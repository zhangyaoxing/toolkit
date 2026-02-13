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

chmod +x MouseMover.app/Contents/MacOS/toolkit
xattr -cr MouseMover.app
codesign --force --deep --sign - MouseMover.app

echo "Build complete! MouseMover.app has been generated."