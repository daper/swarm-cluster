FROM redis:4-alpine

# Set default configuration values (in ms)
ENV SENTINEL_QUORUM 2
ENV SENTINEL_DOWN_AFTER 30000
ENV SENTINEL_FAILOVER 180000

# Add configuration file and entrypoint script
COPY sentinel.conf /etc/redis/sentinel.conf
RUN chown redis:redis /etc/redis/sentinel.conf

COPY sentinel-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/sentinel-entrypoint.sh

EXPOSE 26379

ENTRYPOINT ["sentinel-entrypoint.sh"]
