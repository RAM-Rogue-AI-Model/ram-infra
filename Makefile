# --- CONFIGURATION ---
GITHUB_ORG = RAM-Rogue-AI-Model
REPOS = ram-front ram-ms-logger ram-api-gateway ram-ms-user ram-ms-battle ram-ms-effect ram-ms-game ram-ms-player ram-ms-enemy ram-ms-item ram-infra
PARENT_DIR = ..

# Couleurs pour le feedback visuel
GREEN  := $(shell tput -Txterm setaf 2)
RED    := $(shell tput -Txterm setaf 1)
YELLOW := $(shell tput -Txterm setaf 3)
RESET  := $(shell tput -Txterm sgr0)

.PHONY: help init clone update install build start stop dev logs

help:
	@echo "${YELLOW}--- COMMANDES DEVOPS ---${RESET}"
	@echo "${GREEN}make init${RESET}    : 🚀 SETUP COMPLET (Clone + Install + Update)"
	@echo "${GREEN}make clone${RESET}   : Récupère les repos manquants"
	@echo "${GREEN}make update${RESET}  : Git Pull + Docker Up"
	@echo "${GREEN}make install${RESET} : pnpm install partout"
	@echo "${GREEN}make build${RESET}   : Compile tout (TypeScript -> dist/)"
	@echo "${GREEN}make start${RESET}   : Lance tout via PM2 (Prod)"
	@echo "${GREEN}make dev${RESET}     : Mode Watch (Concurrently)"
	@echo "${GREEN}make stop${RESET}    : Coupe tout"

init: clone setup-env install update
	@echo "${GREEN}✨ Setup complet terminé ! Tu peux lancer 'make start' ou 'make dev'.${RESET}"

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

build:
	@echo "${YELLOW}🔨 Compilation...${RESET}"
	@for repo in $(REPOS); do \
		target_dir="$(PARENT_DIR)/$$repo"; \
		if [ -d "$$target_dir" ]; then \
			echo "   ⚙️ Building $$repo..."; \
			(cd "$$target_dir" && pnpm build) || echo "   ${RED}❌ Erreur build $$repo${RESET}"; \
		fi; \
	done

up:
	@echo "${YELLOW}🚀 Lancement PM2...${RESET}"
	@if ! command -v pm2 &> /dev/null; then echo "${RED}❌ PM2 manquant (pnpm add -g pm2)${RESET}"; exit 1; fi
	@for repo in $(REPOS); do \
		target_dir="$(PARENT_DIR)/$$repo"; \
		if [ -d "$$target_dir" ]; then \
			echo "   ▶️ Starting $$repo..."; \
			(cd "$$target_dir" && pm2 start npm --name "$$repo" -- run start); \
		fi; \
	done
	@echo "${GREEN}✅ Services lancés.${RESET}"

down:
	@pm2 delete all || true
	@echo "${GREEN}🛑 Tout est arrêté.${RESET}"

dev:
	@echo "${YELLOW}🔥 Lancement DEV...${RESET}"
	@commands=""; \
	for repo in $(REPOS); do \
		if [ -d "$(PARENT_DIR)/$$repo" ]; then \
			commands="$$commands \"cd $(PARENT_DIR)/$$repo && pnpm dev\""; \
		fi; \
	done; \
	npx concurrently -n "ALL" -c "auto" $$commands

logs:
	@pm2 logs