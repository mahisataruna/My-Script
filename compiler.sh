#!build bash

export KBUILD_BUILD_USER=Algorithm
export KBUILD_BUILD_HOST=Trinket
#compile function
function compile(){
make O=out ARCH=arm64 RMX1911-stock_defconfig

PATH="<path to clang folder>/bin:<path to gcc folder>/bin:${PATH}" \
make -j$(nproc --all) O=out \
                      ARCH=arm64 \
                      CC=clang \
                      CLANG_TRIPLE=aarch64-linux-gnu- \
                      CROSS_COMPILE=aarch64-linux-android-
}
compile
