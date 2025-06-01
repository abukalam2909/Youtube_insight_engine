# VPC
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "youtube-analyzer-vpc"
  }
}

# Internet Gateway for NAT Gateway
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "youtube-analyzer-igw"
  }
}

# Public Subnet for NAT Gateway
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "${var.aws_region}a"
  tags = {
    Name = "youtube-analyzer-public"
  }
}

# Elastic IP for NAT Gateway
resource "aws_eip" "nat" {
  domain = "vpc"
}

# NAT Gateway
resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public.id
  tags = {
    Name = "youtube-analyzer-nat"
  }
}

# Private Subnets for Lambdas
resource "aws_subnet" "private_1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "${var.aws_region}a"
  tags = {
    Name = "youtube-analyzer-private-1"
  }
}

resource "aws_subnet" "private_2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "${var.aws_region}b"
  tags = {
    Name = "youtube-analyzer-private-2"
  }
}

# Route Table for Public Subnet
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
  tags = {
    Name = "youtube-analyzer-public-rt"
  }
}

resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# Route Table for Private Subnets (NAT Gateway)
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }
  tags = {
    Name = "youtube-analyzer-private-rt"
  }
}

resource "aws_route_table_association" "private_assoc_1" {
  subnet_id      = aws_subnet.private_1.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_assoc_2" {
  subnet_id      = aws_subnet.private_2.id
  route_table_id = aws_route_table.private.id
}

# # Update Lambda functions to use VPC config
# resource "aws_lambda_function" "youtube_ingest" {
#   # ... existing config ...
#   vpc_config {
#     subnet_ids         = [aws_subnet.private_1.id, aws_subnet.private_2.id]
#     security_group_ids = [aws_security_group.lambda_sg.id]
#   }
# }

# resource "aws_lambda_function" "youtube_nlp_analysis" {
#   # ... existing config ...
#   vpc_config {
#     subnet_ids         = [aws_subnet.private_1.id, aws_subnet.private_2.id]
#     security_group_ids = [aws_security_group.lambda_sg.id]
#   }
# }

# resource "aws_lambda_function" "youtube_fetch_results" {
#   # ... existing config ...
#   vpc_config {
#     subnet_ids         = [aws_subnet.private_1.id, aws_subnet.private_2.id]
#     security_group_ids = [aws_security_group.lambda_sg.id]
#   }
# }

# resource "aws_lambda_function" "llm_insights" {
#   # ... existing config ...
#   vpc_config {
#     subnet_ids         = [aws_subnet.private_1.id, aws_subnet.private_2.id]
#     security_group_ids = [aws_security_group.lambda_sg.id]
#   }
# }

# Security group for Lambda
resource "aws_security_group" "lambda_sg" {
  name        = "lambda-sg"
  description = "Allow outbound internet for Lambda"
  vpc_id      = aws_vpc.main.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "lambda-sg"
  }
}
