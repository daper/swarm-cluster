FROM golang

RUN git clone https://github.com/coreos/etcd-ca \
	&& cd etcd-ca \
	&& ./build \
	&& cp bin/etcd-ca /go/bin


ENTRYPOINT [ "/go/bin/etcd-ca" ]
