.PHONY: dev stop test update update-tf update-screenpipe cert

dev:
	@bash start.sh

stop:
	@bash stop.sh

test:
	@curl -s -X POST http://localhost:3031/instruction \
		-H "Content-Type: application/json" \
		-d '{"x":800,"y":300,"instruction":"clique sur File > Export","step":1}' \
		&& echo " → instruction envoyée" || echo "Serveur non disponible"

# Reconstruit + recopie + re-signe les apps avec le cert stable.
# TCC (Accessibility, Screen Recording) reste accordé entre les builds.
update:
	@bash update-apps.sh all

update-tf:
	@bash update-apps.sh tf

update-screenpipe:
	@bash update-apps.sh screenpipe

# Crée/vérifie le cert self-signed dans le Keychain (one-shot).
cert:
	@bash update-apps.sh cert
