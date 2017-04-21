plan:
	terraform plan -var key_name=datacenter-admin-ff

apply:
	terraform apply -var key_name=datacenter-admin-ff


destroy:
	terraform destroy -var key_name=datacenter-admin-ff
	rm -rf files/ca/certs/* files/.unsealed files/serverlist.txt

ca: files/ca/certs/ca.pem
files/ca/certs/ca.pem:
	echo generate ca certificates
	cfssl gencert -initca files/ca/ca-csr.json | cfssljson -bare files/ca/certs/ca

unseal: files/.unsealed
files/.unsealed: files/vault.keys
	files/unseal_vault.sh

files/vault.keys:
	ssh core@$(shell cut -d" " -f 1 ./files/serverlist.txt ) "/opt/bin/vault init" > ./files/vault.keys

reset_vault:
	rm -f ./files/vault.keys ./files/.unsealed
