provider "aws" {
  region = "us-east-1"
}

resource "aws_instance" "example_instance" {
  ami           = "ami-0c94855ba95c71c99" # Replace with your desired AMI ID
  instance_type = "t2.micro"
  key_name      = "example_keypair"

  vpc_security_group_ids = [
    aws_security_group.example_security_group.id
  ]

  subnet_id = aws_subnet.example_subnet.id

  tags = {
    Name = "example_instance"
  }
}

resource "aws_security_group" "example_security_group" {
  name_prefix = "example_security_group"

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

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_key_pair" "example_keypair" {
  key_name   = "example_keypair"
  public_key = file("${path.module}/id_rsa.pub")

  provisioner "local-exec" {
    command = "mkdir -p ${path.module}/ssh && echo '${aws_key_pair.example_keypair.private_key}' > ${path.module}/ssh/id_rsa && chmod 600 ${path.module}/ssh/id_rsa"
  }
}