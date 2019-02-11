#!/bin/sh

for host in $(cat hosts | grep ssh_host | sed -r 's/.*host=([0-9\.]+).*/\1/'); do
	echo "connecting to $host" \
	&& ssh -q core@$host -i <PATH_TO_PRIVATE_KEY> exit \
	&& echo "success" || echo "failed"
done
