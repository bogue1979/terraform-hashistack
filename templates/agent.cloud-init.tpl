#cloud-config
write_files:
  - path: "/etc/systemd/resolved.conf"
    permissions: "0644"
    owner: "root"
    content: |
      [Resolve]
      DNS=127.0.0.1
  - path: "/etc/nomad/nomad-tls.hcl"
    permissions: "0644"
    owner: "root"
    content: |
      tls {
        http = true
        rpc  = true
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
      curl -sLo nomad.zip https://releases.hashicorp.com/nomad/${nomad_version}/nomad_${nomad_version}_linux_amd64.zip

      echo "Installing Consul..."
      unzip consul.zip >/dev/null
      chmod +x consul
      mv consul /opt/bin/consul

      echo "Installing Nomad..."
      unzip nomad.zip >/dev/null
      chmod +x nomad
      mv nomad /opt/bin/nomad

      echo "Configure Consul..."
      mkdir -p /etc/consul
      cat << EOF > /etc/consul/config.json
      {
        "bind_addr": "$PRIVATE_IP",
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
      data_dir = "/var/lib/docker/nomad"
      bind_addr = "0.0.0.0"
      name = "$PRIVATE_IP"
      region = "$REGION"
      disable_anonymous_signature = true
      disable_update_check = true
      leave_on_interrupt = true
      leave_on_terminate = true
      advertise {
         http = "$PRIVATE_IP"
         rpc  = "$PRIVATE_IP"
         serf = "$PRIVATE_IP"
      }
      server {
          enabled = false
      }
      client {
          enabled = true
      }
      consul {
            address = "127.0.0.1:8500"
      }
      #vault {
      #   enabled = true
      #   address = "https://vault.service.consul:8200"
      #   create_from_role = "nomad-cluster"
      #}
      EOF
coreos:
  units:
    - name: etcd2.service
      command: stop
    - name: fleet.service
      command: stop
    - name: format-docker-disk.service
      runtime: true
      command: start
      content: |
        [Unit]
        Description=Format XVDB
        Before=docker.service
        Before=docker-early.service
        [Service]
        Type=oneshot
        RemainAfterExit=yes
        ExecStart=-/usr/sbin/wipefs -f /dev/xvdb
        ExecStart=-/usr/sbin/mkfs.xfs /dev/xvdb
    - name: var-lib-docker.mount
      command: start
      content: |
        [Unit]
        Description=Mount storage to /var/lib/docker
        Requires=format-docker-disk.service
        After=format-docker-disk.service
        Before=docker.service
        Before=docker-early.service
        [Mount]
        What=/dev/xvdb
        Where=/var/lib/docker
        Type=xfs
    - name: docker.service
      command: start
      drop-ins:
        - name: 10-wait-docker.conf
          content: |
            [Unit]
            After=var-lib-docker.mount
            Requires=var-lib-docker.mount
            Restart=always
            [Service]
            Environment=DOCKER_OPTS=--bip=172.21.0.1/16 --fixed-cidr=172.21.0.0/16 --dns=172.21.0.1 --dns=${dns_server}
    - name: dnsmasq.service
      command: start
      content: |
        [Unit]
        Description=dnsmasq
        After=docker.service
        [Service]
        Slice=machine.slice
        ExecStartPre=/usr/bin/rkt trust --trust-keys-from-https --prefix coreos.com/dnsmasq
        ExecStartPre=/usr/bin/rkt trust --trust-keys-from-https --prefix quay.io/coreos/alpine-sh
        ExecStart=/usr/bin/rkt run coreos.com/dnsmasq:v0.3.0 --net=host --dns ${dns_server} --  -k --interface=docker0 --conf-file= --bind-interfaces --server=/consul/127.0.0.1#8600
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
        ExecStart=/opt/bin/consul agent -config-dir /etc/consul
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
