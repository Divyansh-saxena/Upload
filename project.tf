// first run for the creation of security grp and then ingess and instance launch

provider "aws" {
	region = "ap-south-1"
        access_key = "AKIA6BH2VXLXTWN4YJWO"
	secret_key = "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" 
}



//To fetch  VPC details
data "aws_vpc" "main" {
  filter {
	name = "tag:Name" 
	values = ["divyansh"]
}
}

//Creation of security grp  ingress (inbound) or egress (outbound)
resource "aws_security_group" "SG02" {
  name        = "SG02"
  description = "Allow TLS inbound traffic HTTP"
  vpc_id      = data.aws_vpc.main.id
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
tags = {
    Name = "SG02"
  }
}


//To fetch Security grp details
data "aws_security_group" "SG02data" {
 depends_on = [
    aws_security_group.SG02,
  ]
  filter {
	name = "tag:Name" 
	values = ["SG02"]
}
}

//Adding port 80 HTTP
resource "aws_security_group_rule" "Rule_HTTP" {

  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = data.aws_security_group.SG02data.id
}

//Adding port 22 SSH
resource "aws_security_group_rule" "Rule_SSH" {

  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = data.aws_security_group.SG02data.id
}





variable ami1 {
	default="ami-0447a12f28fddb066"
}


//instance launch
resource "aws_instance" "vm02" {
depends_on = [
    aws_security_group_rule.Rule_SSH,
    aws_security_group_rule.Rule_HTTP,
  ]
  ami           = "${var.ami1}"
  instance_type = "t2.micro"
  security_groups = [data.aws_security_group.SG02data.name]
  key_name = "key1234"

  connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = file("C:/Users/Divyansh Saxena/Downloads/key1234.pem")
    host     = aws_instance.vm02.public_ip
  }

  provisioner "remote-exec" {
    inline = [      

      "sudo yum install httpd  php git -y",
      "sudo systemctl restart httpd",
      "sudo systemctl enable httpd",
    ]
  }
  tags = {
    Name = "SecondOS"
  }
}



//Creation of volume
resource "aws_ebs_volume" "Pen_Drive2" {
depends_on = [
    aws_instance.vm02,
  ]
  availability_zone = aws_instance.vm02.availability_zone
  size              = 1

  tags = {
    Name = "PenDrive1gib"
  }
}

//Attachment of EBS with insatance
resource "aws_volume_attachment" "Attachment_02" {
depends_on = [
    aws_ebs_volume.Pen_Drive2,
  ]
  device_name = "/dev/sdh"
  volume_id   = aws_ebs_volume.Pen_Drive2.id
  instance_id = aws_instance.vm02.id
  force_detach = true
}

resource "null_resource" "nullremote"  {

depends_on = [
    aws_volume_attachment.Attachment_02
  ]


  connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = file("C:/Users/Divyansh Saxena/Downloads/key1234.pem")
    host     = aws_instance.vm02.public_ip
  }

provisioner "remote-exec" {
    inline = [
      "sudo mkfs.ext4  /dev/xvdh",
      "sudo mount  /dev/xvdh  /var/www/html",
      "sudo rm -rf /var/www/html/*",
      "sudo git clone https://github.com/Divyansh-saxena/Upload.git  var/www/html/"
      ]
  }
}


//creation of S3 bucket
resource "aws_s3_bucket" "divyansh1222bucket" {
depends_on = [
    aws_ebs_volume.Pen_Drive2,
  ]
  bucket = "divyanshbu22cketaws"
  acl    = "public-read"
  force_destroy = true

  tags = {
    Name        = "divyan22shbucketaws"
    Environment = "Divyanshaws"
  }
}


resource "aws_s3_bucket_policy" "b67" {
depends_on = [
    aws_s3_bucket.divyansh1222bucket,
  ]
  bucket = "${aws_s3_bucket.divyansh1222bucket.id}"

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Id": "MYBUCKETPOLICY",
  "Statement": [
    {
      "Sid": "IPAllow",
      "Effect": "Deny",
      "Principal": "*",
      "Action": "s3:*",
      "Resource": "arn:aws:s3:::divyanshbu22cketaws/*",
      "Condition": {
         "IpAddress": {"aws:SourceIp": "8.8.8.8/32"}
      }
    }
  ]
}
POLICY
}

//object upload
resource "aws_s3_bucket_object" "S3objectUpload" {
  bucket = aws_s3_bucket.divyansh1222bucket.bucket
  key    = "upload.jpg"
  source = "C:/Users/Divyansh Saxena/Downloads/upload.jpg"
  acl = "public-read"
  content_type = "image or jpeg"
  }


output "URLCF"{
  value = aws_cloudfront_distribution.s39898distribution.domain_name
}

locals {
  s3_origin_id = "myS3334Origin"
}

// Creation of CloudFront
resource "aws_cloudfront_distribution" "s39898distribution" {
depends_on = [
    aws_s3_bucket.divyansh1222bucket,
  ]
  origin {
    domain_name = "${aws_s3_bucket.divyansh1222bucket.bucket_regional_domain_name}"
    origin_id   = "${local.s3_origin_id}"
        
   custom_origin_config {
            http_port = 80
            https_port = 443
            origin_protocol_policy = "match-viewer"
            origin_ssl_protocols = ["TLSv1", "TLSv1.1", "TLSv1.2"]
        }

  }

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "Some comment"
  default_root_object = "index.html"
   
  logging_config {
    include_cookies = false
    bucket          = "${aws_s3_bucket.divyansh1222bucket.bucket_regional_domain_name}"
    prefix          = "myprefix"
  }

  
  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "${local.s3_origin_id}"

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "allow-all"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  # Cache behavior with precedence 0
  ordered_cache_behavior {
    path_pattern     = "/content/immutable/*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD", "OPTIONS"]
    target_origin_id = "${local.s3_origin_id}"

    forwarded_values {
      query_string = false
      headers      = ["Origin"]

      cookies {
        forward = "none"
      }
    }

    min_ttl                = 0
    default_ttl            = 86400
    max_ttl                = 31536000
    compress               = true
    viewer_protocol_policy = "redirect-to-https"
  }

  # Cache behavior with precedence 1
  ordered_cache_behavior {
    path_pattern     = "/content/*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "${local.s3_origin_id}"

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
    compress               = true
    viewer_protocol_policy = "redirect-to-https"
  }

  price_class = "PriceClass_200"

  restrictions {
    geo_restriction {
      restriction_type = "none"
      }
  }

  tags = {
    Environment = "producmmmtion"
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}



output "Instance_publicIP"{
  value = aws_instance.vm02.public_ip
}

