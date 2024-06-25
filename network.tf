# create vpc
resource "aws_vpc" "example" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name  = "tf-vpc-example"
    Owner = "John Ajera"
  }
}

# create subnet
resource "aws_subnet" "example_a" {
  vpc_id                  = aws_vpc.example.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "ap-southeast-1a"

  tags = {
    Name  = "tf-subnet-example_a"
    Owner = "John Ajera"
  }
}

resource "aws_subnet" "example_b" {
  vpc_id                  = aws_vpc.example.id
  cidr_block              = "10.0.2.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "ap-southeast-1b"

  tags = {
    Name  = "tf-subnet-example_b"
    Owner = "John Ajera"
  }
}

resource "aws_subnet" "example_c" {
  vpc_id                  = aws_vpc.example.id
  cidr_block              = "10.0.3.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "ap-southeast-1c"

  tags = {
    Name  = "tf-subnet-example_c"
    Owner = "John Ajera"
  }
}

# create ig
resource "aws_internet_gateway" "example" {
  vpc_id = aws_vpc.example.id

  tags = {
    Name  = "tf-ig-example"
    Owner = "John Ajera"
  }
}

# create rt
resource "aws_route_table" "example" {
  vpc_id = aws_vpc.example.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.example.id
  }

  route {
    ipv6_cidr_block = "::/0"
    gateway_id      = aws_internet_gateway.example.id
  }

  tags = {
    Name  = "tf-rt-example"
    Owner = "John Ajera"
  }
}

# set rt association
resource "aws_route_table_association" "example_a" {
  subnet_id      = aws_subnet.example_a.id
  route_table_id = aws_route_table.example.id
}

resource "aws_route_table_association" "example_b" {
  subnet_id      = aws_subnet.example_b.id
  route_table_id = aws_route_table.example.id
}

resource "aws_route_table_association" "example_c" {
  subnet_id      = aws_subnet.example_c.id
  route_table_id = aws_route_table.example.id
}

resource "aws_security_group" "example_ecs" {
  name        = "tf-sg-example-ecs"
  description = "Security group for example resources to allow ecs access"
  vpc_id      = aws_vpc.example.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    self        = "false"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all incoming traffic"
  }

  # ingress {
  #   from_port   = 80
  #   to_port     = 80
  #   protocol    = "tcp"
  #   cidr_blocks = ["0.0.0.0/0"]
  #   description = "Allow incoming traffic on port 80"
  # }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name  = "tf-sg-example_ecs"
    Owner = "John Ajera"
  }
}
