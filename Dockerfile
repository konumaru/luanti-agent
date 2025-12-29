FROM debian:bookworm-slim

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
  minetest-server \
  ca-certificates \
  bash \
  git \
  wget \
  unzip \
  && rm -rf /var/lib/apt/lists/*

# Copy initialization scripts and templates
COPY scripts/init-world.sh /scripts/init-world.sh
COPY scripts/download-mods.sh /scripts/download-mods.sh
COPY scripts/download-games.sh /scripts/download-games.sh
COPY config/minetest.conf.template /config/minetest.conf.template
COPY config/world.mt.template /config/world.mt.template

RUN chmod +x /scripts/init-world.sh /scripts/download-mods.sh /scripts/download-games.sh

COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

VOLUME ["/data"]
EXPOSE 30000/udp

ENTRYPOINT ["docker-entrypoint.sh"]
