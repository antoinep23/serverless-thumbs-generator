# S3 Bucket for Storing Thumbnails and Images

resource "aws_s3_bucket" "thumbs" {
  bucket        = "thumbs-serverless-store"
  force_destroy = true
}

resource "aws_s3_bucket_notification" "this" {
  bucket = aws_s3_bucket.thumbs.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.convert_function.arn
    events              = ["s3:ObjectCreated:Put"]
  }
}

resource "aws_s3_bucket_cors_configuration" "this" {
  depends_on = [aws_s3_bucket.thumbs, aws_cloudfront_distribution.this]
  bucket     = aws_s3_bucket.thumbs.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["PUT", "POST", "GET", "HEAD"]
    allowed_origins = [
      "https://${aws_cloudfront_distribution.this.domain_name}",
    ]
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}

# S3 Bucket for Frontend Hosting

resource "aws_s3_bucket" "frontend" {
  bucket = "thumbs-serverless-frontend"
}

resource "aws_s3_bucket_website_configuration" "this" {
  bucket = aws_s3_bucket.frontend.id

  index_document {
    suffix = "index.html"
  }
}

resource "aws_s3_object" "index_html" {
  depends_on   = [aws_s3_bucket.frontend]
  bucket       = aws_s3_bucket.frontend.bucket
  key          = "index.html"
  source       = "./src/frontend/index.html"
  content_type = "text/html"
}

resource "aws_s3_object" "style_css" {
  depends_on   = [aws_s3_bucket.frontend]
  bucket       = aws_s3_bucket.frontend.bucket
  key          = "style.css"
  source       = "./src/frontend/style.css"
  content_type = "text/css"
}

resource "aws_s3_object" "aws_logo" {
  depends_on   = [aws_s3_bucket.frontend]
  bucket       = aws_s3_bucket.frontend.bucket
  key          = "aws-logo.png"
  source       = "./src/frontend/aws-logo.png"
  content_type = "image/png"
}

resource "local_file" "app_js" {
  depends_on = [aws_api_gateway_rest_api.this, aws_api_gateway_stage.this]
  filename   = "src/frontend/app.js"
  content    = templatefile("src/frontend/app.js.tftpl", { "API_BASE" = "https://${aws_api_gateway_rest_api.this.id}.execute-api.${data.aws_region.current.region}.amazonaws.com/${aws_api_gateway_stage.this.stage_name}" })
}

resource "aws_s3_object" "app_js" {
  depends_on   = [aws_s3_bucket.frontend, local_file.app_js]
  bucket       = aws_s3_bucket.frontend.bucket
  key          = "app.js"
  source       = "./src/frontend/app.js"
  content_type = "application/javascript"
}