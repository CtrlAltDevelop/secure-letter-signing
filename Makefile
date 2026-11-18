# BRAND picks the company: make up BRAND=acme   (default: demo)
BRAND ?= demo
PROJECT := letters-$(BRAND)
SERVER_ENV := DJANGO_DEBUG=1 BRAND=$(BRAND)

.PHONY: help up down logs dev superuser test app

help:
	@echo "make up         run backend in Docker (Postgres + Redis) for BRAND=$(BRAND); needs brands/$(BRAND)/.env"
	@echo "make down       stop the Docker stack"
	@echo "make logs       follow Docker logs"
	@echo "make dev        run backend from source: SQLite + in-memory channels/celery, auto-reload, no Docker"
	@echo "make superuser  create a developer (superuser) account for the dev database"
	@echo "make test       run server, JS and Flutter tests"
	@echo "make app        flutter run the app with brand BRAND (copies brand assets first)"

up:
	./build.sh $(BRAND) up

down:
	docker compose -p $(PROJECT) down

logs:
	docker compose -p $(PROJECT) logs -f

dev:
	cd server && $(SERVER_ENV) uv run python manage.py migrate --noinput
	cd server && $(SERVER_ENV) uv run python manage.py runserver 0.0.0.0:8000

superuser:
	cd server && $(SERVER_ENV) uv run python manage.py createsuperuser

test:
	cd server && $(SERVER_ENV) uv run pytest -q
	$(MAKE) app-assets
	cd app && flutter test
	REQUIRE_DART_SIGNED=1 npm test

app: app-assets
	cd app && flutter pub get && flutter run --dart-define=BRAND=$(BRAND)

.PHONY: app-assets
app-assets:
	mkdir -p app/assets/brand
	cp brands/$(BRAND)/brand.json brands/$(BRAND)/logo.svg app/assets/brand/
