provider "aws" {
  region = "us-east-1"
}

resource "aws_vpc" "vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
}

resource "aws_subnet" "public_1" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"
  map_public_ip_on_launch = true
}

resource "aws_subnet" "public_2" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1b"
  map_public_ip_on_launch = true
}

resource "aws_internet_gateway" "EC2InternetGateway" {
    vpc_id = aws_vpc.vpc.id
}

resource "aws_route_table" "EC2RouteTable" {
    vpc_id = aws_vpc.vpc.id
}

resource "aws_route_table_association" "rtb-association-1" {
  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.EC2RouteTable.id
}

resource "aws_route_table_association" "rtb-association-2" {
  subnet_id      = aws_subnet.public_2.id
  route_table_id = aws_route_table.EC2RouteTable.id
}



resource "aws_route" "EC2Route" {
    destination_cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.EC2InternetGateway.id
    route_table_id = aws_route_table.EC2RouteTable.id
}