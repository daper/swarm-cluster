#!/bin/sh

docker service ls --format '{{.Name}}' | grep -q registry
if [ $? -ne 0 ]; then
	docker service create --name registry \
		--publish published=5000,target=5000 \
		--constraint=node.hostname==sw-node-1 \
		--mount=type=bind,src=/etc/ssl,dst=/certs \
		-e REGISTRY_HTTP_TLS_CERTIFICATE=/certs/sw-node-1.pem \
		-e REGISTRY_HTTP_TLS_KEY=/certs/sw-node-1-key.pem \
		registry:2
fi

docker build -t sw-node-1:5000/php-fpm php-fpm
docker push sw-node-1:5000/php-fpm

docker build -t sw-node-1:5000/nginx nginx-waf
docker push sw-node-1:5000/nginx