import json
import os
import boto3
import urllib.parse
import urllib.request
from collections import Counter

# Environment variables
DYNAMODB_TABLE = os.environ['DYNAMODB_TABLE']
YOUTUBE_API_KEY = os.environ['YOUTUBE_API_KEY']
REGION = os.environ.get('AWS_REGION', 'us-east-1')

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table(DYNAMODB_TABLE)
comprehend = boto3.client('comprehend', region_name=REGION)

def get_video_metadata(channel_id):
    response = table.scan(
        FilterExpression='ChannelId = :cid',
        ExpressionAttributeValues={':cid': channel_id}
    )
    return response.get('Items', [])

def fetch_comments(video_id):
    url = (
        f"https://www.googleapis.com/youtube/v3/commentThreads"
        f"?key={YOUTUBE_API_KEY}&videoId={video_id}&part=snippet&maxResults=100"
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
                return []  # No comments to analyze
        print(f"HTTPError for video {video_id}: {e}")
        return []
    except Exception as e:
        print(f"Failed to fetch comments for video {video_id}: {e}")
        return []

def summarize_comment_sentiment(comments):
    summary = Counter({'POSITIVE': 0, 'NEGATIVE': 0, 'NEUTRAL': 0, 'MIXED': 0})
    for comment in comments:
        text = comment['snippet']['topLevelComment']['snippet']['textDisplay']
        try:
            sentiment = comprehend.detect_sentiment(Text=text, LanguageCode='en')
            summary[sentiment['Sentiment'].upper()] += 1
        except Exception as e:
            print(f"Error analyzing sentiment: {e}")
            continue
    return dict(summary)

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
        sentiment_counts = summarize_comment_sentiment(comments)

        results.append({
            'VideoId': video_id,
            'Title': title,
            'CommentSentimentSummary': sentiment_counts
        })
        # Store sentiment summary in DynamoDB
        table.update_item(
            Key={"VideoId": video_id},
            UpdateExpression="SET CommentSentimentSummary = :val",
            ExpressionAttributeValues={":val": sentiment_counts}
        )


    return {
        'statusCode': 200,
        'body': json.dumps(results, indent=2)
    }
