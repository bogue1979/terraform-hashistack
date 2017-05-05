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


variable "vpn_network" {
  default = "172.27.0.0/16"
}

resource "aws_security_group" "jumphost" {
  name = "jumphost"
  tags {
        Name = "jumphost"
  }
  description = "Jumphost"
  vpc_id = "${module.vpc.vpc_id}"

  ingress {
        from_port   = 22
        to_port     = 22
        protocol    = "TCP"
        cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 1194
    to_port     = 1194
    protocol    = "UDP"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

data "aws_ami" "debian_stable" {
  most_recent = true

  filter {
    name   = "name"
    values = ["debian-jessie-amd64-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["379101102735"] # Debian
}

resource "aws_instance" "jumphost" {
  ami           = "${data.aws_ami.debian_stable.id}"
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
  user_data = <<HEREDOC
#!/bin/bash
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get -y install openvpn iptables-persistent
mkdir -p /etc/openvpn/keys/
openssl dhparam -out /etc/openvpn/keys/dh2048.pem 2048 &
iptables -t nat -A POSTROUTING -o eth0  -j MASQUERADE
echo "net.ipv4.ip_forward = 1" > /etc/sysctl.d/30-ip_forwrding.conf
sysctl -p /etc/sysctl.d/30-ip_forwrding.conf
iptables-save > /etc/iptables/rules.v4

cat <<EOF > /etc/openvpn/server.conf
port 1194
proto udp
dev tun
server ${element(split("/",var.vpn_network),0)} ${cidrnetmask(var.vpn_network)}
push "route ${element(split("/",module.vpc.vpc-fullcidr),0)} ${cidrnetmask(module.vpc.vpc-fullcidr)}"
ca /etc/openvpn/keys/ca.pem
cert /etc/openvpn/keys/server.pem
key /etc/openvpn/keys/server.key
dh /etc/openvpn/keys/dh2048.pem
tls-version-min 1.2
tls-cipher TLS-ECDHE-RSA-WITH-AES-128-GCM-SHA256:TLS-ECDHE-ECDSA-WITH-AES-128-GCM-SHA256:TLS-ECDHE-RSA-WITH-AES-256-GCM-SHA384:TLS-DHE-RSA-WITH-AES-256-CBC-SHA256
cipher AES-256-CBC
auth SHA512
ifconfig-pool-persist ipp.txt
keepalive 10 120
comp-lzo
persist-key
persist-tun
status openvpn-status.log
log-append  /var/log/openvpn.log
verb 3
max-clients 100
user nobody
group nogroup
EOF

HEREDOC

  provisioner "local-exec" {
    command = "${path.module}/files/generate_cert.sh ${self.tags.Name} 127.0.0.1,${self.private_ip} server"
  }

  provisioner "file" {
    connection {
        type              = "ssh"
        user              = "admin"
    }
    source      = "${path.module}/files/ca/certs/jumphost.tgz"
    destination = "/home/admin/certs.tgz"
  }

  provisioner "remote-exec" {
    connection {
      type              = "ssh"
      user              = "admin"
    }
    inline = [
      "tar xzf certs.tgz",
      "while ! [ -f /etc/openvpn/keys/dh2048.pem ] ; do echo wait for dh ; sleep 10 ; done",
      "sudo cp ca.pem /etc/openvpn/keys",
      "sudo cp jumphost-key.pem /etc/openvpn/keys/server.key",
      "sudo cp jumphost.pem /etc/openvpn/keys/server.pem",
      "sudo systemctl enable openvpn@server",
      "sudo systemctl start openvpn@server"
    ]
  }
}
