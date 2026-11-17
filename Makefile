APP := build/Tabby.app

VERSION := $(shell sed -n 's/.*current = "\(.*\)"/\1/p' Sources/Tabby/Version.swift)

.PHONY: app run install release clean

app:
	./scripts/build-app.sh

run: app
	open $(APP)

install: app
	rm -rf /Applications/Tabby.app
	cp -R $(APP) /Applications/
	@echo "Installed /Applications/Tabby.app"

release:
	./scripts/release.sh $(VERSION)

clean:
	rm -rf .build build dist
