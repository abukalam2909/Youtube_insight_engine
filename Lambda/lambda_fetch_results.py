import json
import os
import boto3
from decimal import Decimal
from boto3.dynamodb.conditions import Attr

# Environment variables
DYNAMODB_TABLE = os.environ['DYNAMODB_TABLE']
REGION = os.environ.get('AWS_REGION', 'us-east-1')

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table(DYNAMODB_TABLE)

def normalize_sentiment(dynamo_map):
    # Safely convert Decimal or int to plain int
    return {
        "positive": int(dynamo_map.get("POSITIVE", 0)),
        "negative": int(dynamo_map.get("NEGATIVE", 0)),
        "neutral": int(dynamo_map.get("NEUTRAL", 0)),
    }

def lambda_handler(event, context):
    try:
        # Parse input body
        if "body" in event and isinstance(event["body"], str):
            body = json.loads(event["body"])
        else:
            body = event

        channel_id = body.get("channel_id")
        if not channel_id:
            return {
                "statusCode": 400,
                "body": json.dumps({"error": "Missing channel_id"})
            }

        # Scan for COMPLETE processed videos
        response = table.scan(
            FilterExpression=Attr('ChannelId').eq(channel_id) & Attr('ProcessingStatus').eq("COMPLETE")
        )

        results = []
        for video in response.get("Items", []):
            sentiment_raw = video.get("CommentSentimentSummary", {})
            sentiment_data = normalize_sentiment(sentiment_raw)

            results.append({
                "video_id": video.get("VideoId"),
                "title": video.get("Title"),
                "sentiment_data": sentiment_data,
                "engagement_data": {
                    "likes": int(video.get("LikeCount", 0)),
                    "comments": int(video.get("CommentCount", 0)),
                    "views": int(video.get("ViewCount", 0))
                }
            })

        return {
            "statusCode": 200,
            "body": json.dumps(results)
        }

    except Exception as e:
        return {
            "statusCode": 500,
            "body": json.dumps({"error": str(e)})
        }
