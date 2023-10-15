resource "aws_vpc" "sample_vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "sample_vpc"
  }
}

resource "aws_internet_gateway" "sample_igw" {
  vpc_id = aws_vpc.sample_vpc.id

  tags = {
    Name = "sample_igw"
  }
}

resource "aws_route_table" "sample_public_route_table" {
  vpc_id = aws_vpc.sample_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.sample_igw.id
  }

  tags = {
    Name = "sample_public_route_table"
  }
}

resource "aws_route_table_association" "sample_public_route_table_association" {
  subnet_id      = aws_subnet.sample_public_subnet.id
  route_table_id = aws_route_table.sample_public_route_table.id
}

resource "aws_subnet" "sample_public_subnet" {
  vpc_id            = aws_vpc.sample_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"

  lifecycle {
    prevent_destroy = false
  }

  tags = {
    Name = "sample_public_subnet"
  }
}

resource "aws_security_group" "sample_ssh" {
  name        = "sample_ssh"
  description = "Allow ssh access from internet"
  vpc_id      = aws_vpc.sample_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
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
    Name = "sample_ssh"
  }
}

resource "aws_instance" "sample_ec2_ssh" {
  ami                         = "ami-041feb57c611358bd"
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.sample_public_subnet.id
  key_name                    = "devops-keypair"
  vpc_security_group_ids      = [aws_security_group.sample_ssh.id]
  associate_public_ip_address = true

  tags = {
    Name = "sample_ec2_ssh"
  }
}

resource "aws_security_group" "sample_icmp" {
  name        = "sample_icmp"
  description = "Allow ping from ec2_ssh"
  vpc_id      = aws_vpc.sample_vpc.id

  ingress {
    from_port       = -1
    to_port         = -1
    protocol        = "icmp"
    security_groups = [aws_security_group.sample_ssh.id, aws_security_group.sample_vpn_endpoint.id]
  }

  egress {
    from_port       = -1
    to_port         = -1
    protocol        = "icmp"
    security_groups = [aws_security_group.sample_ssh.id, aws_security_group.sample_vpn_endpoint.id]
  }

  tags = {
    Name = "sample_icmp"
  }
}

resource "aws_instance" "sample_ec2_internal" {
  ami                    = "ami-041feb57c611358bd"
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.sample_public_subnet.id
  key_name               = "devops-keypair"
  vpc_security_group_ids = [aws_security_group.sample_icmp.id]

  tags = {
    Name = "sample_ec2"
  }
}

// sg for vpn endpoint that allows all inbound and outbound traffic
resource "aws_security_group" "sample_vpn_endpoint" {
  name        = "sample_vpn_endpoint"
  description = "Allow all inbound and outbound traffic"
  vpc_id      = aws_vpc.sample_vpc.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_ec2_client_vpn_endpoint" "sample_client_vpn_endpoint" {
  server_certificate_arn = "arn:aws:acm:us-east-1:798922568248:certificate/478b6cac-bd76-4085-8e5f-d86127c496bf"
  description            = "sample_client_vpn_endpoint"
  client_cidr_block      = "192.168.0.0/22"
  vpc_id                 = aws_vpc.sample_vpc.id
  split_tunnel           = true

  security_group_ids = [
    aws_security_group.sample_vpn_endpoint.id,
  ]

  authentication_options {
    type                       = "certificate-authentication"
    root_certificate_chain_arn = "arn:aws:acm:us-east-1:798922568248:certificate/37ff8377-5dd9-4c5d-9f31-e8244823ce2c"
  }

  connection_log_options {
    enabled = false
  }
}

resource "aws_ec2_client_vpn_authorization_rule" "sample_client_vpn_authorization_rule" {
  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.sample_client_vpn_endpoint.id
  target_network_cidr    = "0.0.0.0/0"
  authorize_all_groups   = true
}

resource "aws_ec2_client_vpn_authorization_rule" "sample_client_vpn_internet_access_rule" {
  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.sample_client_vpn_endpoint.id
  target_network_cidr    = aws_vpc.sample_vpc.cidr_block
  authorize_all_groups   = true
}
