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

# Install VoxeLibre into the user data directory at build time
RUN mkdir -p /root/.minetest/games \
  && git clone --depth 1 https://git.minetest.land/VoxeLibre/VoxeLibre.git /root/.minetest/games/voxelibre

# Copy initialization scripts and templates
COPY scripts/init-world.sh /scripts/init-world.sh
COPY config/minetest.conf.template /config/minetest.conf.template
COPY config/world.mt.template /config/world.mt.template

RUN chmod +x /scripts/init-world.sh

COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

EXPOSE 30000/udp

ENTRYPOINT ["docker-entrypoint.sh"]
