data "archive_file" "sign_function" {
  type        = "zip"
  source_file = "${path.module}/src/functions/signS3Url.mjs"
  output_path = "${path.module}/src/functions/signS3Url.zip"
}

data "aws_iam_policy_document" "sign_function" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "sign_function" {
  name               = "lambda_execution_role_sign_function"
  assume_role_policy = data.aws_iam_policy_document.sign_function.json
}

resource "aws_lambda_function" "sign_function" {
  filename         = data.archive_file.sign_function.output_path
  function_name    = "sign_s3_url"
  role             = aws_iam_role.sign_function.arn
  handler          = "signS3Url.handler"
  source_code_hash = data.archive_file.sign_function.output_base64sha256

  runtime = "nodejs22.x"

  environment {
    variables = {
      RAW_BUCKET = aws_s3_bucket.thumbs.bucket
    }
  }
}

resource "aws_lambda_permission" "this" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.sign_function.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "arn:aws:execute-api:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:${aws_api_gateway_rest_api.this.id}/*/${aws_api_gateway_method.this.http_method}${aws_api_gateway_resource.this.path}"
}