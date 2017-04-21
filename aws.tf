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
