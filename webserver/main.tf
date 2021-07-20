provider "aws" {
  region  = var.aws_region
  profile = "arth"
}

#Creating VPC 
resource "aws_vpc" "main" {
  cidr_block       = var.vpc_cidr
  instance_tenancy = "default"
  tags = {
    Name = "myvpc-terraform"
  }
}
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "myigw"
  }
}
resource "aws_subnet" "main" {
  count                   = length(var.subnet_cidr)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = element(var.subnet_cidr, count.index)
  availability_zone       = element(var.azs, count.index)
  map_public_ip_on_launch = true
  tags = {
    Name = "mysubnet-${count.index + 1}"
  }
}

resource "aws_route_table" "example" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "routetable"
  }
}

resource "aws_route_table_association" "a" {
  count          = length(var.subnet_cidr)
  subnet_id      = element(aws_subnet.main.*.id, count.index)
  route_table_id = aws_route_table.example.id
}

#Creating Security Group
resource "aws_security_group" "allow_ports" {
  name        = "terraform_sg"
  description = "Allow inbound traffic"
  vpc_id      = aws_vpc.main.id

  dynamic "ingress" {
    for_each = var.sgports
    content {
      description = "SHH, HTTP from VPC"
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

}

#Creating Key
resource "tls_private_key" "example" {
  algorithm = "RSA"
}

resource "aws_key_pair" "generated_key" {
  key_name   = var.key_name
  public_key = tls_private_key.example.public_key_openssh
  depends_on = [
    tls_private_key.example
  ]
}

resource "local_file" "key-file" {
  content  = tls_private_key.example.private_key_pem
  filename = "terraform.pem"
  depends_on = [
    tls_private_key.example,
    aws_key_pair.generated_key
  ]
}

#Launch EC2 for Apache Httpd, Python, Flask, MongoDB
resource "aws_instance" "os1" {
  ami             = "ami-010aff33ed5991201"
  instance_type   = var.aws_instance_type
  subnet_id       = aws_subnet.main[0].id
  security_groups = [aws_security_group.allow_ports.id]
  key_name        = aws_key_pair.generated_key.key_name

  tags = {
    Name = "webserver from terraform"
  }
}

#Creating EBS Volume
resource "aws_ebs_volume" "vol1" {
  availability_zone = aws_instance.os1.availability_zone
  size              = 1
  tags = {
    Name = "Volume-1"
  }
}

#Attach ebs with ec2
resource "aws_volume_attachment" "ebs_att" {
  device_name = "/dev/sdh"
  volume_id   = aws_ebs_volume.vol1.id
  instance_id = aws_instance.os1.id
}

resource "null_resource" "config_httpd" {
  connection {
    type        = "ssh"
    user        = "ec2-user"
    private_key = file("D:/ARTH-2020/Workspace/terraform-ws/webserver/terraform.pem")
    host        = aws_instance.os1.public_ip
  }

  provisioner "file" {
    source      = "mongodb.repo"
    destination = "/tmp/mongodb.repo"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo cp /tmp/mongodb.repo /etc/yum.repos.d/",
      "sudo yum install -y mongodb-org",
      "sudo systemctl start --now mongod",
      "sudo yum install python3 git -y",
      "sudo pip3 install flask_pymongo",
      "sudo pip3 install bson",
      "sudo pip3 install flask",
      "sudo mkdir /flask-app",
      "sudo mkfs.ext4  /dev/xvdh",
      "sudo mount  /dev/xvdh  /flask-app",
      "sudo rm -rf /flask-app/*",
      "sudo git clone https://github.com/umeshtyagi829/CRUD-app-for-Mongo-Using-and-Flask.git  /flask-app/",
      "sudo python3 /flask-app/app.py"
    ]
  }
}
output "public-dns" {
  value = aws_instance.os1.public_dns
}