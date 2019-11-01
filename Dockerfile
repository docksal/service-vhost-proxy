FROM openresty/openresty:1.13.6.2-1-alpine

RUN set -xe; \
	apk add --update --no-cache \
		bash \
		curl \
		sudo \
		supervisor \
	; \
	rm -rf /var/cache/apk/*

RUN set -xe; \
	addgroup -S nginx; \
	adduser -D -S -h /var/cache/nginx -s /sbin/nologin -G nginx nginx

ARG DOCKER_VERSION=18.06.1-ce
ARG DOCKER_GEN_VERSION=0.7.4
ARG GOMPLATE_VERSION=3.0.0

# Install docker client binary (if not mounting binary from host)
RUN set -xe; \
	curl -sSL -O "https://download.docker.com/linux/static/stable/x86_64/docker-${DOCKER_VERSION}.tgz"; \
	tar zxf docker-$DOCKER_VERSION.tgz; \
	mv docker/docker /usr/local/bin ; \
	rm -rf docker*

# Install docker-gen
ARG DOCKER_GEN_TARFILE=docker-gen-alpine-linux-amd64-$DOCKER_GEN_VERSION.tar.gz
RUN set -xe; \
	curl -sSL -O "https://github.com/jwilder/docker-gen/releases/download/${DOCKER_GEN_VERSION}/${DOCKER_GEN_TARFILE}"; \
	tar -C /usr/local/bin -xvzf $DOCKER_GEN_TARFILE; \
	rm $DOCKER_GEN_TARFILE

# Install gomplate
RUN set -xe; \
	curl -sSL https://github.com/hairyhenderson/gomplate/releases/download/v${GOMPLATE_VERSION}/gomplate_linux-amd64-slim -o /usr/local/bin/gomplate; \
	chmod +x /usr/local/bin/gomplate

RUN set -xe; \
	# Symlink openresety config folder to /etc/nginx to preserver full compatibility with original nginx setup
	rm -rf /etc/nginx && ln -s /usr/local/openresty/nginx/conf /etc/nginx ; \
	mkdir -p /etc/nginx/conf.d ; \
	# Also symlink nginx binary to a location in PATH
	ln -s /usr/local/openresty/nginx/sbin/nginx /usr/sbin/nginx

# Certs and OAuth
RUN set -xe; \
	apk add --update --no-cache \
		openssl \
		git \
	; \
	# Create a folder for custom vhost certs (mount custom certs here)
	mkdir -p /etc/certs/custom; \
	# Generate a self-signed fallback cert
	openssl req \
		-batch \
		-newkey rsa:4086 \
		-x509 \
		-nodes \
		-sha256 \
		-subj "/CN=*.docksal" \
		-days 3650 \
		-out /etc/certs/server.crt \
		-keyout /etc/certs/server.key; \
	# Install OAuth dependencies
	git clone -c transfer.fsckobjects=true https://github.com/pintsized/lua-resty-http.git /tmp/lua-resty-http; \
	cd /tmp/lua-resty-http; \
	# https://github.com/pintsized/lua-resty-http/releases/tag/v0.07 v0.07
	git checkout 69695416d408f9cfdaae1ca47650ee4523667c3d; \
	mkdir -p /etc/nginx/lua; \
	cp -aR /tmp/lua-resty-http/lib/resty /etc/nginx/lua/resty; \
	rm -rf /tmp/lua-resty-http; \
	apk del openssl git && rm -rf /var/cache/apk/*;

COPY conf/nginx/ /etc/nginx/
COPY conf/sudoers /etc/sudoers
# Override the main supervisord config file, since some parameters are not overridable via an include
# See https://github.com/Supervisor/supervisor/issues/962
COPY conf/supervisord.conf /etc/supervisord.conf
COPY conf/crontab /var/spool/cron/crontabs/root
COPY bin /usr/local/bin
COPY www /var/www
COPY healthcheck.sh /opt/healthcheck.sh

# Fix permissions
RUN chmod 0440 /etc/sudoers

ENV \
	# Disable INACTIVITY_TIMEOUT by default
	PROJECT_INACTIVITY_TIMEOUT=0 \
	# Disable DANGLING_TIMEOUT by default
	PROJECT_DANGLING_TIMEOUT=0 \
	# Disable access log by default
	ACCESS_LOG=0 \
	# Disable debug output by default
	DEBUG_LOG=0 \
	# Disable stats log by default
	STATS_LOG=0 \
	# Default domain
	DEFAULT_CERT=docksal

# Starter script
ENTRYPOINT ["docker-entrypoint.sh"]

# By default, launch supervisord to keep the container running.
CMD ["supervisord"]

# Health check script
HEALTHCHECK --interval=5s --timeout=1s --retries=3 CMD ["/opt/healthcheck.sh"]
