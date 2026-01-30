import json
import boto3

dynamodb = boto3.resource('dynamodb', region_name='us-east-1')
table = dynamodb.Table('visitor-count')

def lambda_handler(event, context):
    try:
        response = table.update_item(
            Key={
                'CounterName': 'site_visits'
            },
            UpdateExpression='SET #c = if_not_exists(#c, :start) + :inc',
            ExpressionAttributeNames={
                '#c': 'Count'
            },
            ExpressionAttributeValues={
                ':inc': 1,
                ':start': 0
            },
            ReturnValues='UPDATED_NEW'
        )

        count = int(response['Attributes']['Count'])

        return {
            'statusCode': 200,
            'body': json.dumps({'count': count})
        }

    except Exception as e:
        print(e)
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }
