# address of the website which we want to check if it is running
websiteAddr = 'example.com'


# textstring that should be present on the mentioned website
# that serves us as confirmation that the website loaded OK with no errors
checkString = 'my website'


# SNS topic ARN using which e-mails will be sent to you (copy your topic arn and paste)
topicARN = 'arn:aws:sns:us-east-1:029186443497:SNSTOPIC'


# let's import library which will allow us to make http/https requests
import http.client


# let's import library which will allow us to publish message to SNS topic
import boto3


def lambda_handler(event, context):
    # let's assume by default that website is down until we prove it isn't
    result = False


    try:
        # making HTTPS connection to the website
        connection = http.client.HTTPSConnection(websiteAddr)

        # fetching root page of the website
        connection.request('GET', '/')


        # checking if the webpage content contains checkString or not
        if connection.getresponse().read().decode().find(checkString) > -1:
            result = True
    except:
        pass

    # if website is down, publish SNS message and SNS sends out email
    if result == False:
        msg = websiteAddr + ' is DOWN'
        sns = boto3.client('sns')
        sns.publish(
            TopicArn = topicARN,
            Subject = msg,
            Message = msg
        )

    return {
        'statusCode': 200,
    }
