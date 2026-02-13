#!/bin/bash

# 1. Build release version
swift build -c release

# 2. Create directory structure
mkdir -p MouseMover.app/Contents/MacOS
mkdir -p MouseMover.app/Contents/Resources

# 3. Copy binary file (note: path may vary based on your Package name)
cp .build/release/toolkit MouseMover.app/Contents/MacOS/

# 4. Copy Info.plist
cp Info.plist MouseMover.app/Contents/

# 5. Copy icon file
cp icon.icns MouseMover.app/Contents/Resources/

# 6. Set permissions and codesign
chmod +x MouseMover.app/Contents/MacOS/toolkit
xattr -cr MouseMover.app

# Sign with entitlements to maintain Accessibility permissions
codesign --force --deep --sign - --entitlements MouseMover.entitlements MouseMover.app

echo "Build complete! MouseMover.app has been generated."

# 7. Copy to /Applications
echo "Installing MouseMover.app to /Applications..."
if [ -d "/Applications/MouseMover.app" ]; then
    echo "Removing old version..."
    sudo rm -rf /Applications/MouseMover.app
fi
sudo cp -R MouseMover.app /Applications/MouseMover.app

echo ""
echo "Installation complete!"
echo "If Accessibility permission is lost, run: ./reset-permissions.sh"