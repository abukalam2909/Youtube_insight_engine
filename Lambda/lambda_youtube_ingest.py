import json
import os
import boto3
import urllib.parse
import urllib.request
from datetime import datetime

YOUTUBE_API_KEY = os.environ['YOUTUBE_API_KEY']
S3_BUCKET = os.environ['S3_BUCKET']
DYNAMODB_TABLE = os.environ['DYNAMODB_TABLE']

s3 = boto3.client('s3')
dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table(DYNAMODB_TABLE)
lambda_client = boto3.client('lambda')

def resolve_channel_id(channel_name):
    # First try 'forUsername' (legacy usernames)
    url = f"https://www.googleapis.com/youtube/v3/channels?part=id&forUsername={channel_name}&key={YOUTUBE_API_KEY}"
    try:
        with urllib.request.urlopen(url) as response:
            result = json.loads(response.read())
            if result["items"]:
                return result["items"][0]["id"]
    except:
        pass  # fallback to next method

    # Try resolving via search (for @handle or name-based)
    url = f"https://www.googleapis.com/youtube/v3/search?part=snippet&type=channel&q={channel_name}&key={YOUTUBE_API_KEY}"
    with urllib.request.urlopen(url) as response:
        result = json.loads(response.read())
        if result["items"]:
            return result["items"][0]["snippet"]["channelId"]
    return None

def fetch_youtube_data(channel_id):
    base_url = "https://www.googleapis.com/youtube/v3/search"
    params = {
        "key": YOUTUBE_API_KEY,
        "channelId": channel_id,
        "part": "snippet",
        "maxResults": 10,
        "order": "date",
        "type": "video"
    }
    query_string = urllib.parse.urlencode(params)
    request_url = f"{base_url}?{query_string}"

    with urllib.request.urlopen(request_url) as response:
        return json.loads(response.read())

def fetch_video_statistics(video_id):
    stats_url = (
        f"https://www.googleapis.com/youtube/v3/videos"
        f"?part=statistics&id={video_id}&key={YOUTUBE_API_KEY}"
    )
    with urllib.request.urlopen(stats_url) as response:
        stats_data = json.loads(response.read())
        if stats_data["items"]:
            return stats_data["items"][0].get("statistics", {})
        return {}


def lambda_handler(event, context):
    if "body" in event and isinstance(event["body"], str):
        body = json.loads(event["body"])
    else:
        body = event

    channel_id = body.get("channel_id")
    channel_name = body.get("channel_name")
    analyse_comments = body.get("analyse_comments")

    # Resolve channelId from name if needed
    if not channel_id and channel_name:
        channel_id = resolve_channel_id(channel_name)

    if not channel_id:
        return {
            "statusCode": 400,
            "body": "Missing or unresolvable 'channel_id' or 'channel_name'"
        }

    data = fetch_youtube_data(channel_id)
    timestamp = datetime.utcnow().isoformat()

    # Store raw JSON in S3
    s3_key = f"raw-data/{channel_id}/{timestamp}.json"
    s3.put_object(
        Bucket=S3_BUCKET,
        Key=s3_key,
        Body=json.dumps(data),
        ContentType="application/json"
    )

    video_count = 0
    # Store structured video metadata in DynamoDB
    for item in data.get("items", []):
        snippet = item.get("snippet", {})
        video_id = item["id"].get("videoId")
        if video_id:
            stats = fetch_video_statistics(video_id)
            table.put_item(
                Item={
                    "VideoId": video_id,
                    "ChannelId": channel_id,
                    "Title": snippet.get("title"),
                    "PublishedAt": snippet.get("publishedAt"),
                    "Description": snippet.get("description"),
                    "FetchedAt": timestamp,
                    "ViewCount": int(stats.get("viewCount", 0)),
                    "LikeCount": int(stats.get("likeCount", 0)),
                    "CommentCount": int(stats.get("commentCount", 0))
                }
            )
            video_count += 1


    # Call second Lambda for sentiment analysis if analyse_comments = true
    if analyse_comments:
        lambda_client.invoke(
            FunctionName='YouTubeNLPAnalysisFunction',
            InvocationType='Event',  # Async
            Payload=json.dumps({
                "channel_id": channel_id
            }).encode('utf-8')
        )

        return {
            "statusCode": 202,
            "body": json.dumps({
                "message": "Sentiment analysis started. Please wait a few moments before checking results.",
                "channel_id": channel_id,
                "channel_name": channel_name,
                "video_count": video_count
            })
        }



    return {
        "statusCode": 200,
        "body": json.dumps({
            "message": f"Fetched and stored metadata for channel {channel_id}",
            "channel_id": channel_id,
            "channel_name": channel_name,
            "video_count": video_count
        })
    }

