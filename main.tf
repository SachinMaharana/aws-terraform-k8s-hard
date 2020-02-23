provider "aws" {
  region = var.region
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-*"]
  }
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
}


resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = {
    Name = "kubernetes"
  }
}


resource "aws_subnet" "subnet" {
  vpc_id     = aws_vpc.main.id
  cidr_block = var.vpc_cidr
  tags = {
    Name = "kubernetes"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "kubernetes"
  }
}


resource "aws_route_table" "rt" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = var.all_cidr
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = {
    Name = "kubernetes"
  }
}

resource "aws_route_table_association" "rt-assoc" {
  subnet_id      = aws_subnet.subnet.id
  route_table_id = aws_route_table.rt.id
}

resource "aws_security_group" "kubernetes" {
  name   = "kubernetes-sg"
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "kubernetes"
  }
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "allow_ssh" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  security_group_id = aws_security_group.kubernetes.id
  cidr_blocks       = [var.all_cidr]
}

resource "aws_security_group_rule" "allow_icmp" {
  type              = "ingress"
  from_port         = -1
  to_port           = -1
  protocol          = "icmp"
  security_group_id = aws_security_group.kubernetes.id
  cidr_blocks       = [var.all_cidr]
}

resource "aws_security_group_rule" "allow_https" {
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  security_group_id = aws_security_group.kubernetes.id
  cidr_blocks       = [var.all_cidr]
}
resource "aws_security_group_rule" "allow_http" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  security_group_id = aws_security_group.kubernetes.id
  cidr_blocks       = [var.all_cidr]
}


resource "aws_security_group_rule" "allow_k8s_https" {
  type              = "ingress"
  from_port         = 6443
  to_port           = 6443
  protocol          = "tcp"
  security_group_id = aws_security_group.kubernetes.id
  cidr_blocks       = [var.all_cidr]
}



resource "aws_security_group_rule" "allow_cluster_cidr" {
  type              = "ingress"
  from_port         = -1
  to_port           = -1
  protocol          = "-1"
  security_group_id = aws_security_group.kubernetes.id
  cidr_blocks       = [var.cluster_cidr]
}


resource "aws_security_group_rule" "allow_all" {
  type              = "ingress"
  from_port         = -1
  to_port           = -1
  protocol          = "-1"
  security_group_id = aws_security_group.kubernetes.id
  cidr_blocks       = [var.vpc_cidr]
}


resource "aws_security_group_rule" "allow_all_outgoing_traffic" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = aws_security_group.kubernetes.id
  cidr_blocks       = [var.all_cidr]
}

// Is it necessary?
resource "aws_security_group_rule" "allow_access_from_this_security_group" {
  type                     = "ingress"
  from_port                = -1
  to_port                  = -1
  protocol                 = "-1"
  security_group_id        = aws_security_group.kubernetes.id
  source_security_group_id = aws_security_group.kubernetes.id
}


resource "aws_lb" "lb-k8s" {
  name               = "kubernetes"
  internal           = false
  load_balancer_type = "network"
  subnets            = [aws_subnet.subnet.id]
  ip_address_type    = "ipv4"
  tags = {
    Name = "kubernetes"
  }
}

resource "aws_lb_target_group" "lb_target_grp" {
  name        = "kubernetes"
  port        = 6443
  protocol    = "TCP"
  target_type = "ip"
  vpc_id      = aws_vpc.main.id
}


resource "aws_lb_target_group_attachment" "master1" {
  target_group_arn = aws_lb_target_group.lb_target_grp.arn
  target_id        = "10.240.0.10"
  port             = 6443
}


resource "aws_lb_target_group_attachment" "master2" {
  target_group_arn = aws_lb_target_group.lb_target_grp.arn
  target_id        = "10.240.0.11"
  port             = 6443
}


resource "aws_lb_target_group_attachment" "master3" {
  target_group_arn = aws_lb_target_group.lb_target_grp.arn
  target_id        = "10.240.0.12"
  port             = 6443
}

resource "aws_lb_listener" "kubernetes" {
  load_balancer_arn = aws_lb.lb-k8s.arn
  port              = "443"
  protocol          = "TCP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.lb_target_grp.arn
  }
}

resource "aws_instance" "controller" {
  count                       = var.controller_count
  associate_public_ip_address = true
  ami                         = "ami-0f2b4fc905b0bd1f1"
  key_name                    = "kubernetes"
  vpc_security_group_ids      = [aws_security_group.kubernetes.id]
  instance_type               = "t3.medium"
  private_ip                  = "10.240.0.1${count.index}"
  subnet_id                   = aws_subnet.subnet.id
  connection {
    type        = "ssh"
    user        = "centos"
    private_key = file("/home/sachin/blackhole/aws-terraform-final/kubernetes.pem")
    timeout     = "5m"
    host        = self.public_ip

  }

  provisioner "file" {
    source      = "install_docker.sh"
    destination = "/tmp/install_docker.sh"
  }
  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/install_docker.sh",
      "/tmp/install_docker.sh",
    ]
  }
  source_dest_check = false
  tags = {
    Name = "controller-${count.index}"
  }
  ebs_block_device {
    device_name = "/dev/sda1"
    volume_size = 50
    volume_type = "standard"
  }
}


resource "aws_instance" "worker" {
  count                       = var.worker_count
  associate_public_ip_address = true
  ami                         = "ami-0f2b4fc905b0bd1f1"
  key_name                    = "kubernetes"
  vpc_security_group_ids      = [aws_security_group.kubernetes.id]
  instance_type               = "t3.medium"
  private_ip                  = "10.240.0.2${count.index}"
  subnet_id                   = aws_subnet.subnet.id
  connection {
    type        = "ssh"
    user        = "centos"
    private_key = file("/home/sachin/blackhole/aws-terraform-final/kubernetes.pem")
    timeout     = "5m"
    host        = self.public_ip

  }

  provisioner "file" {
    source      = "install_docker.sh"
    destination = "/tmp/install_docker.sh"
  }
  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/install_docker.sh",
      "/tmp/install_docker.sh",
    ]
  }

  source_dest_check = false
  tags = {
    Name = "worker-${count.index}"
  }
  ebs_block_device {
    device_name = "/dev/sda1"
    volume_size = 50
    volume_type = "standard"
  }
}

resource "aws_instance" "etcd" {
  count                       = var.etcd_count
  associate_public_ip_address = true
  ami                         = "ami-0f2b4fc905b0bd1f1"
  key_name                    = "kubernetes"
  vpc_security_group_ids      = [aws_security_group.kubernetes.id]
  instance_type               = "t3.small"
  private_ip                  = "10.240.0.3${count.index}"
  subnet_id                   = aws_subnet.subnet.id
  source_dest_check           = false
  connection {
    type        = "ssh"
    user        = "centos"
    private_key = file("/home/sachin/blackhole/aws-terraform-final/kubernetes.pem")
    timeout     = "5m"
    host        = self.public_ip

  }

  provisioner "file" {
    source      = "install_docker.sh"
    destination = "/tmp/install_docker.sh"
  }
  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/install_docker.sh",
      "/tmp/install_docker.sh",
    ]
  }
  tags = {
    Name = "etcd-${count.index}"
  }
  ebs_block_device {
    device_name = "/dev/sda1"
    volume_size = 50
    volume_type = "standard"
  }
}


resource "aws_instance" "lb" {
  count                       = var.lb_count
  associate_public_ip_address = true
  ami                         = "ami-0f2b4fc905b0bd1f1"
  key_name                    = "kubernetes"
  vpc_security_group_ids      = [aws_security_group.kubernetes.id]
  instance_type               = "t3.micro"
  private_ip                  = "10.240.0.4${count.index}"
  subnet_id                   = aws_subnet.subnet.id
  source_dest_check           = false
  tags = {
    Name = "lb-${count.index}"
  }

  connection {
    type        = "ssh"
    user        = "centos"
    private_key = file("/home/sachin/blackhole/aws-terraform-final/kubernetes.pem")
    timeout     = "5m"
    host        = self.public_ip

  }

  provisioner "file" {
    source      = "install_docker.sh"
    destination = "/tmp/install_docker.sh"
  }
  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/install_docker.sh",
      "/tmp/install_docker.sh",
    ]
  }
  ebs_block_device {
    device_name = "/dev/sda1"
    volume_size = 50
    volume_type = "standard"
  }
}





# resource "aws_instance" "nfs" {
#   count                       = 1
#   associate_public_ip_address = true
#   ami                         = "ami-0f2b4fc905b0bd1f1"
#   key_name                    = "kubernetes"
#   vpc_security_group_ids      = [aws_security_group.kubernetes.id]
#   instance_type               = "t3.micro"
#   private_ip                  = "10.240.0.5${count.index}"
#   user_data                   = "name=lb-${count.index}|pod-cidr=10.200.${count.index}.0/24"
#   subnet_id                   = aws_subnet.subnet.id
#   source_dest_check           = false
#   tags = {
#     Name = "lb-${count.index}"
#   }
#   ebs_block_device {
#     device_name = "/dev/sda1"
#     volume_size = 75
#     volume_type = "standard"
#   }
# }




