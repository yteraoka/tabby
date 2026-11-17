APP := build/Taffy.app

VERSION := $(shell sed -n 's/.*current = "\(.*\)"/\1/p' Sources/Taffy/Version.swift)

.PHONY: app run install release clean

app:
	./scripts/build-app.sh

run: app
	open $(APP)

install: app
	rm -rf /Applications/Taffy.app
	cp -R $(APP) /Applications/
	@echo "Installed /Applications/Taffy.app"

release:
	./scripts/release.sh $(VERSION)

clean:
	rm -rf .build build dist
