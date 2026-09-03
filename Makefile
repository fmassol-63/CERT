.PHONY: up down restart logs reload config

up:
	docker compose up -d

down:
	docker compose down

restart:
	docker compose restart caddy

logs:
	docker compose logs -f caddy

# Recharge la configuration Caddy sans coupure de service
reload:
	docker compose exec caddy caddy reload --config /etc/caddy/Caddyfile

# Verifie la syntaxe du Caddyfile avant de deployer
config:
	docker compose exec caddy caddy validate --config /etc/caddy/Caddyfile
