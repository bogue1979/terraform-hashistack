
data "aws_ami" "coreos_stable" {
  most_recent = true

  filter {
    name   = "name"
    values = ["CoreOS-stable-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["595879546273"] # CoreOS
}

# Create the user-data for the Consul server
data "template_file" "server" {
  count    = "${var.servers}"
  template = "${file("${path.module}/templates/consul.cloud-init.tpl")}"

  vars {
    consul_version = "0.8.1"
    vault_version = "0.7.0"
    nomad_version = "0.5.6"

    config = <<EOF
       "bootstrap_expect": 3,
       "node_name": "consul-server-${count.index}",
       "retry_join_ec2": {
         "tag_key": "${var.consul_join_tag_key}",
         "tag_value": "${var.consul_join_tag_value}"
       },
       "server": true
    EOF
  }
}
# A security group that makes the instances accessible
resource "aws_security_group" "consul2" {
  vpc_id      = "${module.vpc.vpc_id}"

  name = "Consul-Server"
  tags {
        Name = "Consul"
  }
  description = "Consul Server"

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
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
# Create an IAM role for the auto-join
resource "aws_iam_role" "consul-join" {
  name               = "consul-join"
  assume_role_policy = "${file("${path.module}/templates/policies/assume-role.json")}"
}

# Create the policy
resource "aws_iam_policy" "consul-join" {
  name        = "consul-join"
  description = "Allows Consul nodes to describe instances for joining."
  policy      = "${file("${path.module}/templates/policies/describe-instances.json")}"
}

# Attach the policy
resource "aws_iam_policy_attachment" "consul-join" {
  name       = "consul-join"
  roles      = ["${aws_iam_role.consul-join.name}"]
  policy_arn = "${aws_iam_policy.consul-join.arn}"
}

# Create the instance profile
resource "aws_iam_instance_profile" "consul-join" {
  name  = "consul-join"
  roles = ["${aws_iam_role.consul-join.name}"]
}

# Create the Consul cluster
resource "aws_instance" "server" {
  count = "${var.servers}"
  ami           = "${data.aws_ami.coreos_stable.id}"
  instance_type = "${var.server_instance_type}"
  key_name      = "${var.key_name}"
  associate_public_ip_address = "true"
  subnet_id              = "${element(module.vpc.dmz_networks, count.index)}"
  iam_instance_profile   = "${aws_iam_instance_profile.consul-join.name}"
  vpc_security_group_ids = ["${aws_security_group.consul2.id}"]
  tags = "${map(
    "Name", "consul-server-${count.index}",
    var.consul_join_tag_key, var.consul_join_tag_value
  )}"
  user_data = "${element(data.template_file.server.*.rendered, count.index)}"

  provisioner "local-exec" {
    command = "${path.module}/files/generate_cert.sh ${self.tags.Name} 127.0.0.1,${self.private_ip},vault.${var.external_domain},nomad.${var.external_domain},consul.${var.external_domain} peer"
  }

  provisioner "file" {
    connection {
      type     = "ssh"
      user     = "core"
    }
    source = "${path.module}/files/ca/certs/consul-server-${count.index}.tgz"
    destination = "/home/core/certs.tgz"
  }
  provisioner "remote-exec" {
    connection {
      type     = "ssh"
      user     = "core"
    }
    inline = [
      "tar xzf certs.tgz",
      "sudo cp ca.pem /etc/ssl/certs",
      "sudo update-ca-certificates",
      "sudo cp consul-server-${count.index}-key.pem /etc/ssl/private/server.key",
      "sudo cp consul-server-${count.index}.pem /etc/ssl/private/server.pem",
      "sudo cp consul-server-${count.index}.crt /etc/ssl/private/server.crt",
      "sudo sed -i \"s/tls_disable = 1/tls_disable = 0/\" /etc/vault/config.hcl",
      "sudo systemctl restart vault"
    ]
  }
}


