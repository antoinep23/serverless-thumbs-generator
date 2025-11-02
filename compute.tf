data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

data "aws_iam_policy_document" "s3_access" {
  statement {
    effect = "Allow"

    actions = [
      "s3:GetObject",
      "s3:PutObject",
    ]

    resources = [
      "${aws_s3_bucket.thumbs.arn}/*",
    ]
  }
}

resource "aws_iam_policy" "this" {
  name        = "lambda_s3_access"
  description = "Policy for Lambda to access thumbs S3 bucket"

  policy = data.aws_iam_policy_document.s3_access.json
}

resource "aws_iam_role_policy_attachment" "s3_access_attach" {
  role       = aws_iam_role.this.name
  policy_arn = aws_iam_policy.this.arn
}

resource "aws_iam_role" "this" {
  name               = "lambda_execution_role"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

# Sign S3 URL Lambda Function

data "archive_file" "sign_function" {
  type        = "zip"
  source_file = "${path.module}/src/functions/signS3Url.mjs"
  output_path = "${path.module}/src/functions/signS3Url.zip"
}

resource "aws_lambda_function" "sign_function" {
  filename         = data.archive_file.sign_function.output_path
  function_name    = "sign_s3_url"
  role             = aws_iam_role.this.arn
  handler          = "signS3Url.handler"
  source_code_hash = data.archive_file.sign_function.output_base64sha256

  runtime = "nodejs22.x"

  environment {
    variables = {
      RAW_BUCKET   = aws_s3_bucket.thumbs.bucket
      FRONTEND_URL = aws_cloudfront_distribution.this.domain_name
    }
  }
}

resource "aws_lambda_permission" "allow_api_gateway" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.sign_function.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "arn:aws:execute-api:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:${aws_api_gateway_rest_api.this.id}/*/${aws_api_gateway_method.post.http_method}${aws_api_gateway_resource.this.path}"
}

# Convert Raw to Thumbnail Lambda Function

data "archive_file" "convert_function" {
  type        = "zip"
  source_file = "${path.module}/src/functions/convertRawToThumb.mjs"
  output_path = "${path.module}/src/functions/convertRawToThumb.zip"
}

resource "aws_lambda_function" "convert_function" {
  filename         = data.archive_file.convert_function.output_path
  function_name    = "convert_raw_to_thumb"
  role             = aws_iam_role.this.arn
  handler          = "convertRawToThumb.handler"
  source_code_hash = data.archive_file.convert_function.output_base64sha256

  runtime = "nodejs22.x"

  layers = [aws_lambda_layer_version.this.arn]
}

resource "aws_lambda_permission" "allow_bucket" {
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.convert_function.arn
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.thumbs.arn
}

resource "aws_lambda_layer_version" "this" {
  filename   = "${path.module}/src/functions/layers/layer-nodejs22-x64.zip"
  layer_name = "layer-nodejs22-x64"

  compatible_runtimes      = ["nodejs22.x"]
  compatible_architectures = ["x86_64", "arm64"]
}