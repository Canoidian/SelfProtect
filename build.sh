#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$PROJECT_DIR/.build"
APP_NAME="SelfProtect"
BUNDLE_ID="com.selfprotect.app"
DEPLOYMENT_TARGET="macosx14.0"
ARCH="arm64-apple-macosx14.0"

VFS_OVERLAY="/tmp/vfs.yaml"

echo "=== Creating VFS overlay for CLT workaround ==="
if [ ! -f "$VFS_OVERLAY" ]; then
    cat > "$VFS_OVERLAY" << 'EOF'
{
  "version": 0,
  "roots": [
    {
      "name": "/Library/Developer/CommandLineTools/usr/include/swift",
      "type": "directory",
      "contents": [
        {
          "name": "module.modulemap",
          "type": "file",
          "external-contents": "/dev/null"
        }
      ]
    }
  ]
}
EOF
fi

COMMON_FLAGS="-target $ARCH -vfsoverlay $VFS_OVERLAY"

echo "=== Cleaning build directory ==="
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR/selfprotectkit"
mkdir -p "$BUILD_DIR/helper"
mkdir -p "$BUILD_DIR/app"
mkdir -p "$BUILD_DIR/module-cache"

KIT_SOURCES=$(find "$PROJECT_DIR/SelfProtectKit/Sources" -name "*.swift" | sort)
HELPER_SOURCES=$(find "$PROJECT_DIR/SelfProtectHelper" -name "*.swift" | sort)
APP_SOURCES=$(find "$PROJECT_DIR/SelfProtect" -name "*.swift" | sort)

echo "=== Building SelfProtectKit (static library) ==="
swiftc \
    $COMMON_FLAGS \
    -emit-module -emit-library -static \
    -module-name SelfProtectKit \
    -o "$BUILD_DIR/selfprotectkit/libSelfProtectKit.a" \
    -module-cache-path "$BUILD_DIR/module-cache" \
    $KIT_SOURCES

echo "=== Building SelfProtectHelper ==="
swiftc \
    $COMMON_FLAGS \
    -I "$BUILD_DIR/selfprotectkit" \
    -module-cache-path "$BUILD_DIR/module-cache" \
    -o "$BUILD_DIR/helper/SelfProtectHelper" \
    $HELPER_SOURCES \
    "$BUILD_DIR/selfprotectkit/libSelfProtectKit.a"

echo "=== Building SelfProtect App ==="
swiftc \
    $COMMON_FLAGS \
    -I "$BUILD_DIR/selfprotectkit" \
    -module-cache-path "$BUILD_DIR/module-cache" \
    -o "$BUILD_DIR/app/SelfProtect" \
    $APP_SOURCES \
    "$BUILD_DIR/selfprotectkit/libSelfProtectKit.a" \
    -framework SwiftUI -framework AppKit

echo "=== Creating .app bundle ==="
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"
mkdir -p "$APP_BUNDLE/Contents/Library/LaunchDaemons"

cp "$BUILD_DIR/app/SelfProtect" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
cp "$BUILD_DIR/helper/SelfProtectHelper" "$APP_BUNDLE/Contents/MacOS/SelfProtectHelper"
cp "$PROJECT_DIR/SelfProtect/Library/LaunchDaemons/com.selfprotect.helper.plist" \
   "$APP_BUNDLE/Contents/Library/LaunchDaemons/com.selfprotect.helper.plist"

cp "$PROJECT_DIR/SelfProtect/Resources/AppIcon.icns" \
   "$APP_BUNDLE/Contents/Resources/AppIcon.icns"

cat > "$APP_BUNDLE/Contents/Info.plist" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>CFBundleDocumentTypes</key>
    <array>
        <dict>
            <key>CFBundleTypeName</key>
            <string>SelfProtect Block List</string>
            <key>LSHandlerRank</key>
            <string>Owner</string>
            <key>LSItemContentTypes</key>
            <array><string>com.selfprotect.blocklist</string></array>
        </dict>
    </array>
    <key>UTExportedTypeDeclarations</key>
    <array>
        <dict>
            <key>UTTypeIdentifier</key>
            <string>com.selfprotect.blocklist</string>
            <key>UTTypeTagSpecification</key>
            <dict>
                <key>public.filename-extension</key>
                <array><string>selfprotect</string></array>
            </dict>
            <key>UTTypeDescription</key>
            <string>SelfProtect Block List</string>
            <key>UTTypeConformsTo</key>
            <array><string>public.json</string></array>
        </dict>
    </array>
</dict>
</plist>
PLIST

echo "=== Code signing (ad-hoc) ==="
codesign --sign - --force --deep "$APP_BUNDLE" 2>&1 || echo "Warning: code signing failed (app may still work)"

echo ""
echo "=== DONE ==="
echo ".app bundle: $APP_BUNDLE"

echo ""
echo "=== Creating .pkg installer ==="
PKG_PATH="$BUILD_DIR/$APP_NAME.pkg"
pkgbuild \
    --root "$APP_BUNDLE" \
    --identifier "$BUNDLE_ID" \
    --version "1.0" \
    --install-location "/Applications/$APP_NAME.app" \
    "$PKG_PATH" 2>&1

echo ""
echo "=== DONE ==="
echo ".app bundle:  $APP_BUNDLE"
echo ".pkg:         $PKG_PATH"
echo ""
echo "To install: open \"$PKG_PATH\""
