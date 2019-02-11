#!/bin/sh

etcd-ca new-cert --passphrase '' --ip $2 --domain $1 $1 \
&& etcd-ca sign --passphrase '' $1 \
&& etcd-ca export --insecure --passphrase '' $1 | tar xvf - \
&& etcd-ca chain $1 > $1.ca.crt \
&& mv $1.key.insecure $1.key

wait
