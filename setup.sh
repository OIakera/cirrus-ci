#!/usr/bin/env bash

# Clone kernel
git clone --depth=1 https://github.com/reallyakera/stock-munch -b munch-s-oss kernel

# Build
cd kernel
bash munch.sh --clang --ksu --lto
