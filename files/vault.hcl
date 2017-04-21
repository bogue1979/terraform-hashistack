disable_mlock = true

backend "consul" {
    path = "vault"
}

listener "tcp" {
  address = "10.40.3.189:8200"
  tls_cert_file = "/etc/ssl/private/vault.crt"
  tls_key_file = "/etc/ssl/private/vault-key.pem"
}
