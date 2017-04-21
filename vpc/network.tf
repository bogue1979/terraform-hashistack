provider "aws" {
  access_key = "${var.aws_access_key}"
  secret_key = "${var.aws_secret_key}"
  region     = "${var.region}"
}

resource "aws_vpc" "terraformmain" {
    cidr_block = "${var.vpc-fullcidr}"
   #### this 2 true values are for use the internal vpc dns resolution
    enable_dns_support = true
    enable_dns_hostnames = true
    tags {
      Name = "${var.name}"
      environment = "${var.environment_tag}"
    }
}

# Declare the data source
data "aws_availability_zones" "available" {}

/* EXTERNAL NETWORG , IG, ROUTE TABLE */
resource "aws_internet_gateway" "gw" {
   vpc_id = "${aws_vpc.terraformmain.id}"
    tags {
      environment = "${var.environment_tag}"
        Name = "internet gw terraform generated"
    }
}

resource "aws_route_table" "public" {
  vpc_id = "${aws_vpc.terraformmain.id}"
  tags {
      environment = "${var.environment_tag}"
      Name = "Public"
  }
  route {
        cidr_block = "0.0.0.0/0"
        gateway_id = "${aws_internet_gateway.gw.id}"
    }
}

resource "aws_route_table" "private" {
  vpc_id = "${aws_vpc.terraformmain.id}"
  tags {
      environment = "${var.environment_tag}"
      Name = "Private"
  }
  route {
        cidr_block = "0.0.0.0/0"
        nat_gateway_id = "${aws_nat_gateway.NAT_A.id}"
  }
}

resource "aws_subnet" "DMZ_A" {
  vpc_id = "${aws_vpc.terraformmain.id}"
  cidr_block = "${var.Subnet-DMZ-A-CIDR}"
  tags {
      environment = "${var.environment_tag}"
        Name = "DMZ_A"
  }
 availability_zone = "${data.aws_availability_zones.available.names[0]}"
}
resource "aws_subnet" "DMZ_B" {
  vpc_id = "${aws_vpc.terraformmain.id}"
  cidr_block = "${var.Subnet-DMZ-B-CIDR}"
  tags {
      environment = "${var.environment_tag}"
        Name = "DMZ_B"
  }
 availability_zone = "${data.aws_availability_zones.available.names[1]}"
}
resource "aws_subnet" "PRIV_A" {
  vpc_id = "${aws_vpc.terraformmain.id}"
  cidr_block = "${var.Subnet-PRIV-A-CIDR}"
  tags {
      environment = "${var.environment_tag}"
        Name = "PRIV_A"
  }
 availability_zone = "${data.aws_availability_zones.available.names[0]}"
}
resource "aws_subnet" "PRIV_B" {
  vpc_id = "${aws_vpc.terraformmain.id}"
  cidr_block = "${var.Subnet-PRIV-B-CIDR}"
  tags {
      environment = "${var.environment_tag}"
        Name = "PRIV_B"
  }
 availability_zone = "${data.aws_availability_zones.available.names[1]}"
}

resource "aws_route_table_association" "DMZ_A" {
    subnet_id = "${aws_subnet.DMZ_A.id}"
    route_table_id = "${aws_route_table.public.id}"
}
resource "aws_route_table_association" "DMZ_B" {
    subnet_id = "${aws_subnet.DMZ_B.id}"
    route_table_id = "${aws_route_table.public.id}"
}
resource "aws_route_table_association" "PRIV_A" {
    subnet_id = "${aws_subnet.PRIV_A.id}"
    route_table_id = "${aws_route_table.private.id}"
}
resource "aws_route_table_association" "PRIV_B" {
    subnet_id = "${aws_subnet.PRIV_B.id}"
    route_table_id = "${aws_route_table.private.id}"
}

resource "aws_eip" "forNat" {
    vpc      = true
}
resource "aws_nat_gateway" "NAT_A" {
    allocation_id = "${aws_eip.forNat.id}"
    subnet_id = "${aws_subnet.DMZ_A.id}"
    depends_on = ["aws_internet_gateway.gw"]
}
