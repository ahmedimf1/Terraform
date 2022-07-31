terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }

  required_version = ">= 1.2.0"
}

# Configure the AWS Provider
provider "aws" {
  region  = "us-east-1"
  profile = "default"
}

# Create a VPC
resource "aws_vpc" "test-vpc" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "test"
  }
}
# Create an internet gateway to the vpc
resource "aws_internet_gateway" "test-gw" {
  vpc_id = aws_vpc.test-vpc.id

  tags = {
    Name = "test"
  }
}
# Create a custom routing table
resource "aws_route_table" "test-rt" {
  vpc_id = aws_vpc.test-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.test-gw.id
  }

  route {
    ipv6_cidr_block = "::/0"
    gateway_id      = aws_internet_gateway.test-gw.id
  }

  tags = {
    Name = "test"
  }
}
# Create a subnet
resource "aws_subnet" "test-subnet" {
  vpc_id            = aws_vpc.test-vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "test"
  }
}
# Associate the Subnet with the routing table
resource "aws_route_table_association" "rw-asoc" {
  subnet_id      = aws_subnet.test-subnet.id
  route_table_id = aws_route_table.test-rt.id
}
# Create a Security group and allow internet traffic
resource "aws_security_group" "allow_web_traffic" {
  name        = "allow_web_traffic"
  description = "Allow inbound web traffic"
  vpc_id      = aws_vpc.test-vpc.id

  ingress {
    description      = "HTTPS"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    description      = "HTTP"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    description      = "SSH"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "test"
  }
}
# Create a Network Interface
resource "aws_network_interface" "test-nic" {
  subnet_id       = aws_subnet.test-subnet.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.allow_web_traffic.id]
  tags = {
    Name = "test"
  }
}

# Create and Elastic IP Address
resource "aws_eip" "test-eip" {
  vpc                       = true
  network_interface         = aws_network_interface.test-nic.id
  associate_with_private_ip = "10.0.1.50"
  depends_on = [
    aws_internet_gateway.test-gw
  ]
}
# Create an EC2 instance with Ubuntu server AMI and install apache2
resource "aws_instance" "test-server" {
  instance_type = "t2.micro"
  ami           = "ami-0729e439b6769d6ab"
  # availability_zone = "us-east-1a"
  availability_zone = "us-east-1a"
  key_name          = "main-key"
  network_interface {
    device_index         = 0
    network_interface_id = aws_network_interface.test-nic.id
  }
  user_data = <<-EOF
                #!bin/bash
                sudo apt update -y
                sudo apt install apache2 -y
                sudo ufw allow 'Apache'
                sudo a2enmod ssl
                sudo systemctl start apache2
                sudo bash -c "The very first webserver" > /var/www/html/index.html
                EOF
  tags = {
    Name = "test"
  }
}
