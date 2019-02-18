#!/bin/sh

OLD_IFS="$IFS"
IFS=","
HOSTS="$*"
IFS="$OLD_IFS"
unset OLD_IFS

CMD="docker run --rm -u $(id -u):$(id -g) -v $(pwd):/certs -w /certs daper/cfssl"

if [ "$1" == "ca" ]; then
	$CMD sh -c "cfssl gencert -initca ca-csr.json | cfssljson -bare ca -" && rm ca.csr
elif [ "$1" == "client" ]; then
	$CMD sh -c "echo '{\"CN\":\"$1\",\"hosts\":[\"\"],\"key\":{\"algo\":\"rsa\",\"size\":4096}}' \
		| cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json \
			-profile=client - \
		| cfssljson -bare $1" \
	&& rm $1.csr \
	&& mkdir -p ~/.docker \
	&& cp ca.pem ~/.docker/ca.pem \
	&& cp $1.pem ~/.docker/cert.pem \
	&& cp $1-key.pem ~/.docker/key.pem
elif [ "$1" == "clean" ]; then
	rm -f *.pem *.csr
elif [ -f ca.pem ]; then
	if [ -n "$1" ]; then
		$CMD sh -c "echo '{\"CN\":\"$1\",\"hosts\":[\"\"],\"key\":{\"algo\":\"rsa\",\"size\":4096}}' \
			| cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json \
				-profile=peer -hostname=\"$HOSTS\" - \
			| cfssljson -bare $1" \
		&& rm $1.csr
		# && $CMD mkbundle -f $1-ca.pem ca.pem $1.pem
	else
		echo "[!] Specify a name for the server"
	fi
else
	echo "[!] Initiate a CA with $0 ca"
fi
