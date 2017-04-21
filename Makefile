plan:
	terraform plan -var key_name=datacenter-admin-ff

apply:
	terraform apply -var key_name=datacenter-admin-ff


destroy:
	terraform destroy -var key_name=datacenter-admin-ff
	rm -rf files/ca/certs/*

ca: files/ca/certs/ca.pem

files/ca/certs/ca.pem:
	echo generate ca certificates
	cfssl gencert -initca files/ca/ca-csr.json | cfssljson -bare files/ca/certs/ca
