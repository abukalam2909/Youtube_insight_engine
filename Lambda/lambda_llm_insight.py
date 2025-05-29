# lambda_generate_report.py (Updated for Claude 3 - Messages API)
import json
import os
import boto3
from decimal import Decimal
from botocore.exceptions import ClientError

# Environment variables
DYNAMODB_TABLE = os.environ['DYNAMODB_TABLE']
BEDROCK_MODEL_ID = os.environ.get('BEDROCK_MODEL_ID', 'anthropic.claude-3-sonnet-20240229-v1:0')
REGION = os.environ.get('AWS_REGION', 'us-east-1')

# AWS clients
dynamodb = boto3.resource('dynamodb')
comprehend = boto3.client('comprehend', region_name=REGION)
bedrock = boto3.client('bedrock-runtime', region_name=REGION)
table = dynamodb.Table(DYNAMODB_TABLE)

def decimal_default(obj):
    if isinstance(obj, Decimal):
        return float(obj)
    raise TypeError(f"Object of type {obj.__class__.__name__} is not JSON serializable")

def detect_sentiment(text):
    try:
        response = comprehend.detect_sentiment(Text=text, LanguageCode='en')
        return response['Sentiment'].upper()
    except Exception as e:
        print(f"Sentiment analysis failed: {e}")
        return "NEUTRAL"

def retrieve_top_comments(video_id, sentiment):
    try:
        response = table.get_item(Key={'VideoId': video_id})
        item = response.get('Item', {})
        samples = item.get('SampleComments', {})

        if sentiment == "NEUTRAL":
            all_comments = []
            for s in ["POSITIVE", "NEGATIVE", "MIXED"]:
                comments = samples.get(s, [])[:3]
                all_comments.extend(comments)
            return all_comments
        else:
            return samples.get(sentiment, [])[:5]
    except ClientError as e:
        print(f"Error retrieving comments: {e.response['Error']['Message']}")
        return []
    except Exception as e:
        print(f"Unexpected error: {e}")
        return []

def generate_prompt(query, sentiment, comments):
    formatted_comments = "\n".join([
        f"- {c.get('text', '')}" for c in comments
    ])

    user_message = (
        "You are an expert YouTube comment analyst. "
        "Avoid phrases like 'based on the comments' or 'without more context'. "
        "Be direct, insightful, and concise.\n\n"
        f"User Query: {query}\n"
        f"The sentiment of the query is: {sentiment}\n"
        f"Here are some YouTube comments for the video:\n{formatted_comments}\n\n"
        "Please provide a concise and insightful response that reflects the viewer sentiment."
    )

    return {
        "messages": [
            {
                "role": "user",
                "content": user_message
            }
        ],
        "anthropic_version": "bedrock-2023-05-31",
        "max_tokens": 500,
        "temperature": 0.7
    }


def call_bedrock(prompt_dict):
    try:
        response = bedrock.invoke_model(
            modelId=BEDROCK_MODEL_ID,
            body=json.dumps(prompt_dict),
            accept="application/json",
            contentType="application/json"
        )
        response_body = json.loads(response['body'].read())
        return response_body.get("content")
    except Exception as e:
        print(f"Error invoking Bedrock model: {e}")
        return "LLM analysis could not be generated at this time."




def lambda_handler(event, context):
    print(f"Received event: {json.dumps(event)}")

    query = event.get('query')
    video_id = event.get('video_id')

    if not query or not video_id:
        return {
            'statusCode': 400,
            'body': json.dumps({
                'error': 'Missing "query" or "video_id" in request'
            })
        }

    sentiment = detect_sentiment(query)
    comments = retrieve_top_comments(video_id, sentiment)

    if not comments:
        return {
            'statusCode': 404,
            'body': json.dumps({
                'error': f'No comments found for sentiment {sentiment} on video {video_id}'
            })
        }

    prompt = generate_prompt(query, sentiment, comments)
    llm_output = call_bedrock(prompt)

    return {
        'statusCode': 200,
        'body': json.dumps({
            'video_id': video_id,
            'query': query,
            'sentiment': sentiment,
            'used_comments': comments,
            'llm_generated_analysis': llm_output
        }, indent=2, default=decimal_default)
    }
