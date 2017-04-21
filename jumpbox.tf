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
