#!/bin/sh

docker service create -d --name swarm-prune \
	--mount type=bind,source=/var/run/docker.sock,target=/var/run/docker.sock \
	--mode=global --restart-condition on-failure \
	docker ash -c 'docker system prune -a -f --volumes'

while true; do
	container_ids=$(docker service ps swarm-prune -q)
	states=$(docker inspect $container_ids --format='{{.Status.State}}')
	completed=$(echo "$states" | grep -v "complete" -q; echo $?)
	if [ $completed -eq 1 ]; then break; fi
	sleep 3
done

docker service rm swarm-prune
