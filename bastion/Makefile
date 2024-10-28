ROOT_DIR := $(dir $(realpath $(lastword $(MAKEFILE_LIST))))
SHELL := /bin/bash

include .env
include secret.env
export

APP_NAME := infra.bastion
DOCKER_IMAGE_TAG := $(APP_NAME):dev
LISTEN_PORT := 2207

.PHONY: help
help: ## This help
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

.PHONY: docker-run
docker-run: ## Run dev docker image
	docker run --rm -it \
		--name yag-$(APP_NAME) \
		-p $(LISTEN_PORT):22/tcp \
		--env-file $(ROOT_DIR).env \
		--env-file $(ROOT_DIR)secret.env \
		$(DOCKER_IMAGE_TAG)

.PHONY: docker-build
docker-build: ## Build docker image
	docker build \
		-t $(DOCKER_IMAGE_TAG) \
		--progress plain \
		.

AWS_ECR_ACCOUNT_ID := 070143334704
AWS_ECR_PROFILE := ecr-rw
AWS_ECR_REGION := us-east-1
AWS_ECR_REPO := im.acme.yag

.PHONY: docker-pub
docker-pub: ## Create a release tag and publish docker image
ifdef TAG
	git fetch \
	&& git checkout main \
	&& git tag -am "Release v$(TAG)" v$(TAG) \
	&& git push origin v$(TAG) \
	&& $(MAKE) docker-build \
	&& docker tag $(DOCKER_IMAGE_TAG) $(AWS_ECR_ACCOUNT_ID).dkr.ecr.$(AWS_ECR_REGION).amazonaws.com/$(AWS_ECR_REPO).$(APP_NAME):$(TAG) \
	&& AWS_PROFILE=$(AWS_ECR_PROFILE) docker push $(AWS_ECR_ACCOUNT_ID).dkr.ecr.$(AWS_ECR_REGION).amazonaws.com/$(AWS_ECR_REPO).$(APP_NAME):$(TAG)
else
	@echo 1>&2 "usage: make docker-pub TAG=1.0.0"
endif
