variable "aws_access_key" {
  default = ""
  description = "the user aws access key"
}
variable "aws_secret_key" {
  default = ""
  description = "the user aws secret key"
}
variable "region" {
  default = "eu-central-1"
}
variable "key_name" { }

variable "servers" {
  default = 3
}
variable "agents" {
  default = 2
}

variable "consul_join_tag_key" {
  default = "role"
}

variable "consul_join_tag_value" {
  default = "consul-server"
}

variable "server_instance_type" {
  default = "t2.medium"
}

variable "agent_instance_type" {
  default = "t2.medium"
}

variable "external_domain" {
  default = "r53.meteogroup.de"
}
variable "internal_domain" {
  default = "hashistack.meteogroup.net"
}
