# Execution Environment Spec (Draft)

This document defines the desired behavior of the Luanti + bot runtime environment.
It is intentionally implementation-agnostic and should be agreed on before changes.

## Goals

- Single source of truth for runtime configuration.
- Reproducible startup with minimal steps.
- Predictable networking between Luanti and the bot server.
- No implicit config regeneration or silent overrides.
- Easy to reset or rebuild without guessing which file is active.

## Non-goals

- No attempt to hide Docker; debugging should remain straightforward.
- No auto-migration of worlds or player data unless explicitly requested.
- Multiple worlds are out of scope for this runtime.

## Desired Properties

- Configuration changes are applied by restarting services, not by deleting files.
- The runtime always uses the same known config path(s).
- The bot server is reachable from Luanti with a stable URL.
- Startup should be one command (e.g., `make up`), with optional targets for reset.

## Configuration Sources (Single Source of Truth)

- `config/minetest.conf` is the authoritative server config.
- `config/world.mt` is authoritative for world metadata only.
- Templates should not exist or be used in normal operation.
- No script should rewrite or "sync" configs at startup.

## Config Path Rules

- Luanti must read `minetest.conf` from a single explicit path.
- The config should be bind-mounted directly to that path (no search logic).
- Logs should include the resolved config path on startup.

## World Lifecycle

- On first run, if the world does not exist, copy `config/world.mt` into the
  new world directory.
- On subsequent runs, do not overwrite `data/.../world.mt`.
- Re-applying `config/world.mt` should be a deliberate action
  (e.g., `make reset-config`).

## Runtime Services

- Luanti server and bot server are independent deployable services.
- Local development may use a compose stack for convenience, but it must not
  assume co-location in production.
- Running the bot server on the host is supported and explicit.

## Deployment Modes

### Local Development

- Compose may start both services for convenience.
- Each service is built from its own image (luanti, bot).
- Inter-service URL defaults can target the compose network.

### Production / Separate Hosts

- Each service runs on its own host/application server.
- All cross-service URLs are explicit configuration (no implicit defaults).

## Local Validation Modes

1) Compose (default)
   - Start both services via `docker compose`.
   - Uses separate images, but shared network for convenience.
   - Intended to mirror production topology while staying single-command.

2) Split (explicit)
   - Luanti runs via Docker.
   - Bot runs on host or a separate machine.
   - `agent_api.bot_server_url` is set explicitly in config.

## Networking

- Default (local compose) bot URL for Luanti: `http://bot:8000`.
- If running bot server on host, use `http://host.docker.internal:8000`
  and document the required override.
- In production, bot URL must be an explicit config value.
- Ports exposed for local development:
  - Luanti: `30000/udp`
  - Bot: `8000/tcp`

## Data and Persistence

- `data/` is the only persistent location for worlds, auth, and game downloads.
- `config/` is not used for persistence, only for static configuration.

## Reproducibility

- Fixed seed should be set in `config/minetest.conf`.
- Game ID and world name are defined in `config/`, not in compose.
- Startup does not mutate configs.

## Developer Workflow (Minimal Commands)

- `make up`: start Luanti + bot with current config.
- `make up-no-bot`: explicit opt-out for bot (dev-only).
- `make restart`: restart services and apply config changes.
- `make reset-config`: reset only config-derived files (no world deletion).
- `make reset-world`: delete the world and restart.

`reset-config` deletes only:
- `data/.minetest/minetest.conf` (if present from older runs)
- `data/.minetest/worlds/<world>/world.mt`

## Observability

- `make logs` shows Luanti logs.
- `make logs-bot` shows bot logs.
- Logs should clearly show which config path was used.

## Open Questions / Decisions Needed

## Decisions (Proposed; pending sign-off)

- Bind-mount `config/minetest.conf` directly to the path Luanti reads, and log it.
- Treat `config/world.mt` as authoritative, but copy only on first world creation.
- Bot server is mandatory only for local compose; in production it is separate.
- Bot server is always required logically, but deployed separately in production.
- `BOT_SERVER_URL` remains an explicit configuration for all non-compose deploys.
- Multiple worlds are not supported in this runtime.
- Luanti and bot are built as separate images and deploy independently.

## Open Questions / Decisions Needed

None (all major decisions are proposed above).
