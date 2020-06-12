provider "aws" {
  region = "ap-south-1"
  profile = "jasmin"
}


resource "aws_instance" "web" {
  ami           = "ami-0447a12f28fddb066"
  instance_type = "t2.micro"
  key_name = "key1"
  security_groups =["${aws_security_group.ssh1_http.name}"]
  connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = file("C:/Users/ABC/Downloads/key1.pem")
    host     = aws_instance.web.public_ip
  }

  provisioner "remote-exec" {
    inline = [
      "sudo yum install httpd  php git -y",
      "sudo systemctl restart httpd",
      "sudo systemctl enable httpd",
    ]
  }

  tags = {
    Name = "tfinstance"
  }

}
resource "aws_security_group" "ssh1_http"{
name = "ssh1_http"
description="allow ssh and http traffic"


ingress{
from_port =22
to_port =22
protocol ="tcp"
cidr_blocks=["0.0.0.0/0"]
}
ingress{
from_port =80 
to_port =80
protocol ="tcp"
cidr_blocks =["0.0.0.0/0"]
}
ingress{
from_port =443
to_port =443
protocol ="tcp"
cidr_blocks=["0.0.0.0/0"]
}
egress{
from_port =22
to_port = 22
protocol ="tcp"
cidr_blocks = ["0.0.0.0/0"]
}
egress{
from_port =80
to_port = 80
protocol ="tcp"
cidr_blocks = ["0.0.0.0/0"]
}
egress{
from_port =443
to_port = 443
protocol ="tcp"
cidr_blocks = ["0.0.0.0/0"]
}

}



//creating new volume

resource "aws_ebs_volume" "tfvolm" {
  availability_zone = aws_instance.web.availability_zone
  size              = 1
  tags = {
    Name = "vol1"
  }
}


resource "aws_volume_attachment" "ebs_att" {
  device_name = "/dev/sdh"
  volume_id   = aws_ebs_volume.tfvolm.id
  instance_id = aws_instance.web.id
  force_detach = true
}


output "myos_ip" {
  value = aws_instance.web.public_ip
}


resource "null_resource" "null2"  {
	provisioner "local-exec" {
	    command = "echo  ${aws_instance.web.public_ip} > public_ip.txt"
  	}
}
resource "null_resource" "null3"  {

depends_on = [
    aws_volume_attachment.ebs_att,
  ]


  connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = file("C:/Users/ABC/Downloads/key1.pem")
    host     = aws_instance.web.public_ip
  }

provisioner "remote-exec" {
    inline = [
      "sudo mkfs.ext4  /dev/xvdh",
      "sudo mount  /dev/xvdh  /var/www/html",
      "sudo rm -rf /var/www/html/*",
      "sudo git clone https://github.com/microsoft/project-html-website.git /var/www/html/" 
    ]
  }
}


resource "null_resource" "null1"  {

depends_on = [
         null_resource.null3    
  ]

	provisioner "local-exec" {
	    command = "chrome  ${aws_instance.web.public_ip}"
  	}
}

// Creating S3 bucket
resource "aws_s3_bucket" "b" {
  bucket = "jazbucket"
  acl    = "private"
  tags = {
    Name = "lwbucket"
  }
}
locals {
  s3_origin_id = "myS3Origin"
}
output "b" {
  value = aws_s3_bucket.b
}

// Creating Origin Access Identity
resource "aws_cloudfront_origin_access_identity" "origin_access_identity" {
  comment = "Some comment"
}
output "origin_access_identity" {
  value = aws_cloudfront_origin_access_identity.origin_access_identity
}

// Creating bucket policy
data "aws_iam_policy_document" "s3_policy" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.b.arn}/*"]
    principals {
      type        = "AWS"
      identifiers = ["${aws_cloudfront_origin_access_identity.origin_access_identity.iam_arn}"]
    }
  }
  statement {
    actions   = ["s3:ListBucket"]
    resources = ["${aws_s3_bucket.b.arn}"]
    principals {
      type        = "AWS"
      identifiers = ["${aws_cloudfront_origin_access_identity.origin_access_identity.iam_arn}"]
    }
  }
}
resource "aws_s3_bucket_policy" "example" {
  bucket = aws_s3_bucket.b.id
  policy = data.aws_iam_policy_document.s3_policy.json
}

// Creating CloudFront
resource "aws_cloudfront_distribution" "s3_distribution" {
  origin {
    domain_name = aws_s3_bucket.b.bucket_regional_domain_name
    origin_id   = local.s3_origin_id
    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.origin_access_identity.cloudfront_access_identity_path
    }
  }
  enabled             = true
  is_ipv6_enabled     = true
 default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.s3_origin_id
    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
  viewer_certificate {
    cloudfront_default_certificate = true
  }
}
//add image in bucket
resource "null_resource" "null4"  {

          provisioner "local-exec" {
	    command = "aws s3 cp C:/Users/ABC/Downloads/successCloudNew.svg s3://jazbucket --acl public-read"
            
  	}
}