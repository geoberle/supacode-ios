SCHEME = SupacodeViewer
DEVICE = iPad Pro 13-inch (M5)
IPHONE = iPhone 17 Pro
DERIVED_DATA = .build/derived-data
APP_PATH = $(DERIVED_DATA)/Build/Products/Debug-iphonesimulator/SupacodeViewer.app
BUNDLE_ID = app.supabit.supacode.viewer

.PHONY: tools generate build build-iphone test lint run run-iphone screenshot open clean

tools:
	brew install xcodegen xcbeautify swiftlint

generate:
	xcodegen generate

build: generate
	xcodebuild -scheme $(SCHEME) -sdk iphonesimulator \
		-destination 'platform=iOS Simulator,name=$(DEVICE)' \
		-derivedDataPath $(DERIVED_DATA) build 2>&1 | xcbeautify

build-iphone: generate
	xcodebuild -scheme $(SCHEME) -sdk iphonesimulator \
		-destination 'platform=iOS Simulator,name=$(IPHONE)' \
		-derivedDataPath $(DERIVED_DATA) build 2>&1 | xcbeautify

test: generate
	xcodebuild -scheme $(SCHEME) -sdk iphonesimulator \
		-destination 'platform=iOS Simulator,name=$(DEVICE)' \
		-derivedDataPath $(DERIVED_DATA) test 2>&1 | xcbeautify

lint:
	swiftlint --strict

run: build
	xcrun simctl boot "$(DEVICE)" 2>/dev/null || true
	xcrun simctl install booted $(APP_PATH)
	xcrun simctl terminate booted $(BUNDLE_ID) 2>/dev/null || true
	xcrun simctl launch booted $(BUNDLE_ID)
	open -a Simulator

run-iphone: build-iphone
	xcrun simctl boot "$(IPHONE)" 2>/dev/null || true
	xcrun simctl install booted $(APP_PATH)
	xcrun simctl terminate booted $(BUNDLE_ID) 2>/dev/null || true
	xcrun simctl launch booted $(BUNDLE_ID)
	open -a Simulator

screenshot:
	xcrun simctl io booted screenshot /tmp/ios-sim-screenshot.png
	@echo "Screenshot saved to /tmp/ios-sim-screenshot.png"

open:
	open -a Simulator

clean:
	rm -rf $(DERIVED_DATA)
