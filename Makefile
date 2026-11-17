APP := build/Tabby.app

.PHONY: app run install clean

app:
	./scripts/build-app.sh

run: app
	open $(APP)

install: app
	rm -rf /Applications/Tabby.app
	cp -R $(APP) /Applications/
	@echo "Installed /Applications/Tabby.app"

clean:
	rm -rf .build build
