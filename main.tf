terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}


provider "aws" {
  region = var.aws_region
}

variable "access_policy" {
  description = "everyone allowed to publish"
  type        = string
}

resource "aws_sns_topic" "health-check" {
  name   = "website-health"
  policy = var.access_policy
}


resource "aws_sns_topic_subscription" "emailnotif" {
  depends_on = [aws_sns_topic.health-check]
  topic_arn  = aws_sns_topic.health-check.arn
  protocol   = "email"
  endpoint   = var.email_list
}

provider "archive" {}

data "archive_file" "zip" {
  type        = "zip"
  source_file = "checkFunction.py"
  output_path = "checkFunction.zip"
}

resource "aws_iam_role" "iam_for_lambda" {
  name = "iam_for_lambda_with_sns"

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_policy" "policy" {
  name        = "sns_fullacc"
  description = "A test policy"

  policy = var.aws_iam_policy
}

resource "aws_iam_role_policy_attachment" "attach" {
  role       = aws_iam_role.iam_for_lambda.name
  policy_arn = aws_iam_policy.policy.arn
}


resource "aws_lambda_function" "lambda" {
  function_name = "checkFunction"

  filename         = "${data.archive_file.zip.output_path}"
  source_code_hash = "${data.archive_file.zip.output_base64sha256}"

  role    = "${aws_iam_role.iam_for_lambda.arn}"
  handler = "checkFunction.lambda_handler"
  runtime = "python3.8"

  environment {
    variables = {
      greeting = "you pulled a facebook on me"
    }
  }
}

resource "aws_cloudwatch_event_rule" "check_5" {
  name = "5-min-event"
  description = "check every 5 mins"
  schedule_expression = "rate(5 minutes)"
}

resource "aws_cloudwatch_event_target" "tar_bda" {
  target_id = "tarbda"
  rule      = aws_cloudwatch_event_rule.check_5.name
  arn       = aws_lambda_function.lambda.arn
}

resource "aws_lambda_permission" "allow_cloudwatch" {
  statement_id = "AllowExcutionFromCloudWatch"
  action = "lambda:InvokeFunction"
  function_name = "checkFunction"
  principal     = "events.amazonaws.com"
  source_arn = aws_cloudwatch_event_rule.check_5.arn
}
