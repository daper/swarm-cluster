FROM php:fpm-alpine

LABEL maintainer="david@daper.email"

RUN apk add --virtual .build_deps \
        autoconf \
        gcc \
        g++ \
        make \
        libpng-dev \
        libjpeg-turbo-dev \
        libwebp-dev \
        libxpm-dev \
        freetype-dev \
    && apk add \
        libjpeg-turbo \
        libpng \
        libwebp \
        libxpm \
        freetype

RUN docker-php-ext-install \
        exif \
        mysqli \
        pdo_mysql \
        sockets \
    && docker-php-ext-configure gd \
        --with-webp-dir=/usr/lib \
        --with-jpeg-dir=/usr/lib \
        --with-png-dir=/usr/lib \
        --with-xpm-dir=/usr/lib \
        --with-freetype-dir=/usr/lib \
    && docker-php-ext-install gd

# Install redis extension
RUN pecl install igbinary \
    && docker-php-ext-enable igbinary.so \
    && yes | pecl install redis \
    && docker-php-ext-enable redis.so \
    && apk del --purge .build_deps

# Install composer
RUN wget "https://getcomposer.org/installer" -O composer-setup.php \
    && php composer-setup.php --install-dir=/usr/local/bin --filename=composer

RUN addgroup -S nginx && \
    adduser -D -S -h /var/cache/nginx -s /sbin/nologin -G nginx nginx && \
    echo -e 'cgi.fix_pathinfo=0\n \
            post_max_size = 8M\n \
            variables_order= \"GPCS\"\n \
            short_open_tag = Off\n \
            error_reporting = E_ALL & ~E_DEPRECATED & ~E_STRICT\n \
            log_errors = On\n \
            file_uploads = Off\n \
            memory_limit = 128M'\
            >>/usr/local/etc/php/conf.d/docker-vars.ini && \
    sed -i \
        -e "s/;catch_workers_output\s*=\s*yes/catch_workers_output = yes/g" \
        -e "s/pm.max_children = 5/pm.max_children = 4/g" \
        -e "s/pm.start_servers = 2/pm.start_servers = 3/g" \
        -e "s/pm.min_spare_servers = 1/pm.min_spare_servers = 2/g" \
        -e "s/pm.max_spare_servers = 3/pm.max_spare_servers = 4/g" \
        -e "s/;pm.max_requests = 500/pm.max_requests = 200/g" \
        -e "s/user = www-data/user = nginx/g" \
        -e "s/group = www-data/group = nginx/g" \
        -e "s/^;clear_env = no$/clear_env = no/" \
        /usr/local/etc/php-fpm.d/www.conf