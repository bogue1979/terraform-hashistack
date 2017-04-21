#cloud-config
write_files:
  - path: "/etc/vault/config.hcl"
    permissions: "0755"
    owner: "root"
    content: |
      backend  "consul" {
          path = "vault"
      }

      listener "tcp" {
        address = "0.0.0.0:8200"
        # will be enabled via terraform remote executor after certificate deployment
        tls_disable = 1
        tls_cert_file = "/etc/ssl/private/server.crt"
        tls_key_file = "/etc/ssl/private/server.key"
      }
  - path: "/opt/bin/install_consul.sh"
    permissions: "0755"
    owner: "root"
    content: |
      #!/bin/bash
      echo "Grabbing IPs..."
      PRIVATE_IP=$(curl http://169.254.169.254/latest/meta-data/local-ipv4)
      PUBLIC_IP=$(curl http://169.254.169.254/latest/meta-data/public-ipv4)

      echo "Fetching binaries..."
      cd /tmp
      curl -sLo consul.zip https://releases.hashicorp.com/consul/${consul_version}/consul_${consul_version}_linux_amd64.zip
      curl -sLo vault.zip https://releases.hashicorp.com/vault/${vault_version}/vault_${vault_version}_linux_amd64.zip
      curl -sLo nomad.zip https://releases.hashicorp.com/nomad/${nomad_version}/nomad_${nomad_version}_linux_amd64.zip

      echo "Installing Consul..."
      unzip consul.zip >/dev/null
      chmod +x consul
      mv consul /opt/bin/consul

      echo "Installing Vault..."
      unzip vault.zip >/dev/null
      chmod +x vault
      mv vault /opt/bin/vault

      echo "Installing Nomad..."
      unzip nomad.zip >/dev/null
      chmod +x nomad
      mv nomad /opt/bin/nomad

      echo "Configure Consul..."
      mkdir -p /etc/consul
      cat << -EOF > /etc/consul/config.json
      {
        "bind_addr": "$PRIVATE_IP",
        "advertise_addr": "$PRIVATE_IP",
        "advertise_addr_wan": "$PUBLIC_IP",
        "data_dir": "/opt/consul",
        "encrypt": "CkqzRm5kVDBZcPyZFLF7sQ==",
        "log_level": "INFO",
        "disable_update_check": true,
        "disable_remote_exec": true,
        "leave_on_terminate": true,
        ${config}
      }
      EOF
coreos:
  units:
    - name: etcd2.service
      command: stop
    - name: "docker.service"
      command: "stop"
    - name: fleet.service
      command: stop
    - name: install-consul.service
      command: start
      content: |
        [Unit]
        Description=run install script
        After=network.target
        [Service]
        Type=oneshot
        ExecStart=/usr/bin/sh -c "/opt/bin/install_consul.sh"
    - name: consul.service
      command: start
      content: |
        [Unit]
        Description=Consul Service
        After=install-consul.service
        Requires=install-consul.service
        [Service]
        ExecStart=/opt/bin/consul agent -ui -config-dir /etc/consul
    - name: vault.service
      command: start
      content: |
        [Unit]
        Description=Vault Service
        After=consul.service
        Requires=consul.service
        [Service]
        Restart=always
        RestartSec=10s
        ExecStart=/opt/bin/vault server -config /etc/vault/config.hcl
