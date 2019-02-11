#!/bin/sh

BOOTSTRAP_SERVICE_NAME=deploy-packetbeat

docker service create -d --name $BOOTSTRAP_SERVICE_NAME \
	--hostname '{{.Node.Hostname}}-packetbeat' \
	--mount type=bind,source=/var/run/docker.sock,target=/var/run/docker.sock \
	--mount type=bind,source=/etc/environment,target=/etc/environment,readonly \
	--mode=global --restart-condition on-failure \
	docker ash -c "\
		docker run -d --name \"\$(hostname)\" \
		--network host --env-file /etc/environment \
		-e ELASTICSEARCH_HOSTS=\$(cat /etc/environment | grep -i public | sed -r 's/.*public_ipv4=([0-9\.]+).*/\1/i'):9200 \
		-e KIBANA_HOST=\$(cat /etc/environment | grep -i public | sed -r 's/.*public_ipv4=([0-9\.]+).*/\1/i'):5601 \
		--user root:packetbeat \
		--entrypoint bash \
		docker.elastic.co/beats/packetbeat-oss:6.6.0 \
		-c \"chmod +x ./packetbeat && ./packetbeat --strict.perms=false\"
	"

while true; do
	container_ids=$(docker service ps $BOOTSTRAP_SERVICE_NAME -q)
	states=$(docker inspect $container_ids --format='{{.Status.State}}')
	completed=$(echo "$states" | grep -v "complete" -q; echo $?)
	if [ $completed -eq 1 ]; then break; fi
	sleep 3
done

docker service rm $BOOTSTRAP_SERVICE_NAME
