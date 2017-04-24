provider "aws" {
  access_key = "${var.aws_access_key}"
  secret_key = "${var.aws_secret_key}"
  region     = "${var.region}"
}

module "vpc" {
  source             = "./vpc"
  region             = "eu-central-1"
  name               = "Hashistack"
  vpc-fullcidr       = "10.40.0.0/16"
  Subnet-DMZ-A-CIDR  = "10.40.3.0/24"
  Subnet-DMZ-B-CIDR  = "10.40.4.0/24"
  Subnet-PRIV-A-CIDR = "10.40.1.0/24"
  Subnet-PRIV-B-CIDR = "10.40.2.0/24"
  DnsZoneName        = "${var.internal_domain}"
  environment_tag    = "recovery"
}

resource "aws_security_group" "jumphost" {
  name = "jumphost"
  tags {
        Name = "jumphost"
  }
  description = "Jumphost"
  vpc_id = "${module.vpc.vpc_id}"

  ingress {
        from_port = 22
        to_port = 22
        protocol = "TCP"
        cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
resource "aws_instance" "jumphost" {
  ami           = "${data.aws_ami.coreos_stable.id}"
  instance_type = "t2.micro"
  associate_public_ip_address = "true"
  subnet_id = "${module.vpc.dmz_subnet_a}"
  vpc_security_group_ids = ["${aws_security_group.jumphost.id}"]
  key_name = "${var.key_name}"
  root_block_device {
    delete_on_termination = true
    volume_type = "gp2"
  }
  tags {
        Name = "jumphost"
        team = "platform"
        product = "hashistack"
  }
#  user_data = <<HEREDOC
#  #!/bin/bash
#  yum update -y
#  rpm -Uvh https://yum.puppetlabs.com/puppetlabs-release-pc1-el-7.noarch.rpm
#HEREDOC
}
