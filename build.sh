#!/bin/bash

#Clang 
HOME_DIR=$(pwd)
echo "Cloning Clang"
git clone -b lineage-20.0 https://github.com/LineageOS/android_prebuilts_clang_kernel_linux-x86_clang-r416183b.git --depth=1
#GCC(using aarch64)
echo "Cloning GCC"
git clone -b lineage-19.1 https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_aarch64_aarch64-linux-android-4.9.git --depth=1
#Kernel Source
echo "Cloning Kernel_realme_trinket"
git clone -b Chisato git@github.com:mahisataruna/kernel_realme_trinket.git --depth=1
#Build Info
BUILD_VERSION=$(awk 'NR==1 {print $2}' kernel_realme_trinket/release)
BUILD_DEVICE=$(awk 'NR==2 {print $2}' kernel_realme_trinket/release)
BUILD_VARIANT=$(awk 'NR==3 {print $2}' kernel_realme_trinket/release)
BUILD_DISPLAY=$(awk 'NR==4 {print $2}' kernel_realme_trinket/release)
# Clone AnyKernel
echo "Cloning AnyKernel3"
git clone --depth=1 -b ${BUILD_DEVICE} git@github.com:mahisataruna/AnyKernel3.git
echo "- Successfully cloned all dependencies!"

# Setup Build Env.
cd kernel_realme_trinket
KERNEL_DIR=$(pwd)
BUILD_START=$(date +"%s")
BUILD_DATE=$(date -u +"%F")
WORKING_BRANCH="$(git rev-parse --abbrev-ref HEAD)"
KERNEL_DEFCONFIG=RMX1911-${BUILD_DEVICE}_defconfig
KERNEL_NAME=Kreapic-${BUILD_VERSION}-${BUILD_VARIANT}-${BUILD_DISPLAY}Hz
KERNEL_IMAGE="${KERNEL_DIR}/out/arch/arm64/boot/Image.gz-dtb"
KERNEL_ZIP=${KERNEL_NAME}-${BUILD_DEVICE}.zip
PATH="${HOME_DIR}/prebuilt/clang/bin:${HOME_DIR}/prebuilt/aarch64/bin:${HOME_DIR}/prebuilt/arm/bin:${PATH}"
export KBUILD_COMPILER_STRING="$(${HOME_DIR}/prebuilt/clang/bin/clang --version | head -n 1 | perl -pe 's/\(http.*?\)//gs' | sed -e 's/  */ /g')"
export ARCH=arm64
export KBUILD_BUILD_USER=Kreapic
export KBUILD_BUILD_HOST=Trinket
# Write Kernel info to defconfig
echo "- Applying Delta Branding to ${KERNEL_DEFCONFIG}"
sed -i "/CONFIG_LOCALVERSION=/c\CONFIG_LOCALVERSION=\"-${KERNEL_NAME}\"" arch/arm64/configs/${KERNEL_DEFCONFIG}

# Compile Kernel
function compile() {
    echo "- Build started!"
    sendBuildStartAlert
    make -j$(nproc) O=out ARCH=arm64 delta-beryllium_defconfig
    make -j$(nproc) O=out \
                    ARCH=arm64 \
                    CC=clang \
                    CLANG_TRIPLE=aarch64-linux-gnu- \
                    CROSS_COMPILE=aarch64-linux-android- \
                    CROSS_COMPILE_ARM32=arm-linux-androideabi- | tee build.log
    if ! [ -a "$KERNEL_IMAGE" ]; then
        BUILD_END=$(date +"%s")
        TOTAL_TIME=$(($BUILD_END - $BUILD_START))
        echo "- Oops! Error(s) in build. Halting CI Instance & Exiting.."
        echo "- Wasted $(($TOTAL_TIME / 60))min $(($TOTAL_TIME % 60))sec. of precious CI build minutes!"
        sendBuildErrorAlert
        exit 1
    fi
    BUILD_END=$(date +"%s")
    TOTAL_TIME=$(($BUILD_END - $BUILD_START))
    sendBuildSuccessAlert
    echo ""
    echo "- Build Completed!"
}
# Zipping
function zipIt() {
    echo ""
    echo "- Copying Image.gz-dtb to anykernel dir!"
    cp -f out/arch/arm64/boot/Image.gz-dtb ../anykernel
    sed -i "1s/.*/${BUILD_VERSION} (${BUILD_VARIANT} ${BUILD_DISPLAY}Hz) | ${BUILD_DATE}/" ${HOME_DIR}/anykernel/version
    echo ""
    echo "- Done Copying Image.gz-dtb!"
    echo ""
    echo "- Zip it!"
    cd ../anykernel || exit 1
    zip -r9 ${KERNEL_ZIP} * -x .git README.md zip.sh *placeholder
    echo "- Done Zipping!"
    SHA1=($(sha1sum ${KERNEL_ZIP}))
    ZIP_SIZE=($(du -h ${KERNEL_ZIP} | awk '{print $1}'))
    cd ..
}
compile
zipIt
sendBuildDetails
sendKernelZip


