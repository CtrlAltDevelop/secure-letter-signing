# BRAND picks the company: make up BRAND=acme   (default: demo)
BRAND ?= demo
PORT ?= 8090
PROJECT := letters-$(BRAND)
# exported so it works in cmd.exe (Windows) as well as sh
export DJANGO_DEBUG := 1
export BRAND

.PHONY: help up down logs dev superuser test app macos windows icons

help:
	@echo "make up         run backend in Docker (Postgres + Redis) for BRAND=$(BRAND); needs brands/$(BRAND)/.env"
	@echo "make down       stop the Docker stack"
	@echo "make logs       follow Docker logs"
	@echo "make dev        run backend from source on port $(PORT): SQLite + in-memory channels/celery, auto-reload, no Docker"
	@echo "make superuser  create a developer (superuser) account for the dev database"
	@echo "make test       run server, JS and Flutter tests"
	@echo "make macos       flutter run the macOS app, hot reload on save (start `make dev` first; port $(PORT))"
	@echo "make windows     flutter run the Windows app, hot reload on save (start `make dev` first; port $(PORT))"
	@echo "make icons       regenerate app icons + native splash from brands/$(BRAND)/logo.svg"
	@echo "make app        flutter run the app with brand BRAND (copies brand assets first)"

up:
	./build.sh $(BRAND) up

down:
	docker compose -p $(PROJECT) down

logs:
	docker compose -p $(PROJECT) logs -f

dev:
	cd server && uv run python manage.py migrate --noinput
	cd server && uv run python manage.py runserver 0.0.0.0:$(PORT)

superuser:
	cd server && uv run python manage.py createsuperuser

test:
	cd server && uv run pytest -q
	$(MAKE) app-assets
	cd app && flutter test
	REQUIRE_DART_SIGNED=1 npm test

app: app-assets
	cd app && flutter pub get && flutter run --dart-define=BRAND=$(BRAND)

macos: app-assets
	cd app && flutter pub get && dart run tool/flutter_watch.dart macos --dart-define=BRAND=$(BRAND)

windows: app-assets
	cd app && flutter pub get && dart run tool/flutter_watch.dart windows --dart-define=BRAND=$(BRAND)

icons: app-assets
	cd app && flutter pub get && flutter test tool/gen_icons_test.dart
	cd app && dart run flutter_launcher_icons
	cd app && dart run flutter_native_splash:create

.PHONY: app-assets
app-assets:
	uv run --no-project python -c "import shutil,os,sys;b=sys.argv[1];os.makedirs('app/assets/brand',exist_ok=True);[shutil.copy('brands/'+b+'/'+f,'app/assets/brand/') for f in ('brand.json','logo.svg')]" $(BRAND)
