EXTRACTED_DRIVERS_5_3_7_6= \
	src/5.3.7-6/PenTabletDriver.original \
	src/5.3.7-6/ConsumerTouchDriver.original \
	src/5.3.7-6/preinstall.original \
	src/5.3.7-6/postinstall.original \
	src/5.3.7-6/renumtablets

PATCHED_DRIVERS_5_3_7_6= \
	src/5.3.7-6/PenTabletDriver.patched \
	src/5.3.7-6/ConsumerTouchDriver.patched \
	src/5.3.7-6/preinstall.patched \
	src/5.3.7-6/postinstall.patched

EXTRACTED_DRIVERS+= $(EXTRACTED_DRIVERS_5_3_7_6)

PATCHED_DRIVERS+= $(PATCHED_DRIVERS_5_3_7_6)

SIGN_ME_5_3_7_6= \
	package/content.pkg/Payload/Library/Application\ Support/Tablet/PenTabletDriver.app/Contents/Resources/TabletDriver.app \
	package/content.pkg/Payload/Library/Application\ Support/Tablet/PenTabletDriver.app/Contents/Resources/ConsumerTouchDriver.app \
	package/content.pkg/Payload/Library/Application\ Support/Tablet/PenTabletDriver.app \
	package/content.pkg/Payload/Library/Frameworks/WacomMultiTouch.framework/Versions/A/WacomMultiTouch \
	package/content.pkg/Payload/Library/PrivilegedHelperTools/com.wacom.TabletHelper.app/Contents/MacOS/com.wacom.TabletHelper \
	package/content.pkg/Payload/Applications/Pen\ Tablet.localized/Pen\ Tablet\ Utility.app/Contents/Library/LaunchServices/com.wacom.RemoveTabletHelper \
	package/content.pkg/Payload/Applications/Pen\ Tablet.localized/Pen\ Tablet\ Utility.app/Contents/Resources/SystemLoginItemTool \
	package/content.pkg/Payload/Applications/Pen\ Tablet.localized/Pen\ Tablet\ Utility.app \
	package/content.pkg/Scripts/renumtablets

MANUAL_INSTALLERS+= wacom-5.3.7-6-macOS-patched.zip
UNSIGNED_INSTALLERS+= Install\ Wacom\ Tablet-5.3.7-6-patched-unsigned.pkg
SIGNED_INSTALLERS+= Install\ Wacom\ Tablet-5.3.7-6-patched.pkg

wacom-5.3.7-6-macOS-patched.zip : $(PATCHED_DRIVERS_5_3_7_6) build/ build/Readme.html
	rm -f $@
	cp src/5.3.7-6/PenTabletDriver.patched build/PenTabletDriver
	cp src/5.3.7-6/ConsumerTouchDriver.patched build/ConsumerTouchDriver
	cd build && zip --must-match ../$@ PenTabletDriver ConsumerTouchDriver Readme.html

# Create the installer package by modifying Wacom's original:

Install\ Wacom\ Tablet-5.3.7-6-patched-unsigned.pkg : src/5.3.7-6/Install\ Wacom\ Tablet.pkg $(PATCHED_DRIVERS_5_3_7_6) src/5.3.7-6/Welcome.rtf
	$(call unpack_package,"src/5.3.7-6/Install Wacom Tablet.pkg")

	# Add Welcome screen
	find package/Resources -type d -depth 1 -exec cp src/5.3.7-6/Welcome.rtf {}/ \;
	sed -i "" -E 's/(<\/installer-gui-script>)/    <welcome file="Welcome.rtf" mime-type="text\/richtext"\/>\1/' package/Distribution

	# Add patched drivers
	cp src/5.3.7-6/PenTabletDriver.patched package/content.pkg/Payload/Library/Application\ Support/Tablet/PenTabletDriver.app/Contents/MacOS/PenTabletDriver
	cp src/5.3.7-6/ConsumerTouchDriver.patched package/content.pkg/Payload/Library/Application\ Support/Tablet/PenTabletDriver.app/Contents/Resources/ConsumerTouchDriver.app/Contents/MacOS/ConsumerTouchDriver
	cp src/5.3.7-6/preinstall.patched package/content.pkg/Scripts/preinstall
	cp src/5.3.7-6/postinstall.patched package/content.pkg/Scripts/postinstall
	cp src/5.3.7-6/unloadagent src/5.3.7-6/loadagent package/content.pkg/Scripts/

ifdef CODE_SIGNING_IDENTITY
	# Resign drivers and enable Hardened Runtime to meet notarization requirements
	codesign -s "$(CODE_SIGNING_IDENTITY)" -f --options=runtime --timestamp $(SIGN_ME_5_3_7_6)
else
	codesign --remove-signature $(SIGN_ME_5_3_7_6)
endif

	# Recreate BOM
	mkbom package/content.pkg/Payload package/content.pkg/Bom

	# Repack payload
	( \
		( cd package/content.pkg/Payload && find . ! -path "./Library/Extensions*" | cpio -o --format odc --owner 0:80 ) ; \
		( cd package/content.pkg/Payload && find ./Library/Extensions              | cpio -o --format odc --owner 0:0 ) ; \
	) | gzip -c > package/content.pkg/Payload.gz
	rm -rf package/content.pkg/Payload
	mv package/content.pkg/Payload.gz package/content.pkg/Payload

	# Repack installer
	pkgutil --flatten package "$@"

ifdef PACKAGE_SIGNING_IDENTITY
Install\ Wacom\ Tablet-5.3.7-6-patched.pkg : Install\ Wacom\ Tablet-5.3.7-6-patched-unsigned.pkg
	productsign --sign "$(PACKAGE_SIGNING_IDENTITY)" Install\ Wacom\ Tablet-5.3.7-6-patched-unsigned.pkg Install\ Wacom\ Tablet-5.3.7-6-patched.pkg
endif

# Download, mount and unpack original Wacom installers:

src/5.3.7-6/pentablet_5.3.7-6.dmg :
	curl -o $@ "https://cdn.wacom.com/u/productsupport/drivers/mac/consumer/pentablet_5.3.7-6.dmg"
	[ $$(md5 $@ | awk '{ print $$4 }') = "3d87c6c5ca73d9f361a21fe2c2e940e2" ] || (rm $@; false) # Verify download is undamaged

src/5.3.7-6/Install\ Wacom\ Tablet.pkg : src/5.3.7-6/pentablet_5.3.7-6.dmg
	hdiutil attach -quiet -nobrowse -mountpoint src/5.3.7-6/dmg "$<"
	cp "src/5.3.7-6/dmg/Install Wacom Tablet.pkg" "$@"
	hdiutil detach -force src/5.3.7-6/dmg

# Extract original files from the Wacom installers as needed:

$(EXTRACTED_DRIVERS_5_3_7_6) : src/5.3.7-6/Install\ Wacom\ Tablet.pkg
	$(call unpack_package,"$<")

	cp package/content.pkg/Payload/Library/Application\ Support/Tablet/PenTabletDriver.app/Contents/MacOS/PenTabletDriver src/5.3.7-6/PenTabletDriver.original
	cp package/content.pkg/Payload/Library/Application\ Support/Tablet/PenTabletDriver.app/Contents/Resources/ConsumerTouchDriver.app/Contents/MacOS/ConsumerTouchDriver src/5.3.7-6/ConsumerTouchDriver.original
	cp package/content.pkg/Scripts/preinstall   src/5.3.7-6/preinstall.original
	cp package/content.pkg/Scripts/postinstall  src/5.3.7-6/postinstall.original
	cp package/content.pkg/Scripts/renumtablets src/5.3.7-6/renumtablets

# Utility commands:

notarize-bamboo: Install\ Wacom\ Tablet-5.3.7-6-patched.pkg
	xcrun altool \
		 --notarize-app \
		 --primary-bundle-id "com.wacom.pentablet" \
		 --username "$(NOTARIZATION_USERNAME)" \
		 --password "@keychain:AC_PASSWORD" \
		 --file "$<"
	cp "$<" "Install Wacom Tablet-5.3.7-6-patched-notarized.pkg"

staple-bamboo:
	xcrun stapler staple "Install Wacom Tablet-5.3.7-6-patched.pkg"
	cp "Install Wacom Tablet-5.3.7-6-patched.pkg" "Install Wacom Tablet-5.3.7-6-patched-stapled.pkg"

unpack-bamboo : src/5.3.7-6/Install\ Wacom\ Tablet.pkg
	$(call unpack_package,"$<")

unbless-bamboo:
	xattr -w com.apple.quarantine "0181;5e33ca0a;Chrome;AEDC174C-8684-476E-9E4C-764D063A714C" Install\ Wacom\ Tablet-5.3.7-6-patched-unsigned.pkg
