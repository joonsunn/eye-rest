.PHONY: build test smoke run clean

build:
	./Scripts/make-app.sh

test:
	swift test

smoke: build
	open --env EYE_REST_WORK_SECONDS=10 --env EYE_REST_BREAK_SECONDS=5 .build/EyeRest.app

run: build
	open .build/EyeRest.app

clean:
	swift package clean
