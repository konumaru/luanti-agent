.PHONY: help prepare up up-no-bot up-build down restart logs logs-bot ps reset-config reset-world

help:
	@printf "%s\n" \
	"Targets:" \
	"  make up           - Start luanti + bot with current config" \
	"  make up-no-bot    - Start luanti only (bot disabled)" \
	"  make up-build     - Start luanti + bot with --build" \
	"  make restart      - Restart services to apply config changes" \
	"  make logs         - Tail luanti logs" \
	"  make logs-bot     - Tail bot server logs" \
	"  make reset-config - Reset config-derived files (world.mt + legacy minetest.conf)" \
	"  make reset-world  - Remove world data and restart"

prepare:
	@mkdir -p data/.minetest

up: prepare
	docker compose up -d

up-no-bot: prepare
	docker compose up -d luanti

up-build: prepare
	docker compose up -d --build

down:
	docker compose down

restart:
	docker compose restart luanti

logs:
	docker compose logs -f luanti

logs-bot:
	docker compose logs -f bot

ps:
	docker compose ps

reset-config:
	rm -f data/.minetest/minetest.conf data/.minetest/worlds/world/world.mt
	docker compose restart luanti

reset-world:
	rm -rf data/.minetest/worlds/world
	docker compose restart luanti
