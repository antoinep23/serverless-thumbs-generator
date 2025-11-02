# S3 Bucket for Storing Thumbnails and Images

resource "aws_s3_bucket" "thumbs" {
  bucket = "thumbs-serverless-store"
}

resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.thumbs.id

  versioning_configuration {
    status = "Enabled"
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

resource "aws_s3_object" "app_js" {
  depends_on   = [aws_s3_bucket.frontend]
  bucket       = aws_s3_bucket.frontend.bucket
  key          = "app.js"
  source       = "./src/frontend/app.js"
  content_type = "application/javascript"
}