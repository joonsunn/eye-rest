.PHONY: build test vet fmt app run smoke dist clean

build:
	go build -o .build/eye-rest-go .

test:
	go test ./...

vet:
	go vet ./...

fmt:
	test -z "$$(gofmt -l .)"

app:
	./build-app.sh

run: app
	open .build/EyeRestGo.app

smoke: app
	HOME="$$(mktemp -d)" EYE_REST_GO_DEBUG=1 EYE_REST_WORK_SECONDS=10 EYE_REST_BREAK_SECONDS=5 ./.build/EyeRestGo.app/Contents/MacOS/eye-rest-go > /tmp/eye-rest-go-smoke.log 2>&1 & pid=$$!; sleep 25; kill -TERM $$pid; wait $$pid 2>/dev/null; true; cat /tmp/eye-rest-go-smoke.log

VERSION ?= $(shell git describe --tags --always --dirty 2>/dev/null || echo dev)
ARCH ?= $(shell go env GOARCH)

dist: app
	cd .build && ditto -c -k --keepParent EyeRestGo.app eye-rest-go-$(VERSION)-darwin-$(ARCH).zip
	ls -la .build/*.zip

clean:
	go clean
	rm -rf .build
