# --- CONFIGURATION ---
GITHUB_ORG = RAM-Rogue-AI-Model
REPOS = ram-infra ram-ms-logger ram-ms-user ram-ms-battle ram-ms-effect ram-ms-game ram-ms-player ram-ms-enemy ram-ms-item ram-api-gateway ram-front
PARENT_DIR = ..

# Couleurs pour le feedback visuel
GREEN  := $(shell tput -Txterm setaf 2)
RED    := $(shell tput -Txterm setaf 1)
YELLOW := $(shell tput -Txterm setaf 3)
RESET  := $(shell tput -Txterm sgr0)

.PHONY: help init clone update install build start stop dev logs

help:
	@echo "${GREEN}make init${RESET}    : 🚀 SETUP COMPLET (Clone + Install + Update + Build + Up)"
	@echo "${GREEN}make clone${RESET}   : Récupère les repos manquants"
	@echo "${GREEN}make update${RESET}  : Git Pull"
	@echo "${GREEN}make install${RESET} : pnpm install partout"
	@echo "${GREEN}make build${RESET}   : Compile tout (TypeScript -> dist/)"
	@echo "${GREEN}make up${RESET}      : 🐳 Lance tous les services Docker"
	@echo "${GREEN}make down${RESET}    : 🛑 Arrête tous les services Docker"
	@echo "${GREEN}make logs${RESET}    : 📋 Affiche les logs Docker"

init: clone setup-env setup-network install update build up
	@echo "${GREEN}✨ Setup complet terminé !${RESET}"

clone:
	@echo "${YELLOW}🔍 Vérification des repositories...${RESET}"
	@for repo in $(REPOS); do \
		target_dir="$(PARENT_DIR)/$$repo"; \
		if [ ! -d "$$target_dir" ]; then \
			echo "   📥 Cloning $$repo..."; \
			git clone "git@github.com:$(GITHUB_ORG)/$$repo.git" "$$target_dir" || echo "   ${RED}❌ Echec clone $$repo${RESET}"; \
		else \
			echo "   ✅ $$repo existe déjà."; \
		fi; \
	done
	@echo "${GREEN}📂 Architecture validée.${RESET}"

setup-env:
	@echo "${YELLOW}🔐 Génération des clés de sécurité partagées...${RESET}"
	$(eval JWT_KEY := $(shell openssl rand -hex 32))
	$(eval INTERNAL_KEY := $(shell openssl rand -hex 32))
	@echo "   🔑 JWT_SECRET généré"
	@echo "   🔑 INTERNAL_SECRET généré"
	
	@echo "${YELLOW}🔧 Configuration des fichiers .env...${RESET}"
	@for repo in $(REPOS); do \
		target_dir="$(PARENT_DIR)/$$repo"; \
		if [ -d "$$target_dir" ]; then \
			if [ ! -f "$$target_dir/.env" ] && [ -f "$$target_dir/.env.example" ]; then \
				echo "   📄 Création .env pour $$repo (avec injection des secrets)"; \
				sed -e "s/__GENERATE_JWT__/$(JWT_KEY)/g" \
				    -e "s/__GENERATE_INTERNAL__/$(INTERNAL_KEY)/g" \
				    "$$target_dir/.env.example" > "$$target_dir/.env"; \
			elif [ -f "$$target_dir/.env" ]; then \
				echo "   ✅ $$repo a déjà un .env (pas de modification)"; \
			fi; \
		fi; \
	done
	@echo "${GREEN}✅ Configuration des fichiers .env terminée.${RESET}"

setup-network:
	@docker network create ram-shared-network 2>/dev/null || true
	@echo "${GREEN}🌐 Réseau Docker partagé 'ram-shared-network' actif.${RESET}"

update:
	@echo "${YELLOW}🚀 Mise à jour globale...${RESET}"
	@for repo in $(REPOS); do \
		target_dir="$(PARENT_DIR)/$$repo"; \
		if [ -d "$$target_dir" ]; then \
			echo ""; \
			echo "${YELLOW}👉 $$repo${RESET}"; \
			echo "   📦 Git Pull..."; \
			git -C "$$target_dir" pull origin main --rebase || echo "   ${RED}❌ Erreur Git${RESET}"; \
		fi; \
	done
	@echo "${GREEN}🎉 Tout est à jour !${RESET}"

install:
	@echo "${YELLOW}📦 Installation des dépendances (pnpm)...${RESET}"
	@for repo in $(REPOS); do \
		target_dir="$(PARENT_DIR)/$$repo"; \
		if [ -d "$$target_dir" ]; then \
			echo "   👉 $$repo..."; \
			(cd "$$target_dir" && pnpm install --reporter=silent && pnpm run postinstall) || echo "   ${RED}❌ Erreur pnpm${RESET}"; \
		fi; \
	done

build:
	@echo "${YELLOW}🐳 Build des services Docker...${RESET}"
	@for repo in $(REPOS); do \
		target_dir="$(PARENT_DIR)/$$repo"; \
		if [ -d "$$target_dir" ] && [ -f "$$target_dir/docker-compose.yml" ]; then \
			echo "   ▶️ Starting $$repo..."; \
			docker compose -f "$$target_dir/docker-compose.yml" build || echo "   ${RED}❌ Erreur Docker $$repo${RESET}"; \
		fi; \
	done
	@echo "${GREEN}✅ Services Docker buildés.${RESET}"

up:
	@echo "${YELLOW}🐳 Lancement des services Docker...${RESET}"
	@for repo in $(REPOS); do \
		target_dir="$(PARENT_DIR)/$$repo"; \
		if [ -d "$$target_dir" ]; then \
			if [ -f "$$target_dir/docker-compose.yml" ]; then \
				echo "   ▶️ Starting $$repo..."; \
				docker compose -f "$$target_dir/docker-compose.yml" up -d --remove-orphans || echo "   ${RED}❌ Erreur Docker $$repo${RESET}"; \
			else \
				echo "   ▶️ Starting $$repo (pnpm dev)..."; \
				(cd "$$target_dir" && pnpm dev) || echo "   ${RED}❌ Erreur pnpm dev $$repo${RESET}"; \
			fi; \
		fi; \
	done
	@echo "${GREEN}✅ Services Docker lancés. Vous pouvez vous rendre sur 'http://localhost:3000/ram'.${RESET}"

down:
	@echo "${YELLOW}🛑 Arrêt des services Docker...${RESET}"
	@for repo in $(REPOS); do \
		target_dir="$(PARENT_DIR)/$$repo"; \
		if [ -d "$$target_dir" ] && [ -f "$$target_dir/docker-compose.yml" ]; then \
			echo "   ⏹️ Stopping $$repo..."; \
			docker compose -f "$$target_dir/docker-compose.yml" down || echo "   ${RED}❌ Erreur Docker $$repo${RESET}"; \
		fi; \
	done
	@echo "${GREEN}✅ Services Docker arrêtés.${RESET}"

logs:
	@echo "${YELLOW}📋 Logs Docker (Ctrl+C pour quitter)...${RESET}"
	@repo=$(filter-out $@,$(MAKECMDGOALS)); \
	if [ -z "$$repo" ]; then \
		echo "${RED}Usage: make logs <service-name>${RESET}"; \
		echo "Exemple: make logs ram-ms-user"; \
	else \
		target_dir="$(PARENT_DIR)/$$repo"; \
		if [ -f "$$target_dir/docker-compose.yml" ]; then \
			docker compose -f "$$target_dir/docker-compose.yml" logs -f; \
		else \
			echo "${RED}❌ docker-compose.yml non trouvé pour $$repo${RESET}"; \
		fi; \
	fi
