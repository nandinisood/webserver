provider "aws"  {
 region= "ap-south-1"
 profile= "nandsss"
}

/*resource "tls_private_key" "private_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}
resource "aws_key_pair" "generated_key" {
  key_name   = "deploy-key"
  public_key = tls_private_key.private_key.public_key_openssh
}
# saving key to local file
resource "local_file" "deploy-key" {
    content  = tls_private_key.private_key.private_key_pem
    filename = "C:/Users/Nandini/Desktop/key.pem"
}
*/

resource "aws_instance"  "myin"  {
depends_on=[
 	aws_security_group.sec_grp1
]
  ami= "ami-0447a12f28fddb066"
  instance_type= "t2.micro"
  key_name= "keypair"
  security_groups= ["sec_grp1"]

	 tags = {
   	 Name = "MeraInstance"
  }
}


resource "aws_ebs_volume" "ebsvol" {
depends_on=[
 	aws_instance.myin
]

  availability_zone = aws_instance.myin.availability_zone
  size              = 1

  tags = {
    Name = "HelloWorld"
  }
}

resource "aws_volume_attachment" "ebs_att" {
 depends_on=[
 	aws_ebs_volume.ebsvol
]
  device_name = "/dev/sdh"
  volume_id   = aws_ebs_volume.ebsvol.id
  instance_id = aws_instance.myin.id
}



resource "aws_security_group" "sec_grp1" {
  name        = "sec_grp1"
  description = "Allow SSH"
  
  ingress {
    description = "TLS from VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

 ingress {
    description = "TLS from VPC"
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
    Name = "sec_grp1"
  }
}



resource "aws_s3_bucket" "b1_61477" {
  bucket = "b1-61477"
  acl    = "private"

  tags = {
    Name = "b1_61477"
  }
  provisioner "local-exec" {
    command ="git clone https://github.com/nandinisood/tera_pic.git  C:/Users/Asus/Desktop/Terraform/"
}
}

resource "aws_s3_bucket_object" "object" { 
 
  bucket = aws_s3_bucket.b1_61477.bucket
  key    = "iot.jpg"
  source = "C:/Users/Asus/Desktop/Terraform/iot.jpg"
  acl = "private"

  
}


data "aws_iam_policy_document" "iam123" {
  statement {
    actions = ["s3:GetObject"]
    principals {
      type        = "AWS"
      identifiers = [aws_cloudfront_origin_access_identity.origin_access_identity.iam_arn]
    }
    resources = ["${aws_s3_bucket.b1_61477.arn}/*"]
  }
}

resource "aws_s3_bucket_policy" "bucpol" {
  bucket = aws_s3_bucket.b1_61477.id
  policy = data.aws_iam_policy_document.iam123.json
}






resource "aws_cloudfront_origin_access_identity" "origin_access_identity" {
  comment = "Some comment"
}


resource "aws_cloudfront_distribution" "s3_dist" {
  origin {
    domain_name = aws_s3_bucket.b1_61477.bucket_regional_domain_name
    origin_id   = aws_s3_bucket.b1_61477.bucket

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.origin_access_identity.cloudfront_access_identity_path
    }
  }
  is_ipv6_enabled     = true
  enabled             = true
  default_root_object = aws_s3_bucket_object.object.bucket

 
  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = aws_s3_bucket_object.object.bucket

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

  tags = {
    Environment = "production"
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}







resource "null_resource"   "null1" {
  
  connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = file("C:/Users/Asus/Downloads/keypair.pem")
    host     = aws_instance.myin.public_ip
  }

provisioner "remote-exec" {
    inline = [
      "sudo yum install httpd php git -y",
      "sudo systemctl start httpd",
      "sudo systemctl enable httpd",
      "sudo mkfs.ext4 /dev/xvdh",
      "sudo mount /dev/xvdh /var/www/html",
      "sudo rm -rf /var/www/html/*",
      "sudo git clone https://github.com/nandinisood/webserver.git  /var/www/html",
      "sudo su << \"EOF\" ",
      "sudo echo \"<center><img src='http://${aws_cloudfront_distribution.s3_dist.domain_name}/${aws_s3_bucket_object.object.key}' width='519' height='318'> </center>\" >> /var/www/html/index.php"
    ]
  }
    
}
 


resource "null_resource" "null3" {
depends_on=[
 		 null_resource.null1
]
 
  provisioner "local-exec" {
    command = "start chrome ${aws_instance.myin.public_ip}"
  }
}
