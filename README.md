# luanti-agent

Reproducible Luanti server for agent experiments.

## Quick start

```bash
git clone https://github.com/konumaru/luanti-agent.git
cd luanti-agent
docker compose up
docker compose logs -f
```

Server: `localhost:30000/udp`

## Data and init

- Data dir: `./data` (minetest data lives under `./data/.minetest`)
- Templates: `config/minetest.conf.template`, `config/world.mt.template`
- Init: `scripts/init-world.sh` runs at container start via `/custom-cont-init.d`

## Common tasks

### Change seed

- Option A: set `FIXED_SEED` in `docker-compose.yml`
- Option B: edit `config/minetest.conf.template`, remove `./data/.minetest/minetest.conf` and `./data/.minetest/worlds/<world>/world.mt`, then restart

### Add mods

- Place mods in `./data/.minetest/mods`
- Enable in `config/world.mt.template` (new worlds) or `./data/.minetest/worlds/<world>/world.mt` (existing)
- Restart: `docker compose up -d`

### Change game

- Set `GAME_ID` (optional: `GAME_REPO_URL`, `GAME_REPO_BRANCH`)
- Remove `./data/.minetest/games/<gameid>` to re-download
- Restart: `docker compose up -d`

### Reset world

```bash
docker compose down
rm -rf ./data/.minetest/worlds/world
docker compose up -d
```

## Permissions

If you see permission errors writing to `/config/.minetest`:

```bash
sudo chown -R 1000:1000 ./data
```

Match `PUID/PGID` in `docker-compose.yml`.

## License

See LICENSE.
