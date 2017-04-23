# A security group that makes the instances accessible
resource "aws_security_group" "agents" {
  vpc_id      = "${module.vpc.vpc_id}"

  name        = "Nomad-Agents"
  tags {
        Name  = "NomadAgents"
  }
  description = "Nomad Agents"

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["10.40.0.0/16"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
data "template_file" "agent" {
  count    = "${var.agents}"
  template = "${file("${path.module}/templates/agent.cloud-init.tpl")}"

  vars {
    consul_version = "0.8.1"
    vault_version  = "0.7.0"
    nomad_version  = "0.5.6"
    dns_server     = "10.40.0.2"

    config = <<EOF
       "node_name": "nomad-agent-${count.index}",
       "retry_join_ec2": {
         "tag_key": "${var.consul_join_tag_key}",
         "tag_value": "${var.consul_join_tag_value}"
       },
       "server": false
    EOF
  }
}

# Create the Consul cluster
resource "aws_instance" "agent" {
  count                       = "${var.agents}"
  ami                         = "${data.aws_ami.coreos_stable.id}"
  instance_type               = "${var.agent_instance_type}"
  key_name                    = "${var.key_name}"
  associate_public_ip_address = "false"
  subnet_id                   = "${element(module.vpc.private_networks, count.index)}"
  iam_instance_profile        = "${aws_iam_instance_profile.consul-join.name}"
  vpc_security_group_ids      = ["${aws_security_group.agents.id}"]
  tags = "${map(
    "Name", "nomad-agent-${count.index}",
  )}"
  user_data = "${element(data.template_file.agent.*.rendered, count.index)}"
  ebs_block_device {
    device_name               = "/dev/xvdb"
    delete_on_termination     = true
    volume_type               = "gp2"
    volume_size               = "30"
  }

  provisioner "local-exec" {
    command = "${path.module}/files/generate_cert.sh ${self.tags.Name} 127.0.0.1,${self.private_ip} peer"
  }

  provisioner "file" {
    connection {
        type              = "ssh"
        user              = "core"
        bastion_host      = "${aws_instance.jumphost.public_ip}"
        bastion_host_user = "core"
    }
    source      = "${path.module}/files/ca/certs/nomad-agent-${count.index}.tgz"
    destination = "/home/core/certs.tgz"
  }
  provisioner "remote-exec" {
    connection {
      type              = "ssh"
      user              = "core"
      bastion_host      = "${aws_instance.jumphost.public_ip}"
      bastion_host_user = "core"
    }
    inline = [
      "tar xzf certs.tgz",
      "sudo cp ca.pem /etc/ssl/certs",
      "sudo update-ca-certificates > /dev/null",
      "sudo cp nomad-agent-${count.index}-key.pem /etc/ssl/private/server.key",
      "sudo cp nomad-agent-${count.index}.pem /etc/ssl/private/server.pem",
      "sudo cp nomad-agent-${count.index}.crt /etc/ssl/private/server.crt",
      "sudo systemctl restart nomad"
    ]
  }
}
