.SILENT :
.PHONY : docker-gen clean fmt

TAG:=docksal-vhost-proxy
LDFLAGS:=-X main.buildVersion=$(TAG)

all: docker-gen

docker-gen:
	echo "Building docker-gen"
	go build -ldflags "$(LDFLAGS)" ./cmd/docker-gen

dist-clean:
	rm -rf dist
	rm -f docker-gen-alpine-linux-*.tar.gz
	rm -f docker-gen-linux-*.tar.gz
	rm -f docker-gen-darwin-*.tar.gz

dist: dist-clean
	mkdir -p dist/alpine-linux/amd64 && GOOS=linux GOARCH=amd64 go build -ldflags "$(LDFLAGS)" -a -tags netgo -installsuffix netgo -o dist/alpine-linux/amd64/docker-gen ./cmd/docker-gen

release: dist
	glock sync -n < GLOCKFILE
	tar -cvzf docker-gen-alpine-linux-amd64-$(TAG).tar.gz -C dist/alpine-linux/amd64 docker-gen

get-deps:
	go get github.com/robfig/glock
	glock sync -n < GLOCKFILE

check-gofmt:
	if [ -n "$(shell gofmt -l .)" ]; then \
		echo 1>&2 'The following files need to be formatted:'; \
		gofmt -l .; \
		exit 1; \
	fi

test:
	go test
