#!/bin/bash

# 1. 编译 release 版本
swift build -c release

# 2. 创建目录结构
mkdir -p MouseMover.app/Contents/MacOS
mkdir -p MouseMover.app/Contents/Resources

# 3. 拷贝二进制文件 (注意路径可能根据你的 Package 名字变化)
cp .build/release/toolkit MouseMover.app/Contents/MacOS/

# 4. 拷贝 Info.plist
cp Info.plist MouseMover.app/Contents/

echo "打包完成！MouseMover.app 已生成。"