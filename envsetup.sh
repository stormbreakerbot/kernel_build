#!/usr/bin/env bash

#
# Copyright (C) 2019 Saalim Quadri (danascape)
#
# SPDX-License-Identifier: Apache-2.0 license
#

function getTop() {
    local TOPFILE=build/envsetup.sh
    if [[ -f "$TOPFILE" ]] ; then
        PWD= /bin/pwd
    else
        local HERE=$PWD
        local T=
        while [ \( ! \( -f $TOPFILE \) \) -a \( "$PWD" != "/" \) ]; do
            \cd ..
            T=`PWD= /bin/pwd -P`
        done
            \cd "$HERE"
        if [ -f "$T/$TOPFILE" ]; then
            echo "$T"
        fi
    fi
}

function setBuildVariables() {
    local TOP=$(getTop)
    source $TOP/build/src/build_vars.sh
}

function setupDevice() {

    local TOP=$(getTop)
    if [[ $# = 0 ]]; then
        echo "usage: setDevice [target]" >&2
        return 1
    fi

    setBuildVariables

    local DEVICE="$1"
    cd "$TOP"
    if [[ -n $(find -L $TOP -maxdepth 4 -name "device-$DEVICE.sh") ]]; then
        for dir in device; do
            for f in $(cd "$TOP" && test -d $dir && \
                find -L $TOP -maxdepth 4 -name "device-$DEVICE.sh" | sort); do
                    echo "including $f"; . "$T/$f"
            done
        done
        displayDeviceInfo $DEVICE
    else
        echo "error: Can not locate config for product "$DEVICE""
    fi
}

function displayDeviceInfo() {

    if [[ $# = 0 ]]; then
        echo "usage: displayDeviceInfo [target]" >&2
        return 1
    fi

    local DEVICE="$1"
    local TARGET_DEVICE="$DEVICE"
    local HOST_OS=$(uname)
    local HOST_OS_EXTRA=$(uname -r)
    setupCompiler
    echo "============================================"
    echo "TARGET_DEVICE=$TARGET_DEVICE"
    echo "TARGET_ARCH=$TARGET_ARCH"
    echo "TARGET_KERNEL_VERSION=$TARGET_KERNEL_VERSION"
    echo "KERNEL_DEFCONFIG=$KERNEL_DEFCONFIG"
    echo "KERNEL_DIR=$KERNEL_DIR"
    echo "HOST_OS=$HOST_OS"
    echo "HOST_OS_EXTRA=$HOST_OS_EXTRA"
    if [[ $TARGET_USES_GCC ]]; then
        echo "HOST_COMPILER_GCC_VERSION=$TARGET_GCC_VERSION"
    fi
    echo "HOST_COMPILER=clang $TARGET_CLANG"
    echo "HOST_COMPILER_VERSION=$TARGET_CLANG_VERSION"
    echo "HOST_COMPILER_PATH=$COMPILER_PATH"
    echo "OUT_DIR=out" # HardCode this for now.
    echo "============================================"
}

function setupCompiler() {
    local TOP=$(getTop)
    local PREBUILT_CLANG_PATH="$TOP/prebuilts/clang/host/linux-x86"
    local PREBUILT_GCC_PATH="$TOP/prebuilts/gcc/linux-x86"
    if [[ $TARGET_CLANG ]]; then
        echo "warning: TARGET_CLANG is already set!"
    else
        echo "warning: TARGET_CLANG not found"
        echo "warning: Setting clang 10 as default!"
        TARGET_CLANG=10
    fi
    export TARGET_CLANG_VERSION=$($PREBUILT_CLANG_PATH/clang-$TARGET_CLANG/bin/clang --version | head -n 1 | cut -f1,6,8 -d " ")
    export CLANG_COMPILER_PATH="$PREBUILT_CLANG_PATH/clang-$TARGET_CLANG/bin"
    if [[ $TARGET_USES_GCC ]]; then
        export GCC_ARM_COMPILER_PATH="$PREBUILT_GCC_PATH/arm/arm-linux-androideabi-4.9/bin"
        export GCC_ARM64_COMPILER_PATH="$PREBUILT_GCC_PATH/aarch64/aarch64-linux-android-4.9/bin"
        export PATH="${GCC_ARM_COMPILER_PATH}:${GCC_ARM64_COMPILER_PATH}:${CLANG_COMPILER_PATH}:${PATH}"
    else
        export PATH="${CLANG_COMPILER_PATH}:${PATH}"
    fi
}

function buildDefconfig() {
    local TOP=$(getTop)
    checkKernelDirectory
    displayDeviceInfo $DEVICE
    cd $TOP/$KERNEL_DIR
    local MAKE_PARAMS="ARCH=arm64 CC=clang CLANG_TRIPLE=aarch64-linux-gnu-"
    if [[ $TARGET_USES_GCC ]]; then
        local MAKE_GCC_PARAMS="CROSS_COMPILE=aarch64-linux-android- \
                               CROSS_COMPILE_ARM32=arm-linux-androideabi-"
    fi
    if [[ $TARGET_USES_GCC ]]; then
        make -j$(nproc --all) O=$TOP/out $MAKE_PARAMS $MAKE_GCC_PARAMS $KERNEL_DEFCONFIG
    else
        make -j$(nproc --all) O=$TOP/out $MAKE_PARAMS $KERNEL_DEFCONFIG
    fi
    cd $TOP
}

function buildKernelImage() {
    local TOP=$(getTop)
    checkKernelDirectory
    displayDeviceInfo $DEVICE
    cd $TOP/$KERNEL_DIR
    local MAKE_PARAMS="ARCH=arm64 CC=clang CLANG_TRIPLE=aarch64-linux-gnu-"
    if [[ $TARGET_USES_GCC ]]; then
        local MAKE_GCC_PARAMS="CROSS_COMPILE=aarch64-linux-android- \
                               CROSS_COMPILE_ARM32=arm-linux-androideabi-"
    fi
    if [[ $TARGET_USES_GCC ]]; then
        make -j$(nproc --all) O=$TOP/out $MAKE_PARAMS $MAKE_GCC_PARAMS
    else
        make -j$(nproc --all) O=$TOP/out $MAKE_PARAMS
    fi
    cd $TOP
}

function buildKernel() {
    buildDefconfig
    buildKernelImage
}

function checkKernelDirectory() {
    local TOP=$(getTop)
    if [ -d $TOP/$KERNEL_DIR ]; then
        echo "Kernel directory found at $KERNEL_DIR"
    else
        echo "warning: Kernel directory not found"
        echo "warning: Trying to clone the repository"
        source $TOP/build/src/repository.sh $TARGET_DEVICE_CODENAME $KERNEL_DIR
        return
    fi
}
