# Cibles de développement, de test, d'infrastructure et d'apprentissage.
# `make help` liste les cibles. Les commandes de référence sont dans CLAUDE.md §8.

.DEFAULT_GOAL := help
SHELL := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c

ENV ?= dev
LAYER ?= foundation
TF_ROOT := infra/envs/$(ENV)/$(LAYER)
TF_ROOTS := $(shell find infra/envs -mindepth 2 -maxdepth 2 -type d 2>/dev/null | sort) \
            infra/global/organization \
            $(shell find infra/global/accounts -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort)
RESULTS_DATE := $(shell date +%Y-%m-%d)

# Le noyau Jupyter du venv doit primer sur un kernelspec utilisateur homonyme (~/Library/Jupyter/kernels/python3).
export JUPYTER_PREFER_ENV_PATH := 1

.PHONY: help install dev-up dev-down lint format test notebooks-ci notebooks-full \
        validation-report tf-check tf-plan tf-apply

help: ## Affiche cette aide
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2}'

install: ## Installe les dépendances (uv sync --locked) et les hooks pre-commit
	uv sync --locked
	uv run pre-commit install --install-hooks

dev-up: ## Démarre PostgreSQL + pgvector en local (docker compose)
	docker compose up -d --wait

dev-down: ## Arrête les conteneurs locaux (le volume de données est conservé)
	docker compose down

lint: ## ruff (lint + format) puis mypy
	uv run ruff check .
	uv run ruff format --check .
	uv run mypy

format: ## Formate et corrige ce qui peut l'être (ruff)
	uv run ruff format .
	uv run ruff check --fix .

test: ## Tests unitaires, propriétés et stockage local, avec couverture
	uv run pytest --cov --cov-report=term --cov-report=xml

notebooks-ci: ## Notebooks en mode sample (cassettes, sans réseau), comme la CI
	CGP_NB_MODE=sample uv run pytest --nbmake --nbmake-timeout=600 -p no:cacheprovider notebooks/

notebooks-full: ## Notebooks contre le compte dev ; chiffres archivés dans notebooks/results/<date>/
	CGP_NB_MODE=full CGP_NB_RESULTS_DIR=notebooks/results/$(RESULTS_DATE) \
		uv run pytest --nbmake --nbmake-timeout=3600 -p no:cacheprovider notebooks/

validation-report: ## Génère reports/validation.md (contenu métier en attente de validation)
	uv run cgp validation-report

tf-check: ## fmt -check, validate, tflint et trivy sur tout infra/
	terraform fmt -check -recursive -diff infra
	@for root in $(TF_ROOTS); do \
		echo "== validate $$root"; \
		terraform -chdir=$$root init -backend=false -input=false >/dev/null; \
		terraform -chdir=$$root validate; \
	done
	tflint --init --config "$(CURDIR)/.tflint.hcl" >/dev/null
	cd infra && tflint --recursive --config "$(CURDIR)/.tflint.hcl"
	trivy config --exit-code 1 --severity HIGH,CRITICAL infra

tf-plan: ## Plan d'une couche : make tf-plan ENV=dev LAYER=platform
	terraform -chdir=$(TF_ROOT) init -input=false -backend-config=backend.hcl
	terraform -chdir=$(TF_ROOT) plan -input=false -lock-timeout=60s

tf-apply: ## Apply local, autorisé pour dev uniquement ; staging et prod passent par la CI
ifneq ($(ENV),dev)
	$(error apply local interdit vers "$(ENV)" : staging et prod ne sont déployés que par la CI)
endif
	terraform -chdir=$(TF_ROOT) init -input=false -backend-config=backend.hcl
	terraform -chdir=$(TF_ROOT) apply -input=false -lock-timeout=60s
