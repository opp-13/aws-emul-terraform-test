resource "aws_s3_bucket" "this" {
  bucket        = "${var.name}-bucket"
  force_destroy = true
}

resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.this.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_object" "hello" {
  bucket       = aws_s3_bucket.this.id
  key          = "hello.txt"
  content      = "hello from terraform on aws-emulator\n"
  content_type = "text/plain"
}
