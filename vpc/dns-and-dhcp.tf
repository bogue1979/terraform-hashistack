resource "aws_vpc_dhcp_options" "frankfurtdhcp" {
    domain_name = "${var.DnsZoneName}"
    domain_name_servers = ["AmazonProvidedDNS"]
    tags {
      Name = "Frankfurt DHCP Options"
      environment = "${var.environment_tag}"
    }
}

resource "aws_vpc_dhcp_options_association" "dns_resolver" {
    vpc_id = "${aws_vpc.terraformmain.id}"
    dhcp_options_id = "${aws_vpc_dhcp_options.frankfurtdhcp.id}"
}

#/* DNS PART ZONE AND RECORDS */
#resource "aws_route53_zone" "ffaws" {
#  name = "${var.DnsZoneName}"
#  vpc_id = "${aws_vpc.terraformmain.id}"
#  comment = "Managed by terraform"
#  tags {
#
#    environment = "${var.environment_tag}"
#    product =     "various"
#    team =        "platform"
#
#  }
#}
#
# Example to create an DNS entry
#  resource "aws_route53_record" "database" {
#     zone_id = "${aws_route53_zone.ffaws.zone_id}"
#     name = "mydatabase.${var.DnsZoneName}"
#     type = "A"
#     ttl = "300"
#     records = ["${aws_instance.database.private_ip}"]
#  }

