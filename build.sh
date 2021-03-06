#! /bin/sh

# Define Path
MainPath=$(pwd)
GCC64_Path=$MainPath/../GCC64
GCC_Path=$MainPath/../GCC
gcc64_Path=$MainPath/../gcc64
gcc_Path=$MainPath/../gcc
Clang_Path=$MainPath/../clang
DTC_Path=$MainPath/../DragonTC
LOG=$MainPath/error.log
USER="PIKACHU"
HOST="PIKACHU"

# Message
CAP1="
# For Redmi Note 8 Pro (begonia) #
Build By : $USER
Host : $HOST
Base Firmware : Q-OSS
Compiler Type : $Compiler
Build Success in : $((DIFF / 60)) minute(s) and $((DIFF % 60)) second(s)
"

CAP2="
Build Fail in : $((DIFF / 60)) minute(s) and $((DIFF % 60)) second(s)
"

# Make zip
MakeZip() {
    Any=$MainPath/../AnyKernel3
    if [ ! -d $Any ];then
	    git clone https://github.com/Atanu81237/Anykernel3 -b master $Any
    else
        cd $Any
        git reset --hard
        git fetch origin master
        git checkout master
        git reset --hard origin/master
    fi
    cd $Any
    cp -af $MainPath/out/arch/arm64/boot/Image.gz-dtb $Any
    cp -af anykernel-real.sh anykernel.sh
    sed -i "s/kernel.string=.*/kernel.string=$KERNEL_NAME-$HeadCommit by ${USER}/g" anykernel.sh
    zip -r $MainPath/"[${Compiler}][Q-OSS][$ZIP_KERNEL_VERSION]-$KERNEL_NAME-$TIME.zip" * -x .git .git/**\* ./.git ./anykernel-real.sh ./.gitignore ./LICENSE ./README.md ./*.zip
    cd $MainPath
}

# Clone Compiler
CloneGCC() {
    if [ ! -d $GCC64_Path ];then
	    git clone --depth=1 https://github.com/mvaisakh/gcc-arm64 $GCC64_Path
    fi
    if [ ! -d $GCC_Path ];then
	    git clone --depth=1 https://github.com/mvaisakh/gcc-arm $GCC_Path
    fi
}

CloneCLANG() {
    if [ ! -d $Clang_Path ];then
	    git clone --depth=1 https://github.com/kdrag0n/proton-clang $Clang_Path
    fi
}

CloneDTC() {
    if [ ! -d $DTC_Path ];then
	    git clone --depth=1 https://github.com/NusantaraDevs/DragonTC $DTC_Path
    fi
    if [ ! -d $gcc64_Path ];then
	    git clone --depth=1 https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/aarch64/aarch64-linux-android-4.9 $gcc64_Path
    fi
    if [ ! -d $gcc_Path ];then
	    git clone --depth=1 https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/arm/arm-linux-androideabi-4.9 $gcc_Path
    fi
}

# Define Config
HeadCommit="$(git log --pretty=format:'%h' -1)"
export KBUILD_BUILD_USER="$USER"
export KBUILD_BUILD_HOST="$HOST"
Defconfig="begonia_user_defconfig"
KERNEL_NAME=$(cat "$MainPath/arch/arm64/configs/$Defconfig" | grep "CONFIG_LOCALVERSION=" | sed 's/CONFIG_LOCALVERSION="-*//g' | sed 's/"*//g' )
ZIP_KERNEL_VERSION="4.14.$(cat "$MainPath/Makefile" | grep "SUBLEVEL =" | sed 's/SUBLEVEL = *//g')$(cat "$(pwd)/Makefile" | grep "EXTRAVERSION =" | sed 's/EXTRAVERSION = *//g')"

# Building
BuildGCC() {
    Compiler=GCC
    rm -rf out $LOG
    exec 2> >(tee -a error.log >&2)
    TIME=$(date +"%m%d%H%M")
    BUILD_START=$(date +"%s")
    make -j$(nproc --all) O=out ARCH=arm64 ${Defconfig}
    make -j$(nproc --all) ARCH=arm64 SUBARCH=arm64 O=out \
                          PATH=$GCC64_Path/bin:$GCC_Path/bin:/usr/bin:${PATH} \
                          AR=aarch64-elf-ar \
                          LD=ld.lld \
                          OBJDUMP=aarch64-elf-objdump \
                          CROSS_COMPILE=aarch64-elf- \
                          CROSS_COMPILE_ARM32=arm-eabi-
}

BuildCLANG() {
    Compiler=Proton
    rm -rf out $LOG
    exec 2> >(tee -a error.log >&2)
    TIME=$(date +"%m%d%H%M")
    BUILD_START=$(date +"%s")
    make -j$(nproc --all) O=out ARCH=arm64 ${Defconfig}
    make -j$(nproc --all) ARCH=arm64 SUBARCH=arm64 O=out \
                          PATH=$Clang_Path/bin:/usr/bin:${PATH} \
                          LD_LIBRARY_PATH=$Clang_Path/lib:${LD_LIBRARY_PATH} \
                          CC=clang \
                          AS=llvm-as \
                          NM=llvm-nm \
                          OBJCOPY=llvm-objcopy \
                          OBJDUMP=llvm-objdump \
                          STRIP=llvm-strip \
                          LD=ld.lld \
                          CROSS_COMPILE=aarch64-linux-gnu- \
                          CROSS_COMPILE_ARM32=arm-linux-gnueabi-
}

BuildDTC() {
    Compiler=DragonTC
    rm -rf out $LOG
    exec 2> >(tee -a error.log >&2)
    TIME=$(date +"%m%d%H%M")
    BUILD_START=$(date +"%s")
    make -j$(nproc --all) O=out ARCH=arm64 ${Defconfig}
    make -j$(nproc --all) ARCH=arm64 SUBARCH=arm64 O=out \
                          PATH=$DTC_Path/bin:$gcc64_Path/bin:$gcc_Path/bin:/usr/bin:${PATH} \
                          LD_LIBRARY_PATH=$DTC_Path/lib64:${LD_LIBRARY_PATH} \
                          CC=clang \
                          LD=ld.lld \
                          CROSS_COMPILE=aarch64-linux-android- \
                          CROSS_COMPILE_ARM32=arm-linux-androideabi- \
                          CLANG_TRIPLE=aarch64-linux-gnu-
}

# End Success or Fail
End() {
    if [ -e $MainPath/out/arch/arm64/boot/Image.gz-dtb ];then
	    BUILD_END=$(date +"%s")
	    DIFF=$((BUILD_END - BUILD_START))
	    MakeZip
	    echo "Build Success in : $((DIFF / 60)) minute(s) and $((DIFF % 60)) second(s)"
    else
	    BUILD_END=$(date +"%s")
	    DIFF=$((BUILD_END - BUILD_START))
	    echo "Build Fail in : $((DIFF / 60)) minute(s) and $((DIFF % 60)) second(s)"
    fi
}

# Compiler Choices
DTC() {
    CloneDTC
    BuildDTC
    End
}

CLANG() {
    CloneCLANG
    BuildCLANG
    End
}

GCC() {
    CloneGCC
    BuildGCC
    End
}
