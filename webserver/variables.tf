variable "aws_region" {
  default = "ap-south-1"
}

variable "vpc_cidr" {
  default = "10.0.0.0/16"
}

variable "subnet_cidr" {
  type    = list(any)
  default = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "azs" {
  default = ["ap-south-1a", "ap-south-1b"]
}

variable "aws_instance_type" {
  default = "t2.micro"
}

variable "sgports" {
  type    = list(any)
  default = [80, 22]
}

variable "key_name" {
  default = "terraform-key"
}

