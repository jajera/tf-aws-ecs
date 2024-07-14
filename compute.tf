data "aws_ami" "amzn2023" {
  most_recent = true

  filter {
    name   = "owner-alias"
    values = ["amazon"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "name"
    values = ["al2023-ami-2023*"]
  }
}

resource "aws_instance" "jumphost" {
  ami                         = data.aws_ami.amzn2023.id
  associate_public_ip_address = false
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.private_a.id

  user_data = <<-EOF
              #!/bin/bash -xe
              hostnamectl set-hostname jumphost
              yum update -y
              yum install -y nc mtr

              mkdir -p /home/ec2-user/.ssh
              cat << 'EOKEY' > /home/ec2-user/.ssh/id_rsa
              ${file("${path.module}/external/key1.pem")}
              EOKEY
              chmod 600 /home/ec2-user/.ssh/id_rsa
              chown ec2-user:ec2-user /home/ec2-user/.ssh/id_rsa
              EOF

  vpc_security_group_ids = [
    aws_security_group.ssh_external.id
  ]

  tags = {
    Name = "private-${random_string.suffix.result}-jumphost"
  }
}
