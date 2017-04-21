resource "null_resource" "local_ca" {
  provisioner "local-exec" {
    command = "make ca"
  }
}

