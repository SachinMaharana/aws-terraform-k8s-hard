variable "ssh_public_key_path" {
  default = "~/.ssh/id_rsa.pub"
}

variable "availability_zones" {
  description = "Number of different AZs to use"
  type        = number
  default     = 3
}


variable "region" {
  default = "eu-west-3"
}


variable "vpc_cidr" {
  default = "10.240.0.0/24"
}

variable "cluster_cidr" {
  default = "10.200.0.0/16"
}


variable "all_cidr" {
  default = "0.0.0.0/0"
}


