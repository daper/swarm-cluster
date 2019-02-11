#!/bin/sh

hosts=$(cat tmp.txt | cut -f1 -d ' ')

docker run --name init \
	--rm -it -w /ca \
	-v $(pwd)/../certs:/ca \
	--user 1000:1000 \
	daper/etcd-ca init --passphrase ''

for host in $hosts; do
	ip=$(cat tmp.txt | grep sw-node-1 | cut -f3 -d '=')
	docker run --name $host \
	--rm -it -w /ca \
	-v $(pwd)/../certs:/ca \
	--user 1000:1000 \
	--entrypoint bash \
	daper/etcd-ca ./gen.sh $host $ip && sleep 5
done
