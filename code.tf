// AWS Provider
provider "aws" {
  region     = "ap-south-1"
  profile    = "aziz"
}

// AWS Security Groups
resource "aws_security_group" "security_group" {
  name        = "security1"
  description = "Allow SSH and HTTP inbound traffic"

  ingress {
    description = "Allow SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  ingress {
    description = "Allow HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "security_group"
  }
}

//AWS Create Key-Pair
variable "key" {
	default = "azizkey"
}

resource "tls_private_key" "algo"{
	algorithm = "RSA"
	rsa_bits  = 2048
}

resource "local_file" "private_key" {
	content = tls_private_key.algo.private_key_pem
	filename = "${var.key}.pem"
	file_permission = "0400"
}

resource "aws_key_pair" "deployer" {
	key_name = var.key
	public_key = tls_private_key.algo.public_key_openssh
}

// AWS Instance
resource "aws_instance" "myOS" {
  ami           = "ami-0447a12f28fddb066"
  instance_type = "t2.micro"
  key_name  	= var.key
  security_groups = [aws_security_group.security_group.name]

  tags = {
    Name = "projectOS"
  }

  connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = file("C:/Users/Aziz Suterwala/Downloads/tera/project1/${var.key}.pem")
    host     = aws_instance.myOS.public_ip
  }

  provisioner "remote-exec" {
    inline = [
      "sudo yum install httpd git -y",
      "setenforce 0",
      "sudo systemctl start httpd",
      "sudo systemctl enable httpd",
    ]
  }
}

// AWS EBS Volume
resource "aws_ebs_volume" "ebs1" {
  availability_zone = aws_instance.myOS.availability_zone
  size              = 1

  tags = {
    Name = "EBS_Volume"
  }
}

// AWS EBS Volume Attachment
resource "aws_volume_attachment" "ebs1_attach" {
depends_on = [
   aws_ebs_volume.ebs1,
]
  device_name = "/dev/sdh"
  volume_id   = aws_ebs_volume.ebs1.id
  instance_id = aws_instance.myOS.id
  force_detach = true
}

// AWS S3 Bucket
resource "aws_s3_bucket" "bucket1" {
  bucket = "mytask1s3bucket"
  acl    = "public-read"

  tags = {
    Name        = "My bucket"
    Environment = "Dev"
  }
}

locals {
    s3_origin_id = "myS3Origin"
}

// AWS S3 Bucket Object
resource "aws_s3_bucket_object" "object1" {
depends_on = [
   aws_s3_bucket.bucket1,
]
  bucket = "mytask1s3bucket"
  key    = "terraform"
  source = "C:/Users/Aziz Suterwala/Downloads/terraform.png"
  acl    = "public-read"
}

// AWS Cloudfront
resource "aws_cloudfront_distribution" "s3_distribution" {
  origin {
    domain_name = aws_s3_bucket.bucket1.bucket_regional_domain_name
    origin_id   = local.s3_origin_id
  }

  enabled             = true
  default_root_object = "terraform"

  //aliases = ["mysite.example.com", "yoursite.example.com"]

  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.s3_origin_id

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
  
  restrictions {
    geo_restriction {
      restriction_type = "whitelist"
      locations        = ["US", "CA", "IN"]
    }
  } 
  
  viewer_certificate {
	cloudfront_default_certificate = true 
	}
}

// AWS Null Resource
resource "null_resource" "null1" {
depends_on = [
   aws_volume_attachment.ebs1_attach,
]
  connection {
      type     = "ssh"
      user     = "ec2-user"
      private_key = file("C:/Users/Aziz Suterwala/Downloads/tera/project1/${var.key}.pem")
      host     = aws_instance.myOS.public_ip
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mkfs.ext4 /dev/xvdh",
      "sudo mount /dev/xvdh  /var/www/html",
      "sudo rm -rf /var/www/html/*",
      "sudo rm -rf /var/www/html/*",
      "sudo git clone https://github.com/Decibel-byte/cloud_example_repo.git  /var/www/html",
    ]
  }
}

// Output Cloudfront Url
output "cloudfront_url" {
  value = aws_cloudfront_distribution.s3_distribution.domain_name
}

// Output AWS Instance IP
output "aws_public_ip" {
  value = aws_instance.myOS.public_ip
}

//AWS Cloudfornt URL in our code
resource "null_resource" "null3" {
depends_on = [
   aws_cloudfront_distribution.s3_distribution,
]
  connection {
      type     = "ssh"
      user     = "ec2-user"
      private_key = file("C:/Users/Aziz Suterwala/Downloads/tera/project1/${var.key}.pem")
      host     = aws_instance.myOS.public_ip
  }

  provisioner "remote-exec" {
    inline = [
      "sudo su <<EOF","echo \"<img src='http://${aws_cloudfront_distribution.s3_distribution.domain_name}/${aws_s3_bucket_object.object1.key}'>\" >> /var/www/html/index.html","EOF",
    ]
  }
}

// AWS Null Resource
resource "null_resource" "null2" {
 depends_on = [
    null_resource.null1,
    aws_cloudfront_distribution.s3_distribution,
  ]
  provisioner "local-exec" {
    command = "chrome ${aws_instance.myOS.public_ip}"
  }
}