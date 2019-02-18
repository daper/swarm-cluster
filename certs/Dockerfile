FROM golang:alpine3.9 AS builder

RUN apk add git gcc g++ \
	&& export CLONE_DIR=$GOPATH/src/github.com/cloudflare/cfssl \
	&& mkdir -p $CLONE_DIR \
	&& git clone https://github.com/cloudflare/cfssl $CLONE_DIR \
	&& cd $CLONE_DIR \
	&& git checkout 1.3.2 \
	&& for pkg in $(ls cmd); do \
		go install $CLONE_DIR/cmd/$pkg; \
	done

FROM scratch

ENV PATH=/bin:/go/bin
COPY --from=builder /lib/ld-musl-x86_64.so.1 /lib/ld-musl-x86_64.so.1 
COPY --from=builder /bin/sh /bin/sh
COPY --from=builder /go/bin /go/bin