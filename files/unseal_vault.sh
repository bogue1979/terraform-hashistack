#!/bin/bash

DIR="$(cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd)"

for ip in $(cat $DIR/serverlist.txt ) ; do
  echo "connect to $ip"
  for key in $(grep "Unseal Key" $DIR/vault.keys |tr -d " " | cut -d":" -f 2 | head -n 3); do
    echo "using $key"
    ssh core@$ip "/opt/bin/vault unseal $key"
  done
done

touch $DIR/.unsealed
