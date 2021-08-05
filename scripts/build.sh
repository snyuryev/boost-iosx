#!/bin/bash
set -e
################## SETUP BEGIN
HOST_ARC=$( uname -m )
XCODE_ROOT=$( xcode-select -print-path )
BOOST_VER=1.76.0
################## SETUP END
DEVSYSROOT=$XCODE_ROOT/Platforms/iPhoneOS.platform/Developer
SIMSYSROOT=$XCODE_ROOT/Platforms/iPhoneSimulator.platform/Developer
MACSYSROOT=$XCODE_ROOT/Platforms/MacOSX.platform/Developer

BOOST_NAME=boost_${BOOST_VER//./_}
BUILD_DIR="$( cd "$( dirname "./" )" >/dev/null 2>&1 && pwd )"
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

if [ ! -f "$BUILD_DIR/frameworks.built" ]; then

if [[ $HOST_ARC == arm* ]]; then
	BOOST_ARC=arm
elif [[ $HOST_ARC == x86* ]]; then
	BOOST_ARC=x86
else
	BOOST_ARC=unknown
fi

if [ ! -f $BOOST_NAME.tar.bz2 ]; then
	curl -L https://boostorg.jfrog.io/artifactory/main/release/$BOOST_VER/source/$BOOST_NAME.tar.bz2 -o $BOOST_NAME.tar.bz2
fi
if [ ! -d boost ]; then
	echo "extracting $BOOST_NAME.tar.bz2 ..."
	tar -xf $BOOST_NAME.tar.bz2
	mv $BOOST_NAME boost
fi

if [ ! -f boost/b2 ]; then
	pushd boost
	./bootstrap.sh
	popd
fi

pushd boost

echo patching boost...

if [ ! -f tools/build/src/tools/gcc.jam.orig ]; then
	cp -f tools/build/src/tools/gcc.jam tools/build/src/tools/gcc.jam.orig
else
	cp -f tools/build/src/tools/gcc.jam.orig tools/build/src/tools/gcc.jam
fi
patch tools/build/src/tools/gcc.jam $SCRIPT_DIR/gcc.jam.patch

if [ ! -f tools/build/src/tools/features/instruction-set-feature.jam.orig ]; then
	cp -f tools/build/src/tools/features/instruction-set-feature.jam tools/build/src/tools/features/instruction-set-feature.jam.orig
else
	cp -f tools/build/src/tools/features/instruction-set-feature.jam.orig tools/build/src/tools/features/instruction-set-feature.jam
fi
patch tools/build/src/tools/features/instruction-set-feature.jam $SCRIPT_DIR/instruction-set-feature.jam.patch

if false; then
if [ ! -f tools/build/src/build/configure.jam.orig ]; then
	cp -f tools/build/src/build/configure.jam tools/build/src/build/configure.jam.orig
else
	cp -f tools/build/src/build/configure.jam.orig tools/build/src/build/configure.jam
fi
patch tools/build/src/build/configure.jam $SCRIPT_DIR/configure.jam.patch
fi

LIBS_TO_BUILD="--with-filesystem --with-system"

B2_BUILD_OPTIONS="release link=static runtime-link=shared define=BOOST_SPIRIT_THREADSAFE"

if true; then
if [ -d bin.v2 ]; then
	rm -rf bin.v2
fi
if [ -d stage ]; then
	rm -rf stage
fi
fi

if true; then
if [[ -f tools/build/src/user-config.jam ]]; then
	rm -f tools/build/src/user-config.jam
fi
./b2 -j8 --stagedir=stage/macosx cxxflags="-std=c++17" -sICU_PATH="$ICU_PATH" toolset=darwin address-model=64 architecture=$BOOST_ARC $B2_BUILD_OPTIONS $LIBS_TO_BUILD
rm -rf bin.v2
fi

if true; then
if [[ -f tools/build/src/user-config.jam ]]; then
	rm -f tools/build/src/user-config.jam
fi
cat >> tools/build/src/user-config.jam <<EOF
using darwin : catalyst : clang++ -arch $HOST_ARC --target=$BOOST_ARC-apple-ios13-macabi -isysroot $MACSYSROOT/SDKs/MacOSX.sdk -I$MACSYSROOT/SDKs/MacOSX.sdk/System/iOSSupport/usr/include/ -isystem $MACSYSROOT/SDKs/MacOSX.sdk/System/iOSSupport/usr/include -iframework $MACSYSROOT/SDKs/MacOSX.sdk/System/iOSSupport/System/Library/Frameworks
: <striper> <root>$MACSYSROOT
: <architecture>$BOOST_ARC
;
EOF
./b2 -j8 --stagedir=stage/catalyst cxxflags="-std=c++17" -sICU_PATH="$ICU_PATH" toolset=darwin-catalyst address-model=64 architecture=$BOOST_ARC $B2_BUILD_OPTIONS $LIBS_TO_BUILD
rm -rf bin.v2
fi

if true; then
if [[ -f tools/build/src/user-config.jam ]]; then
	rm -f tools/build/src/user-config.jam
fi
cat >> tools/build/src/user-config.jam <<EOF
using darwin : ios : clang++ -arch arm64 -fembed-bitcode-marker -isysroot $DEVSYSROOT/SDKs/iPhoneOS.sdk
: <striper> <root>$DEVSYSROOT 
: <architecture>arm <target-os>iphone 
;
EOF
./b2 -j8 --stagedir=stage/ios cxxflags="-std=c++17" -sICU_PATH="$ICU_PATH" toolset=darwin-ios address-model=64 instruction-set=arm64 architecture=arm binary-format=mach-o abi=aapcs target-os=iphone define=_LITTLE_ENDIAN define=BOOST_TEST_NO_MAIN $B2_BUILD_OPTIONS $LIBS_TO_BUILD
rm -rf bin.v2
fi

if true; then
if [[ -f tools/build/src/user-config.jam ]]; then
	rm -f tools/build/src/user-config.jam
fi
cat >> tools/build/src/user-config.jam <<EOF
using darwin : iossim : clang++ -arch $HOST_ARC -fembed-bitcode-marker -isysroot $SIMSYSROOT/SDKs/iPhoneSimulator.sdk
: <striper> <root>$SIMSYSROOT 
: <architecture>$BOOST_ARC <target-os>iphone 
;
EOF
./b2 -j8 --stagedir=stage/iossim cxxflags="-std=c++17" -sICU_PATH="$ICU_PATH" toolset=darwin-iossim address-model=64 architecture=$BOOST_ARC target-os=iphone define=BOOST_TEST_NO_MAIN $B2_BUILD_OPTIONS $LIBS_TO_BUILD
rm -rf bin.v2
fi

echo installing boost...
if [ -d "$BUILD_DIR/frameworks" ]; then
    rm -rf "$BUILD_DIR/frameworks"
fi

mkdir "$BUILD_DIR/frameworks"

build_xcframework()
{
	xcodebuild -create-xcframework -library stage/macosx/lib/lib$1.a -library stage/catalyst/lib/lib$1.a -library stage/ios/lib/lib$1.a -library stage/iossim/lib/lib$1.a -output "$BUILD_DIR/frameworks/$1.xcframework"
}

if true; then
build_xcframework boost_filesystem
build_xcframework boost_system

mkdir "$BUILD_DIR/frameworks/Headers"
cp -R boost "$BUILD_DIR/frameworks/Headers/"
#mv boost "$BUILD_DIR/frameworks/Headers/"
touch "$BUILD_DIR/frameworks.built"
fi

rm -rf "$BUILD_DIR/boost"

popd

fi
