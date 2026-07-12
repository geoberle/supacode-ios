SCHEME = SupacodeViewer
DEVICE = iPad Pro 13-inch (M5)
DERIVED_DATA = .build/derived-data
APP_PATH = $(DERIVED_DATA)/Build/Products/Debug-iphonesimulator/SupacodeViewer.app
BUNDLE_ID = app.supabit.supacode.viewer


.PHONY: tools generate build test lint run screenshot clean

tools:
	brew install xcodegen xcbeautify swiftlint

generate:
	xcodegen generate

build: generate
	xcodebuild -scheme $(SCHEME) -sdk iphonesimulator \
		-destination 'platform=iOS Simulator,name=$(DEVICE)' \
		-derivedDataPath $(DERIVED_DATA) build 2>&1 | xcbeautify

test: generate
	xcodebuild -scheme $(SCHEME) -sdk iphonesimulator \
		-destination 'platform=iOS Simulator,name=$(DEVICE)' \
		-derivedDataPath $(DERIVED_DATA) test 2>&1 | xcbeautify

lint:
	swiftlint

run: build
	xcrun simctl boot "$(DEVICE)" 2>/dev/null || true
	xcrun simctl install booted $(APP_PATH)
	xcrun simctl terminate booted $(BUNDLE_ID) 2>/dev/null || true
	xcrun simctl launch booted $(BUNDLE_ID)

screenshot:
	xcrun simctl io booted screenshot /tmp/ios-sim-screenshot.png

clean:
	rm -rf $(DERIVED_DATA)
