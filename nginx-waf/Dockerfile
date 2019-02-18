FROM nginx:alpine

LABEL maintainer="david@daper.email"

RUN apk add --no-cache --virtual .build-deps \
        gcc \
        libc-dev \
        make \
        openssl-dev \
        pcre-dev \
        zlib-dev \
        linux-headers \
        gnupg \
        libxslt-dev \
        gd-dev \
        perl-dev \
    && apk add --no-cache --virtual .libmodsecurity-deps \
        pcre-dev \
        libxml2-dev \
        git \
        libtool \
        automake \
        autoconf \
        g++ \
        flex \
        bison \
        yajl-dev \
        libmaxminddb-dev \
        geoip-dev \
        curl-dev \
    && apk add --no-cache \
        geoip \
        yajl \
        libstdc++ \
        git \
        sed \
        curl \
        libmaxminddb

RUN mkdir -p /opt/ModSecurity && cd /opt/ModSecurity \
    && git clone -b v3/master --single-branch https://github.com/SpiderLabs/ModSecurity . \
    && git submodule init \
    && git submodule update \
    && ./build.sh \
    && ./configure \
        --disable-doxygen-doc \
        --disable-examples \
        --with-curl=/usr/bin \
    && make && make check \
    && make install

# Installing ModSec - Nginx connector
RUN cd /opt \
    && git clone --depth 1 https://github.com/SpiderLabs/ModSecurity-nginx.git \
    && wget http://nginx.org/download/nginx-$NGINX_VERSION.tar.gz \
    && tar zxvf nginx-$NGINX_VERSION.tar.gz

RUN mkdir /opt/GeoIP && cd /opt/GeoIP \
    && git clone -b master --single-branch https://github.com/leev/ngx_http_geoip2_module.git .

RUN cd /opt/nginx-$NGINX_VERSION \
    && ./configure \
        --with-compat \
        --add-dynamic-module=../ModSecurity-nginx  \
        --add-dynamic-module=../GeoIP \
    && make modules \
    && cp objs/ngx_http_modsecurity_module.so objs/ngx_http_geoip2_module.so /etc/nginx/modules

# Begin installing ModSec OWASP Rules
RUN cd /opt \
    && git clone -b v3.0/master https://github.com/SpiderLabs/owasp-modsecurity-crs \
    && mv owasp-modsecurity-crs/ /usr/local/

RUN mkdir /etc/nginx/modsec \
    && rm -fr /etc/nginx/conf.d/ \
    && rm -fr /etc/nginx/nginx.conf

RUN mkdir -p /etc/nginx/geoip \
    && cd /opt \
    && wget http://geolite.maxmind.com/download/geoip/database/GeoLite2-City.tar.gz \
    && wget http://geolite.maxmind.com/download/geoip/database/GeoLite2-Country.tar.gz \
    && tar -xvzf GeoLite2-City.tar.gz --strip-components=1 \
    && tar -xvzf GeoLite2-Country.tar.gz --strip-components=1 \
    && mv *.mmdb /etc/nginx/geoip/

#delete uneeded and clean up
RUN apk del .build-deps .libmodsecurity-deps \
    && rm -rf /opt

COPY conf/nginx/ /etc/nginx/
COPY conf/modsec/ /etc/nginx/modsec/
COPY conf/owasp/ /usr/local/owasp-modsecurity-crs/
COPY errors /usr/share/nginx/errors

RUN chown -R nginx:nginx /usr/share/nginx /etc/nginx

WORKDIR /usr/share/nginx/html