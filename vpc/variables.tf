variable "region" {
  default = "eu-central-1"
}

variable "environment_tag" {
  default = "recovery"
}

variable "aws_access_key" {
  default = ""
  description = "the user aws access key"
}

variable "aws_secret_key" {
  default = ""
  description = "the user aws secret key"
}

variable "vpc-fullcidr" {
  default = "10.4.0.0/16"
  description = "the vpc Network range"
}

variable "Subnet-DMZ-A-CIDR" {
  default = "10.4.3.0/24"
  description = "the cidr of the DMZ-A"
}

variable "Subnet-DMZ-B-CIDR" {
  default = "10.4.4.0/24"
  description = "the cidr of the DMZ-B"
}

variable "Subnet-PRIV-A-CIDR" {
  default = "10.4.1.0/24"
  description = "the cidr of the PRIV-A"
}

variable "Subnet-PRIV-B-CIDR" {
  default = "10.4.2.0/24"
  description = "the cidr of the PRIV-B"
}

variable "DnsZoneName" {
  default = "ffaws.meteogroup.net"
  description = "the internal dns name"
}

variable "name" {
  default = ""
  description = "VPC Name"
}
