.PHONY: up down restart logs pull update ps shell ui

up:            ## Start Homebridge in the background
	docker compose up -d

down:           ## Stop and remove the Homebridge container
	docker compose down

restart:        ## Restart the Homebridge container
	docker compose restart

logs:           ## Follow Homebridge logs
	docker compose logs -f homebridge

pull:           ## Pull the latest homebridge/homebridge image
	docker compose pull

update: pull    ## Pull the latest image and recreate the container
	docker compose up -d

ps:             ## Show container status
	docker compose ps

shell:          ## Open a shell inside the running container
	docker compose exec homebridge sh

ui:             ## Print the Config UI URL
	@echo "Homebridge Config UI: http://$$(hostname -I | awk '{print $$1}'):8581"
