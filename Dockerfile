FROM debian:bookworm-slim

RUN apt-get update \
  && apt-get install -y --no-install-recommends minetest-server ca-certificates \
  && rm -rf /var/lib/apt/lists/*

COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

VOLUME ["/data"]
EXPOSE 30000/udp

ENTRYPOINT ["docker-entrypoint.sh"]
