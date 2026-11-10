#!/bin/zsh
# Builds dist/HP-11C.app — a standalone macOS app wrapping index.html.
# Usage: ./macos/build.sh            (build)
#        ./macos/build.sh --install  (build + copy to /Applications)
set -euo pipefail

ROOT="${0:A:h:h}"
APP="$ROOT/dist/HP-11C.app"
VERSION="1.0"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources/web"

echo "→ Compiling…"
swiftc -O -target arm64-apple-macos13 -o "$APP/Contents/MacOS/HP-11C-arm64" "$ROOT/macos/main.swift"
if swiftc -O -target x86_64-apple-macos13 -o "$APP/Contents/MacOS/HP-11C-x86_64" "$ROOT/macos/main.swift" 2>/dev/null; then
  lipo -create -output "$APP/Contents/MacOS/HP-11C" "$APP/Contents/MacOS/HP-11C-"{arm64,x86_64}
  rm "$APP/Contents/MacOS/HP-11C-"{arm64,x86_64}
else
  mv "$APP/Contents/MacOS/HP-11C-arm64" "$APP/Contents/MacOS/HP-11C"
fi

cp "$ROOT/index.html" "$APP/Contents/Resources/web/index.html"
cp "$ROOT/macos/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key>                <string>HP-11C</string>
  <key>CFBundleDisplayName</key>         <string>HP-11C</string>
  <key>CFBundleIdentifier</key>          <string>local.hp11c.calculator</string>
  <key>CFBundleExecutable</key>          <string>HP-11C</string>
  <key>CFBundleIconFile</key>            <string>AppIcon</string>
  <key>CFBundlePackageType</key>         <string>APPL</string>
  <key>CFBundleShortVersionString</key>  <string>$VERSION</string>
  <key>CFBundleVersion</key>             <string>$VERSION</string>
  <key>LSMinimumSystemVersion</key>      <string>13.0</string>
  <key>LSApplicationCategoryType</key>   <string>public.app-category.utilities</string>
  <key>NSHighResolutionCapable</key>     <true/>
  <key>NSHumanReadableCopyright</key>    <string>Simulateur HP-11C</string>
</dict>
</plist>
PLIST

# Ad-hoc signature so macOS runs it locally without complaints
codesign --force --deep --sign - "$APP" >/dev/null
echo "✓ Built $APP"

if [[ "${1:-}" == "--install" ]]; then
  rm -rf "/Applications/HP-11C.app"
  cp -R "$APP" /Applications/
  echo "✓ Installed in /Applications/HP-11C.app"
fi
