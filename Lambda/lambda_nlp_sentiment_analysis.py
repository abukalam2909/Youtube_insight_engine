import json
import os
import boto3
import urllib.parse
import urllib.request
from collections import Counter, defaultdict

# Environment variables
DYNAMODB_TABLE = os.environ['DYNAMODB_TABLE']
YOUTUBE_API_KEY = os.environ['YOUTUBE_API_KEY']
REGION = os.environ.get('AWS_REGION', 'us-east-1')

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table(DYNAMODB_TABLE)
comprehend = boto3.client('comprehend', region_name=REGION)
lambda_client = boto3.client('lambda')

def get_video_metadata(channel_id):
    response = table.scan(
        FilterExpression='ChannelId = :cid',
        ExpressionAttributeValues={':cid': channel_id}
    )
    return response.get('Items', [])

def fetch_comments(video_id):
    url = (
        f"https://www.googleapis.com/youtube/v3/commentThreads"
        f"?key={YOUTUBE_API_KEY}&videoId={video_id}&part=snippet&maxResults=25"
    )
    try:
        with urllib.request.urlopen(url) as response:
            return json.loads(response.read()).get('items', [])
    except urllib.error.HTTPError as e:
        if e.code == 403:
            error_body = json.loads(e.read())
            reason = error_body.get("error", {}).get("errors", [{}])[0].get("reason", "")
            if reason == "commentsDisabled":
                print(f"Comments disabled for video: {video_id}")
                return []
        print(f"HTTPError for video {video_id}: {e}")
        return []
    except Exception as e:
        print(f"Failed to fetch comments for video {video_id}: {e}")
        return []

def analyze_sentiment_and_sample(comments):
    sentiment_summary = Counter({'POSITIVE': 0, 'NEGATIVE': 0, 'NEUTRAL': 0, 'MIXED': 0})
    sentiment_samples = defaultdict(list)

    for comment in comments:
        try:
            snippet = comment['snippet']['topLevelComment']['snippet']
            text = snippet.get('textDisplay', '')
            likes = snippet.get('likeCount', 0)

            #sentiment = comprehend.detect_sentiment(Text=text, LanguageCode='en')
            # Truncate to 5000 bytes (not characters)
            encoded_text = text.encode('utf-8')
            if len(encoded_text) > 5000:
                encoded_text = encoded_text[:5000]
                text = encoded_text.decode('utf-8', errors='ignore')  # safely decode

            sentiment = comprehend.detect_sentiment(Text=text, LanguageCode='en') 
            sentiment_type = sentiment['Sentiment'].upper()
            sentiment_summary[sentiment_type] += 1

            # Add to samples with likes count
            sentiment_samples[sentiment_type].append({
                "text": text,
                "likes": likes
            })

        except Exception as e:
            print(f"Error processing comment: {e}")
            continue

    # Keep top 3 samples per sentiment type, sorted by likes
    sample_comments = {}
    for sentiment_type, comment_list in sentiment_samples.items():
        sorted_comments = sorted(comment_list, key=lambda x: x['likes'], reverse=True)
        sample_comments[sentiment_type] = sorted_comments[:3]

    return dict(sentiment_summary), sample_comments

def lambda_handler(event, context):
    channel_id = event.get('channel_id')

    if not channel_id:
        return {
            'statusCode': 400,
            'body': 'Missing channel_id in request'
        }

    results = []
    videos = get_video_metadata(channel_id)

    for video in videos:
        video_id = video.get('VideoId')
        title = video.get('Title', '')

        comments = fetch_comments(video_id)
        sentiment_counts, sample_comments = analyze_sentiment_and_sample(comments)

        # Store sentiment summary and sample comments in DynamoDB
        table.update_item(
            Key={"VideoId": video_id},
            UpdateExpression="""
                SET CommentSentimentSummary = :summary,
                    SampleComments = :samples,
                    ProcessingStatus = :status
            """,
            ExpressionAttributeValues={
                ":summary": sentiment_counts,
                ":samples": sample_comments,
                ":status": "COMPLETE"
            }
        )

        results.append({
            "video_id": video_id,
            "title": title,
            "sentiment_data": {
                "positive": sentiment_counts.get("POSITIVE", 0),
                "neutral": sentiment_counts.get("NEUTRAL", 0),
                "negative": sentiment_counts.get("NEGATIVE", 0)
            },
            "engagement_data": {
                "likes": int(video.get("LikeCount", 0)),
                "comments": int(video.get("CommentCount", 0)),
                "views": int(video.get("ViewCount", 0))
            }
        })

    return {
        'statusCode': 200,
        'body': json.dumps(results, indent=2)
    }
