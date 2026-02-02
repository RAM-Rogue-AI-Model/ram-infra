# --- CONFIGURATION ---
GITHUB_ORG = RAM-Rogue-AI-Model
REPOS = ram-ms-user ram-ms-battle ram-ms-effect ram-ms-game ram-ms-player ram-ms-enemy ram-ms-item ram-infra ram-api-gateway ram-front ram-ms-logger
PARENT_DIR = ..

# Couleurs pour le feedback visuel
GREEN  := $(shell tput -Txterm setaf 2)
RED    := $(shell tput -Txterm setaf 1)
YELLOW := $(shell tput -Txterm setaf 3)
RESET  := $(shell tput -Txterm sgr0)

.PHONY: help init clone update install build start stop dev logs

help:
	@echo "${GREEN}make init${RESET}    : 🚀 SETUP COMPLET (Clone + Install + Update)"
	@echo "${GREEN}make clone${RESET}   : Récupère les repos manquants"
	@echo "${GREEN}make update${RESET}  : Git Pull + Docker Up"
	@echo "${GREEN}make install${RESET} : pnpm install partout"
	@echo "${GREEN}make build${RESET}   : Compile tout (TypeScript -> dist/)"
	@echo "${GREEN}make up${RESET}      : 🐳 Lance tous les services Docker"
	@echo "${GREEN}make down${RESET}    : 🛑 Arrête tous les services Docker"
	@echo "${GREEN}make logs${RESET}    : 📋 Affiche les logs Docker"
	@echo "${GREEN}make rebuild${RESET} : 🔨 Rebuild les images Docker"

init: clone setup-env setup-network install update
	@echo "${GREEN}✨ Setup complet terminé ! Vous pouvez lancer 'make up'.${RESET}"

clone:
	@echo "${YELLOW}🔍 Vérification des repositories...${RESET}"
	@for repo in $(REPOS); do \
		target_dir="$(PARENT_DIR)/$$repo"; \
		if [ ! -d "$$target_dir" ]; then \
			echo "   📥 Cloning $$repo..."; \
			git clone "https://github.com/$(GITHUB_ORG)/$$repo.git" "$$target_dir" || echo "   ${RED}❌ Echec clone $$repo${RESET}"; \
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
			if [ -f "$$target_dir/docker-compose.yml" ]; then \
				echo "   🐳 Docker Up..."; \
				docker compose -f "$$target_dir/docker-compose.yml" up -d || echo "   ${RED}⚠️ Erreur Docker${RESET}"; \
			fi; \
		fi; \
	done
	@echo "${GREEN}🎉 Tout est à jour !${RESET}"

install:
	@echo "${YELLOW}📦 Installation des dépendances (pnpm)...${RESET}"
	@for repo in $(REPOS); do \
		target_dir="$(PARENT_DIR)/$$repo"; \
		if [ -d "$$target_dir" ]; then \
			echo "   👉 $$repo..."; \
			(cd "$$target_dir" && pnpm install --reporter=silent) || echo "   ${RED}❌ Erreur pnpm${RESET}"; \
		fi; \
	done

up:
	@echo "${YELLOW}🐳 Lancement des services Docker...${RESET}"
	@for repo in $(REPOS); do \
		target_dir="$(PARENT_DIR)/$$repo"; \
		if [ -d "$$target_dir" ] && [ -f "$$target_dir/docker-compose.yml" ]; then \
			echo "   ▶️ Starting $$repo..."; \
			docker compose -f "$$target_dir/docker-compose.yml" up -d --build --remove-orphans || echo "   ${RED}❌ Erreur Docker $$repo${RESET}"; \
		fi; \
	done
	@echo "${GREEN}✅ Services Docker lancés.${RESET}"

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

build:
	@echo "${YELLOW}🔨 Compilation...${RESET}"
	@for repo in $(REPOS); do \
		target_dir="$(PARENT_DIR)/$$repo"; \
		if [ -d "$$target_dir" ]; then \
			echo "   ⚙️ Building $$repo..."; \
			(cd "$$target_dir" && pnpm build) || echo "   ${RED}❌ Erreur build $$repo${RESET}"; \
		fi; \
	done

logs:
	@echo "${YELLOW}📋 Logs Docker (Ctrl+C pour quitter)...${RESET}"
	@repo=$(filter-out $@,$(MAKECMDGOALS)); \
	if [ -z "$$repo" ]; then \
		echo "${RED}Usage: make docker:logs <service-name>${RESET}"; \
		echo "Exemple: make docker:logs ram-ms-user"; \
	else \
		target_dir="$(PARENT_DIR)/$$repo"; \
		if [ -f "$$target_dir/docker-compose.yml" ]; then \
			docker compose -f "$$target_dir/docker-compose.yml" logs -f; \
		else \
			echo "${RED}❌ docker-compose.yml non trouvé pour $$repo${RESET}"; \
		fi; \
	fi

docker-rebuild:
	@echo "${YELLOW}🔨 Rebuild des images Docker...${RESET}"
	@for repo in $(REPOS); do \
		target_dir="$(PARENT_DIR)/$$repo"; \
		if [ -d "$$target_dir" ] && [ -f "$$target_dir/docker-compose.yml" ]; then \
			echo "   🔧 Rebuilding $$repo..."; \
			docker compose -f "$$target_dir/docker-compose.yml" build --no-cache || echo "   ${RED}❌ Erreur build $$repo${RESET}"; \
		fi; \
	done
	@echo "${GREEN}✅ Images Docker rebuilt.${RESET}"
