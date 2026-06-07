.PHONY: dev build migrate stop clean

dev:
	docker compose -f infra/docker-compose.yml up -d --build
	@echo "Docker containers started. To view logs run: docker compose -f infra/docker-compose.yml logs -f"

build:
	docker compose -f infra/docker-compose.yml build

migrate:
	docker compose -f infra/docker-compose.yml exec server npx prisma migrate dev

stop:
	docker compose -f infra/docker-compose.yml down

clean:
	docker compose -f infra/docker-compose.yml down -v
