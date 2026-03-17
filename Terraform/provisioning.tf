# Security group
resource "aws_security_group" "devsecops_sg" {

  vpc_id = aws_vpc.devsecops_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 9000
    to_port     = 9000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 30007
    to_port     = 30007
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
    Name = "devsecops-security-group"
  }
}

########################################################
# TLS Private Key
########################################################

resource "tls_private_key" "terraform_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

########################################################
# AWS Key Pair
########################################################

resource "aws_key_pair" "generated_key" {
  key_name   = "terraform-key"
  public_key = tls_private_key.terraform_key.public_key_openssh
}

resource "aws_instance" "devops_vm" {

  ami           = "ami-053b0d53c279acc90"
  instance_type = "t3.large"

  subnet_id = aws_subnet.subnet1.id

  vpc_security_group_ids = [
    aws_security_group.devsecops_sg.id
  ]

  key_name = aws_key_pair.generated_key.key_name

  associate_public_ip_address = true

  depends_on = [
    aws_key_pair.generated_key
  ]

########################################################
# Upload installation script
########################################################

  provisioner "file" {

    source      = "installation.sh"
    destination = "/home/ubuntu/installation.sh"

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = tls_private_key.terraform_key.private_key_pem
      host        = self.public_ip
    }
  }

########################################################
# Execute installation script
########################################################

  provisioner "remote-exec" {

    inline = [
      "sleep 60",
      "chmod +x /home/ubuntu/installation.sh",
      "sudo bash /home/ubuntu/installation.sh"
    ]

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = tls_private_key.terraform_key.private_key_pem
      host        = self.public_ip
      timeout     = "10m"
    }
  }

  tags = {
    Name = "devsecops-agent"
  }
}