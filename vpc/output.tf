output "vpc_id" {
  value = "${aws_vpc.terraformmain.id}"
}

output "private_networks" {
  value = ["${aws_subnet.PRIV_A.id}", "${aws_subnet.PRIV_B.id}"]
}
output "dmz_networks" {
  value = ["${aws_subnet.DMZ_A.id}", "${aws_subnet.DMZ_B.id}"]
}
output "private_subnet_a" {
 value =  "${aws_subnet.PRIV_A.id}"
}
output "private_subnet_b" {
 value =  "${aws_subnet.PRIV_B.id}"
}
output "dmz_subnet_a" {
 value =  "${aws_subnet.DMZ_A.id}"
}
output "dmz_subnet_b" {
 value =  "${aws_subnet.DMZ_B.id}"
}
