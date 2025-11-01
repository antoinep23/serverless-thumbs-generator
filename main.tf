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
  source       = "./src/index.html"
  content_type = "text/html"
}

resource "aws_s3_object" "style_css" {
  depends_on   = [aws_s3_bucket.frontend]
  bucket       = aws_s3_bucket.frontend.bucket
  key          = "style.css"
  source       = "./src/style.css"
  content_type = "text/css"
}

resource "aws_s3_object" "aws_logo" {
  depends_on   = [aws_s3_bucket.frontend]
  bucket       = aws_s3_bucket.frontend.bucket
  key          = "aws-logo.png"
  source       = "./src/aws-logo.png"
  content_type = "image/png"
}

resource "aws_s3_object" "app_js" {
  depends_on   = [aws_s3_bucket.frontend]
  bucket       = aws_s3_bucket.frontend.bucket
  key          = "app.js"
  source       = "./src/app.js"
  content_type = "application/javascript"
}

# CloudFront Distribution for Frontend

resource "aws_cloudfront_origin_access_control" "this" {
  name                              = "thumbs-serverless-frontend-oac"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "this" {
  enabled             = true
  default_root_object = "index.html"

  origin {
    domain_name              = aws_s3_bucket.frontend.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.this.id
    origin_id                = local.s3_origin_id
  }

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    viewer_protocol_policy = "redirect-to-https"
    target_origin_id       = local.s3_origin_id

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
      locations        = []
    }
  }
}

# Grant CloudFront Access to S3 Bucket

data "aws_iam_policy_document" "allow_cloudfront_access" {
  statement {
    actions = ["s3:GetObject"]

    resources = ["${aws_s3_bucket.frontend.arn}/*"]

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.this.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "allow_cloudfront_access" {
  depends_on = [aws_cloudfront_distribution.this, aws_s3_bucket.frontend]
  bucket     = aws_s3_bucket.frontend.id
  policy     = data.aws_iam_policy_document.allow_cloudfront_access.json
}