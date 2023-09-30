#!/usr/bin/env bash

# Kernel CI build script By reallyakera

#-----------------------------------------------------------#

export TZ="Asia/Kolkata"

# Specify command.
if [[ "$@" =~ "--gcc" ]]; then
     COMPILER="gcc"
     GCC_OPT="1"
     TOOLCHAIN="arter"
     LINKER="ld.bfd"
elif [[ "$@" =~ "--clang" ]]; then
       COMPILER="clang"
       TOOLCHAIN="aosp"
       LINKER="ld.lld"
fi

# Set enviroment and vaiables
DATE="$(date +%d%m%Y-%H%M%S)"
CHATID="-1001409962367"
CI_BRANCH="$(git rev-parse --abbrev-ref HEAD)"

# The defult directory where the kernel should be placed.
KERNEL_DIR="$(pwd)"

# The name of the Kernel, to name the ZIP.
ZIPNAME="She"

# The name of the device for which the kernel is built.
MODEL="POCO F4 / REDMI K40S"

# The codename of the device.
DEVICE="munch"

# The version of the Kernel
VERSION="plus"

# The Type of the Kernel
TYPE="KernelSU"

# Set your anykernel3 repo and branch (Required)
AK3_REPO="reallyakera/AnyKernel3"
BRANCH="$DEVICE"

# The defconfig which should be used. Get it from config.gz from your device or check source
CONFIG="${DEVICE}_user_defconfig"

# Select LTO variant ( Full LTO by default )
#DISABLE_LTO="0"
#THIN_LTO="0"

# Verbose build
VERBOSE="0"

# Debug purpose. Send logs on every successfull builds.
DEBUG_LOG="0"

# Check Kernel Version
KERVER="$(make kernelversion)"

# Set a commit head
COMMIT_HEAD="$(git log --oneline -1)"

# shellcheck source=/etc/os-release
DISTRO="$(source /etc/os-release && echo "${NAME}")"

# File/artifact
IMAGE="$KERNEL_DIR/out/arch/arm64/boot/Image"
DTBO="$KERNEL_DIR/out/arch/arm64/boot/dtbo.img"
DTB="$KERNEL_DIR/out/arch/arm64/boot/dtb"

# Toolchain Directory defaults
GCC64_DIR="$KERNEL_DIR/gcc64"
GCC32_DIR="$KERNEL_DIR/gcc32"
CLANG_DIR="$KERNEL_DIR/clang"

# AnyKernel Directory default
AK_DIR="$KERNEL_DIR/anykernel3"

#-----------------------------------------------------------#

function clone() {
    if [[ "$COMPILER" == "gcc" ]]; then
         if [[ "$TOOLCHAIN" == "eva" ]]; then
              git clone --depth=1 https://github.com/mvaisakh/gcc-arm64 -b gcc-new gcc64
              git clone --depth=1 https://github.com/mvaisakh/gcc-arm -b gcc-new gcc32
         elif [[ "$TOOLCHAIN" == "arter" ]]; then
                git clone --depth=1 https://github.com/arter97/arm64-gcc gcc64
                git clone --depth=1 https://github.com/arter97/arm32-gcc gcc32
         fi
    elif [[ "$COMPILER" == "clang" ]]; then
          if [[ "$TOOLCHAIN" == "aosp" ]]; then
               git clone --depth=1 https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/aarch64/aarch64-linux-android-4.9 gcc64
               git clone --depth=1 https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/arm/arm-linux-androideabi-4.9 gcc32
               mkdir clang
               cd clang || exit
               wget -q https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/+archive/refs/heads/master/clang-r498229b.tar.gz
               tar -xzf clang*
               cd .. || exit
          elif [[ "$TOOLCHAIN" == "neutron" ]]; then
          		 mkdir clang
          		 cd clang || exit
                 bash <(curl -s https://raw.githubusercontent.com/Neutron-Toolchains/antman/main/antman) -S
                 cd .. || exit
          fi
    fi
    if [ "$AK3_REPO" ]
    then
         git clone --depth=1 https://github.com/"$AK3_REPO".git -b "$BRANCH" anykernel3
    else
         post_file "build.log" "Build failed, please setup your ak3 repo bish!"
    fi
}

#-----------------------------------------------------------#

# Export vaiables
export BOT_MSG_URL="https://api.telegram.org/bot$token/sendMessage"
export BOT_BUILD_URL="https://api.telegram.org/bot$token/sendDocument"

# Set ccache compilation.
export KERNEL_USE_CCACHE="0" # ( 1 = YES | 0 = NO(default) ) = ( https://github.com/radcolor/android_kernel_xiaomi_whyred/commit/f9736b378aa75e3554c2a47e596e01a68ee4296a )

# Export ARCH <arm, arm64, x86, x86_64>
export ARCH="arm64"

#Export SUBARCH <arm, arm64, x86, x86_64>
export SUBARCH="arm64"

# Kbuild host and user
export PROCS="$(nproc --all)"
export KBUILD_BUILD_USER="akera"
export KBUILD_BUILD_HOST="archlinux"
export KBUILD_JOBS="$(($(grep -c '^processor' /proc/cpuinfo) * 2))"
if [ "$CI" ]
then
	if [ "$CIRCLECI" ]
	then
		export KBUILD_BUILD_VERSION="$CIRCLE_BUILD_NUM"
		export CI_BRANCH="$CIRCLE_BRANCH"
	elif [ "$DRONE" ]
	then
		export KBUILD_BUILD_VERSION="$DRONE_BUILD_NUMBER"
		export CI_BRANCH="$DRONE_BRANCH"
	fi
fi
if [[ "$KERNEL_USE_CCACHE" == "1" ]]; then
	  export CCACHE_DIR="$KERNEL_DIR/.ccache"
fi
if [ "$VERSION" ]
then
     # The version of the Kernel at end.
     # if you don't need then disable it '#'
	 export LOCALVERSION="-$VERSION"
fi

#-----------------------------------------------------------#

function setup() {
    if [[ "$COMPILER" == "clang" ]]; then
         export KBUILD_COMPILER_STRING="$($CLANG_DIR/bin/clang --version | head -n 1 | perl -pe 's/\(http.*?\)//gs' | sed -e 's/  */ /g' -e 's/[[:space:]]*$//')"
         PATH="$CLANG_DIR/bin/:$PATH"
    elif [[ "$COMPILER" == "gcc" ]]; then
           export KBUILD_COMPILER_STRING="$($GCC64_DIR/bin/aarch64-elf-gcc --version | head -n 1)"
           PATH="$GCC64_DIR/bin/:$GCC32_DIR/bin/:/usr/bin:$PATH"
    fi
}

#-----------------------------------------------------------#

if [[ "$@" =~ "--notf" ]]; then

function post_msg() {
	curl -s -X POST "$BOT_MSG_URL" \
    -d chat_id="$CHATID" \
	-d "disable_web_page_preview=true" \
	-d "parse_mode=html" \
	-d text="$1"
}

fi

#-----------------------------------------------------------#

function post_file() {
    curl -F document=@$1 "$BOT_BUILD_URL" \
        -F chat_id="$CHATID"  \
        -F "disable_web_page_preview=true" \
        -F "parse_mode=html" \
        -F caption="$2"
}

#-----------------------------------------------------------#

# Export Configs
function configs() {
    if [ -d "$KERNEL_DIR/clang" ]; then
       if [ "$DISABLE_LTO" = "1" ]; then
          sed -i 's/CONFIG_LTO_CLANG=y/# CONFIG_LTO_CLANG is not set/' arch/arm64/configs/cust_defconfig
          sed -i 's/CONFIG_LTO=y/# CONFIG_LTO is not set/' arch/arm64/configs/cust_defconfig
          sed -i 's/# CONFIG_LTO_NONE is not set/CONFIG_LTO_NONE=y/' arch/arm64/configs/cust_defconfig
       elif [ "$THIN_LTO" = "1" ]; then
          sed -i 's/# CONFIG_THINLTO is not set/CONFIG_THINLTO=y/' arch/arm64/configs/cust_defconfig
       fi
    elif [ -d "$KERNEL_DIR"/gcc64 ]; then
       sed -i 's/CONFIG_LLVM_POLLY=y/# CONFIG_LLVM_POLLY is not set/' arch/arm64/configs/cust_defconfig
       sed -i 's/# CONFIG_GCC_GRAPHITE is not set/CONFIG_GCC_GRAPHITE=y/' arch/arm64/configs/cust_defconfig
       if ! [ "$DISABLE_LTO" = "1" ]; then
          sed -i 's/# CONFIG_LTO_GCC is not set/CONFIG_LTO_GCC=y/' arch/arm64/configs/cust_defconfig
       fi
    fi
}

function compile() {
    post_msg "<b>$KBUILD_BUILD_VERSION CI Build Triggered</b>%0A<b>Docker OS : </b><code>$DISTRO</code>%0A<b>Kernel Version : </b><code>$KERVER</code>%0A<b>Date : </b><code>$(TZ=Asia/Kolkata date)</code>%0A<b>Device : </b><code>$MODEL [$DEVICE]</code>%0A<b>Compiler Used : </b><code>$KBUILD_COMPILER_STRING</code>%0A<b>Linker : </b><code>$LINKER</code>%0a<b>Branch : </b><code>$CI_BRANCH</code>%0A<b>Top Commit : </b><a href='$DRONE_COMMIT_LINK'>$COMMIT_HEAD</a>"
    if [[ "$@" =~ "--ksu" ]]; then
		 echo "CONFIG_KSU=y" >> "$KERNEL_DIR/arch/arm64/configs/$CONFIG"
    fi
    make O=out "$CONFIG"
    if [[ "$@" =~ "--regen" ]]; then
		 # Generate a full DEFCONFIG prior building.
		 cp "$KERNEL_DIR"/out/.config "$KERNEL_DIR"/arch/arm64/configs/"$CONFIG"
		 git add "$KERNEL_DIR"/arch/arm64/configs/"$CONFIG"
		 git commit -m "$CONFIG: Regenerate
					   This is an auto-generated commit"
    fi
    BUILD_START="$(date +"%s")"
    if [[ "$COMPILER" == "clang" ]]; then
         if [[ "$@" =~ "--lto" ]]; then
		      "$KERNEL_DIR"/scripts/config --file "$KERNEL_DIR"/out/.config \
		      -e LTO_CLANG \
		      -d THINLTO
         fi
         if [[ "$TOOLCHAIN" == "neutron" ]]; then
		      make -kj"$KBUILD_JOBS" O=out \
			  ARCH=arm64 \
			  CC="$COMPILER" \
			  CROSS_COMPILE=aarch64-linux-gnu- \
			  CROSS_COMPILE_ARM32=arm-linux-gnueabi- \
			  LD="$LINKER" \
			  AR=llvm-ar \
			  NM=llvm-nm \
			  OBJCOPY=llvm-objcopy \
			  OBJDUMP=llvm-objdump \
			  STRIP=llvm-strip \
			  READELF=llvm-readelf \
			  OBJSIZE=llvm-size \
			  V="$VERBOSE" 2>&1 | tee build.log
         elif [[ "$TOOLCHAIN" == "aosp" ]]; then
		        make -kj"$KBUILD_JOBS" O=out \
			    ARCH=arm64 \
			    CC="$COMPILER" \
			    CLANG_TRIPLE=aarch64-linux-gnu- \
			    CROSS_COMPILE=aarch64-linux-gnu- \
			    CROSS_COMPILE_ARM32=arm-linux-gnueabi- \
			    LD="$LINKER" \
			    AR=llvm-ar \
			    NM=llvm-nm \
			    OBJCOPY=llvm-objcopy \
			    OBJDUMP=llvm-objdump \
			    STRIP=llvm-strip \
			    READELF=llvm-readelf \
			    OBJSIZE=llvm-size \
			    V="$VERBOSE" 2>&1 | tee build.log
         fi
	elif [[ "$COMPILER" == "gcc" ]]; then
          if [[ "$TOOLCHAIN" == "eva" || "$TOOLCHAIN" == "arter" ]]; then
			   make -kj"$KBUILD_JOBS" O=out \
			   ARCH=arm64 \
			   CROSS_COMPILE_ARM32=arm-eabi- \
			   CROSS_COMPILE=aarch64-elf- \
			   LD=aarch64-elf-"$LINKER" \
			   AR=llvm-ar \
			   NM=llvm-nm \
			   OBJCOPY=llvm-objcopy \
			   OBJDUMP=llvm-objdump \
			   STRIP=llvm-strip \
			   OBJSIZE=llvm-size \
			   V="$VERBOSE" 2>&1 | tee build.log
          fi
    fi
    BUILD_END="$(date +"%s")"
    DIFF="$(($BUILD_END - $BUILD_START))"
    if ! [ -a "$IMAGE" ]; then
          echo "Build failed in $(($DIFF / 60)) minute(s) and $(($DIFF % 60)) second(s)."
          post_file "build.log" "Build failed, please fix the errors first bish!"
          exit
    else
          echo "Build completed in $(($DIFF / 60)) minute(s) and $(($DIFF % 60)) second(s)."
          find "$KERNEL_DIR"/out/arch/arm64/boot/dts/vendor/qcom -name '*.dtb' -exec cat {} + >"$KERNEL_DIR"/out/arch/arm64/boot/dtb
          cp "$IMAGE" "$AK_DIR"
          cp "$DTBO" "$AK_DIR"
          cp "$DTB" "$AK_DIR"
          finalize
    fi
}

#-----------------------------------------------------------#

function finalize() {
    echo "Now making a flashable zip of kernel with AnyKernel3"
    cd "$AK_DIR" || exit
    zip -r9 "$ZIPNAME-$VERSION-$TYPE-$DEVICE-$DATE" ./* -x .git LICENSE README.md

    # Prepare a final zip variable
    FINAL_ZIP="$ZIPNAME-$VERSION-$TYPE-$DEVICE-$DATE.zip"

    #Post MD5Checksum alongwith for easeness
    MD5CHECK="$(md5sum "${FINAL_ZIP}" | cut -d' ' -f1)"

    post_file "$FINAL_ZIP" "Build took $(($DIFF / 60)) minute(s) and $(($DIFF % 60)) second(s). | <b>MD5 Checksum : </b><code>$MD5CHECK</code> | Compiler : $KBUILD_COMPILER_STRING"
}

#-----------------------------------------------------------#

clone
setup
#configs
compile

#-----------------------------------------------------------#

if [[ "$DEBUG_LOG" == "1" ]]; then
	 post_file "build.log" "Debug Mode Logs"
fi

#-----------------------------------------------------------#
