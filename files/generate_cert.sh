#!/bin/bash

for name in cfssl cfssljson ; do
  if ! which $name >/dev/null; then
    echo "ERROR: could not find $name in $PATH"
    exit 1
  fi
done

function printhelp() {
  echo HELP:
  echo
  echo "$0 BASE NAMES PROFILE"
  echo
  echo "Example:"
  echo "$0 vault-1 vault-1.internal.com,10.40.10.20,vault.r53.external.domain server"
  echo
  echo "allowed profiles: [ peer|server|client ]"
  exit 1
}

DIR="$(cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd)"

BASE=$1
[ ${BASE}x != x ] || printhelp
NAMES=$2
[ ${NAMES}x != x ] || printhelp
PROFILE=$3
[ ${PROFILE}x != x ] || printhelp
if ! echo $PROFILE | grep -e "^peer$\|^server$\|^client$" ; then
  echo "allowed profiles: [ peer|server|client ]"
  exit 1
fi

echo "{\"CN\":\"$BASE\",\"host\":[\"\"],\"key\":{\"algo\":\"rsa\",\"size\":2048}}" | cfssl gencert -ca=$DIR/ca/certs/ca.pem -ca-key=$DIR/ca/certs/ca-key.pem -config=$DIR/ca/ca-config.json -profile=$PROFILE -hostname="$NAMES" - | cfssljson -bare $DIR/ca/certs/$BASE
cat $DIR/ca/certs/$BASE.pem $DIR/ca/certs/ca.pem > $DIR/ca/certs/$BASE.crt

cd $DIR/ca/certs

tar czf $BASE.tgz ca.pem ${BASE}*
