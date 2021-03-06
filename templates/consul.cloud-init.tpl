#cloud-config
write_files:
  - path: "/etc/systemd/resolved.conf"
    permissions: "0644"
    owner: "root"
    content: |
      [Resolve]
      DNS=127.0.0.1
  - path: "/etc/vault/config.hcl"
    permissions: "0644"
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
  - path: "/etc/nomad/nomad-tls.hcl"
    permissions: "0644"
    owner: "root"
    content: |
      tls {
        http = true
        rpc  = false

        ca_file   = "/etc/ssl/certs/ca.pem"
        cert_file = "/etc/ssl/private/server.pem"
        key_file  = "/etc/ssl/private/server.key"
      }
  - path: "/opt/bin/install_hashistack.sh"
    permissions: "0755"
    owner: "root"
    content: |
      #!/bin/bash
      echo "Grabbing IPs..."
      PRIVATE_IP=$(curl http://169.254.169.254/latest/meta-data/local-ipv4)
      PUBLIC_IP=$(curl http://169.254.169.254/latest/meta-data/public-ipv4)
      AZ=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)
      REGION=$(echo $${AZ::-1})

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
        #"advertise_addr_wan": "$PUBLIC_IP",
      cat << EOF > /etc/consul/config.json
      {
        "addresses": {
          "https": "0.0.0.0",
          "dns": "0.0.0.0",
          "http": "0.0.0.0"
        },
        "advertise_addr": "$PRIVATE_IP",
        "data_dir": "/opt/consul",
        "encrypt": "CkqzRm5kVDBZcPyZFLF7sQ==",
        "log_level": "INFO",
        "disable_update_check": true,
        "disable_remote_exec": true,
        "leave_on_terminate": true,
        ${config}
      }
      EOF

      echo "Configure Nomad Server..."
      mkdir -p /etc/nomad
      cat << EOF > /etc/nomad/server.hcl
      log_level = "INFO"
      data_dir = "/opt/nomad"
      bind_addr = "0.0.0.0"
      name = "$PRIVATE_IP"
      region = "$REGION"
      disable_anonymous_signature = true
      disable_update_check = true
      advertise {
         http = "$PRIVATE_IP"
         rpc  = "$PRIVATE_IP"
         serf = "$PRIVATE_IP"
      }
      server {
          enabled = true
          bootstrap_expect = 3
          encrypt = "pvnHNw3Pzi04BwlOMLgV0w=="
      }
      client {
          enabled = false
      }
      consul {
            address = "127.0.0.1:8500"
      }
      #vault {
      #   enabled = true
      #   address = "http://$PRIVATE_IP:8200"
      #   create_from_role = "nomad-cluster"
      #}
      EOF
coreos:
  units:
    - name: etcd2.service
      command: stop
    - name: "docker.service"
      command: "stop"
    - name: fleet.service
      command: stop
    - name: dnsmasq.service
      command: start
      content: |
        [Unit]
        Description=dnsmasq
        After=network.target

        [Service]
        Slice=machine.slice
        ExecStartPre=/usr/bin/rkt trust --trust-keys-from-https --prefix coreos.com/dnsmasq
        ExecStartPre=/usr/bin/rkt trust --trust-keys-from-https --prefix quay.io/coreos/alpine-sh
        ExecStart=/usr/bin/rkt run coreos.com/dnsmasq:v0.3.0 --net=host --dns ${dns_server} --  -k --conf-file= --bind-interfaces --server=/consul/127.0.0.1#8600
        KillMode=mixed
        Restart=always
    - name: install-consul.service
      command: start
      content: |
        [Unit]
        Description=run install script
        After=network.target
        [Service]
        Type=oneshot
        ExecStart=/usr/bin/sh -c "/opt/bin/install_hashistack.sh"
        # workaround for /etc/systemd/resolved.conf change which is ignored on first boot
        ExecStartPost=/bin/systemctl restart systemd-resolved
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
    - name: nomad.service
      command: start
      content: |
        [Unit]
        Description=Nomad Server Service
        After=consul.service
        Requires=consul.service
        [Service]
        Restart=always
        RestartSec=10s
        ExecStart=/opt/bin/nomad agent -config /etc/nomad
