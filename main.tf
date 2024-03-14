terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.57"
    }
  }
}

provider "aws" {
  region                   = "us-east-1"
  shared_credentials_files = ["./credentials"]
}

resource "aws_vpc" "main" {
  cidr_block           = "192.168.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
}

resource "aws_subnet" "public" {
  count                   = 4
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(aws_vpc.main.cidr_block, 2, count.index)
  map_public_ip_on_launch = true
  availability_zone       = "us-east-1a" # Consider using different zones for each subnet
}

resource "aws_instance" "web" {
  count                  = 4
  ami                    = "ami-0f403e3180720dd7e"
  instance_type          = "t2.micro"
  subnet_id              = element(aws_subnet.public[*].id, count.index)
  vpc_security_group_ids = [aws_security_group.sg_tf.id]

user_data = <<-EOF
              #!/bin/bash
              sudo yum install docker -y
              sudo systemctl start docker
              sudo docker run -d -p 80:80 nginx
              sudo docker run -d -p 8080:8080 nginx
              sudo docker run -d -p 8081:8081 nginx
              EOF
}

resource "aws_route_table" "public-rt" {
 vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.internet-gateway.id
  }
  tags = { Name = "public-rt" }
}

resource "aws_route_table_association" "RT-public-sn" {
  count          = 4
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public-rt.id
}
resource "aws_internet_gateway" "internet-gateway" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "internet-gateway"
  }
}

resource "aws_security_group" "sg_tf" {
  name        = "sg_tf"
  description = "Allow SSH, HTTP, and NGINX container ports"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8080
    to_port     = 8081
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress{
    from_port   = 0
    to_port     = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
