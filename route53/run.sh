#!/bin/sh

if ! docker image ls --format '{{.Repository}}:{{.Tag}}' | grep -q -F 'daper/route53-updater'; then
	docker build -t daper/route53-updater .
fi

docker run --rm -it -w /root \
	-v $(pwd)/update_domains.py:/root/update_domains.py \
	-v $(pwd)/dns_calls.json:/root/dns_calls.json \
	-v $(pwd)/../../aws:/root/.aws \
	daper/route53-updater
