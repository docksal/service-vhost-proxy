-include env_make

VERSION ?= dev

REPO = docksal/vhost-proxy
NAME = docksal-vhost-proxy

DOCKSAL_VHOST_PROXY_ACCESS_LOG = 1
DOCKSAL_VHOST_PROXY_DEBUG_LOG = 1
DOCKSAL_VHOST_PROXY_STATS_LOG = 1

# Setting these while testing locally may result in data loss, so only use in CI.
# Only use seconds here, so that these can be used with "sleep" as well.
PROJECT_INACTIVITY_TIMEOUT ?= 0
PROJECT_DANGLING_TIMEOUT ?= 0

PROJECTS_ROOT = $(PWD)/projects

.EXPORT_ALL_VARIABLES:

.PHONY: build exec test push shell run start stop logs debug clean release

build:
	docker build -t ${REPO}:${VERSION} .

test:
	tests/init_test_projects.sh
	IMAGE=${REPO}:${VERSION} bats tests/test.bats

push:
	docker push ${REPO}:${VERSION}

exec:
	@docker exec ${NAME} ${CMD}

exec-it:
	@docker exec -it ${NAME} ${CMD}

shell:
	@make exec-it -e CMD=bash

conf-vhosts:
	make exec -e CMD='cat /etc/nginx/conf.d/vhosts.conf'

# This is the only place where fin is used/necessary
start:
	IMAGE_VHOST_PROXY=${REPO}:${VERSION} fin system reset vhost-proxy

stop:
	docker stop ${NAME}

logs:
	docker logs ${NAME}

logs-follow:
	docker logs -f ${NAME}

debug: build start logs-follow

release:
	@scripts/release.sh

# Curl command with http2 support via a docker container
# Usage: make curl -e ARGS='-kI https://docksal.io'
curl:
	docker run -t --rm badouralix/curl-http2 ${ARGS}

clean:
	docker rm -vf ${NAME} || true
	rm -rf projects

default: build
