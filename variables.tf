
variable "availability_zones" {
  description = "Number of different AZs to use"
  type        = number
  default     = 3
}


variable "region" {
  default = "us-east-2"
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



variable "controller_count" {
  default = 3
}


variable "worker_count" {
  default = 3
}


variable "etcd_count" {
  default = 3
}




variable "lb_count" {
  default = 1
}

variable "centos" {
  default = "ami-0f2b4fc905b0bd1f1"
}




