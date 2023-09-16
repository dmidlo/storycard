###################################
# Variables
###################################
VENV_NAME ?= .venv

# Safety check for undefined variables
ifeq ($(strip $(VENV_NAME)),)
    $(error VENV_NAME is not defined)
endif

# Determine OS using a more reliable method for Windows
ifeq ($(OS),Windows_NT)
    OS := WINDOWS
else
    UNAME_S := $(shell uname -s)
    ifeq ($(UNAME_S),Linux)
        OS := LINUX
    endif
    ifeq ($(UNAME_S),Darwin)
        OS := MACOS
    endif
endif

# File separator & Python executable path based on OS
ifeq ($(OS),WINDOWS)
    SEP := \\
    PYTHON := $(VENV_NAME)$(SEP)Scripts$(SEP)python.exe
else
    SEP := /
    PYTHON := $(VENV_NAME)$(SEP)bin$(SEP)python
endif

PROJECT_DIR := src$(SEP)storycard

###################################
# Main Targets
###################################
.PHONY: help
help:  ## This help message.
	@echo "  make [target]:\n"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

###################################
# Python Virtual Environment
###################################
.PHONY: venv-init
venv-init: venv-install venv-activate venv-upgrade-pip  ## Initialize Python Virtual Environment

.PHONY: venv-upgrade-pip
venv-upgrade-pip: venv-activate
	@echo "Upgrading pip."
	@$(PYTHON) -m pip install --upgrade pip

## Install Python virtual environment
.PHONY: venv-install
venv-install:
	@test -d $(VENV_NAME) || (echo "Virtual environment is not installed. Installing..." && python3.11 -m venv $(VENV_NAME))

## Activate Python Virtual Environment (dependency for other recipes.)
.PHONY: venv-activate
venv-activate: venv-install  
	@which $(PYTHON) >/dev/null || (echo "Python from virtual environment is not in PATH. Activating..." && source $(VENV_NAME)$(SEP)bin$(SEP)activate)
	@if [ -z "$$VIRTUAL_ENV" ]; then echo "Activating virtual environment..."; source $(VENV_NAME)$(SEP)bin$(SEP)activate; else echo "Virtual environment is already active: $$VIRTUAL_ENV"; fi

.PHONY: venv-clean
venv-clean: ## Remove Python virtual environment
	# Safety check before cleaning
	@if [ -n "$$VIRTUAL_ENV" ]; then echo "Virtual environment is active. Please deactivate it first."; exit 1; fi
	@echo "Removing virtual environment..."
	@rm -rf $(VENV_NAME)

.PHONY: venv-rebuild
venv-rebuild: venv-clean venv-init  ## Rebuild Python virtual environment


###################################
# Application Environmnet
###################################
.PHONY: build
build: venv-activate  ## Build the package
	@poetry build

.PHONY: publish
publish: venv-activate  ## Publish the package to PyPI
	@poetry publish --build

.PHONY: install
install: venv-activate  ## Install dependencies
	@pip freeze | grep poetry || pip install poetry
	@poetry install

.PHONY: clean
clean:  ## Clean build artifacts
	@find . -type f -name '*.pyc' -delete
	@find . -type f -name '*.pyo' -delete
	@find . -type d -name '__pycache__' -delete
	@rm -rf htmlcov$(SEP)
	@rm -rf build$(SEP)
	@rm -rf dist$(SEP)


###################################
# Dependency Management
###################################
.PHONY: deps-update
deps-update: venv-activate  ## Update project dependencies
	@poetry update

.PHONY: deps-freeze
deps-freeze: venv-activate  ## Freeze project dependencies
	@poetry export --format requirements.txt > requirements.txt

.PHONY: deps-all
deps-all: venv-activate deps-update deps-freeze ## Update and Freeze project dependencies
	
###################################
# Code Quality
###################################

# Linting

.PHONY: flake8
flake8: venv-activate  ## Lint the code with flake8
	@flake8 $(PROJECT_DIR)

.PHONY: type-check
type-check: venv-activate  ## Type-check the code
	@mypy $(PROJECT_DIR)

.PHONY: docstring-check
docstring-check: venv-activate  ## Validate docstrings
	@pydocstyle $(PROJECT_DIR)

.PHONY: pylint
pylint: venv-activate  ## Run Pylint for code linting
	@pylint $(PROJECT_DIR)

## Linting Aggregates.

.PHONY: lint-python
lint-python: venv-activate flake8 type-check docstring-check pylint ## Lint Python Code.

.PHONY: lint
lint: venv-activate lint-python  ## Lint the project's code.

# Formatting

.PHONY: format-python
format: venv-activate  ## Auto-format the code using black
	@black $(PROJECT_DIR)

.PHONY: sort-python
isort: venv-activate  ## Sort the imports
	@isort $(PROJECT_DIR)

## Formatting Aggregates

.PHONY: sort
sort: venv-activate sort-python  ## Sort the project's dependencies.

.PHONY: format
format: venv-activate format-python ## Format Project Files.

# Security

.PHONY: owasp-check
owasp-check: venv-activate  ## Run OWASP Dependency-Check
	@dependency-check --project Storycard --scan $(PROJECT_DIR) --out . --format "ALL"

.PHONY: snyk-test
snyk-test: venv-activate ## Run Snyk tests
	@snyk test

.PHONY: bandit-check
bandit-check: venv-activate  ## Run Bandit Security Check
	@bandit -r ${PROJECT_DIR}

## Security Aggregates

.PHONY: security-python
security-python: venv-activate owasp-check snyk-check bandit-check ## Audit Python Code Security

.PHONY: security
security: venv-activate security-python  ## Audit Project's Security.

# Testing

.PHONY: unit-test
unit-test: venv-activate  ## Run unit tests
	@pytest tests$(SEP)unit_tests

.PHONY: integration-test
integration-test: venv-activate  ## Run integration tests
	@pytest tests$(SEP)integration_tests

.PHONY: hypothesis
hypothesis: venv-activate  ## Run Hypothesis for property-based testing
	@hypothesis write $(PROJECT_DIR)

# Testing Aggregates

.PHONY: test
test: venv-activate unit-test integration-test hypothesis ## Run Unit and Integration Tests.

# Quality Aggregates

.PHONY: quality-python
quality-python: venv-activate lint-python security-python test-python  ## Check Python Code Quality

.PHONY: quality-python-force
quality-python-force: venv-activate format-python sort-python quality-python  ## Format Python Code and Check Quality

.PHONY: quality ## Check Code Quality
quality: venv-activate quality-python

.PHONY: quality-force
quality-force: venv-activate quality-python-force  ## Format Code and Check Quality

###################################
# Project Info
###################################

.PHONY: coverage
coverage: venv-activate  ## Generate code coverage report
	pytest tests$(SEP) --cov=$(PROJECT_DIR)

.PHONY: coverage-html
coverage-html: venv-activate  ## Generate HTML code coverage report
	pytest tests$(SEP) --cov=$(PROJECT_DIR) --cov-report html

###################################
# Misc.
###################################

.PHONY: set-git-hooks
set-git-hooks:  ## Set up Git hooks
	@cp git-hooks$(SEP)* .git$(SEP)hooks$(SEP)
	@chmod +x .git$(SEP)hooks$(SEP)*

.PHONY: set-env-vars
set-env-vars:  ## Set environment variables
	@echo "Setting environment variables..."

.PHONY: pre-commit
pre-commit: venv-activate  ## Run pre-commit hooks
	@pre-commit run --all-files

#####################
.DEFAULT_GOAL := help
