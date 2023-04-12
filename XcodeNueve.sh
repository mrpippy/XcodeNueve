#!/bin/sh

# XcodeNueve: Modify Xcode 9.4.1's toolchain to run on 10.15+

# If run without arguments, will prompt for path to Xcode and signing identity to use
# To run non-interactively, pass Xcode path as 1st argument and signing identity 2nd.

check_file_exists() {
    if [ ! -f "$1" ]; then
        echo "$0: $1 missing"
        exit 1
    fi
}

check_sha256() {
    if [ `openssl dgst -sha256 "$1" | sed 's/SHA256(.*)= //'` != "$2" ]; then
        echo "$0: $1 has an unexpected checksum. Is this an unmodified copy of Xcode 9.4.1?"
        exit 1
    fi
}

XCODE="/Applications/Xcode9.app"
IDENTITY="XcodeSigner"

if [ "$#" -eq 0 ]; then
    # Running interactively, prompt for Xcode path and signing identity
    echo "XcodeNueve 🛠 9️⃣ : patch Xcode 9.4.1 to run on 10.15+\n"

    if [ -f "$PWD/Xcode9.app/Contents/Info.plist" ]; then
        XCODE="$PWD/Xcode9.app"
    fi

    read -p "Path to Xcode 9.4.1 [$XCODE]: " TMPINPUT
    if [ ! -z "$TMPINPUT" ]; then
        XCODE="$TMPINPUT"
    fi

    read -p "Signing identity to use [$IDENTITY]: " TMPINPUT
    if [ ! -z "$TMPINPUT" ]; then
        IDENTITY="$TMPINPUT"
    fi
elif [ "$#" -eq 2 ]; then
    # Two arguments given: Xcode path and signing identity
    XCODE="$1"
    IDENTITY="$2"
else
    echo "usage: $0 <path to Xcode 9.4.1> <signing identity to use>"
    exit 1
fi

check_file_exists "$XCODE/Contents/SharedFrameworks/DVTKit.framework/Versions/A/DVTKit"
check_file_exists "$XCODE/Contents/PlugIns/IDEInterfaceBuilderKit.framework/Versions/A/IDEInterfaceBuilderKit"

check_sha256 "$XCODE/Contents/SharedFrameworks/DVTKit.framework/Versions/A/DVTKit" \
             "06db61b1de8b7242de20248a7a9a829edcec43ee77190d02a9bda57192b45251"

check_sha256 "$XCODE/Contents/PlugIns/IDEInterfaceBuilderKit.framework/Versions/A/IDEInterfaceBuilderKit" \
             "c8d45ddd9e1334554cc57ee9bb1bc437920f599710aa81b1cbe144fa7ee59740"

# Do a test codesign to check that the given identity exists before we start modifying files
codesign --dryrun -f -s $IDENTITY "$XCODE/Contents/Developer/usr/bin/xcodebuild"

# Change reference in DVTKit from _OBJC_IVAR_$_NSFont._fFlags to _OBJC_IVAR_$_NSCell._cFlags
echo "4E534365 6C6C2E5F 63466C61 6773" |  xxd -r -p -s 0x478967 - "$XCODE/Contents/SharedFrameworks/DVTKit.framework/Versions/A/DVTKit"

# Change reference in DVTKit from _OBJC_IVAR_$_NSUndoTextOperation._layoutManager to _OBJC_IVAR_$_NSUndoTextOperation._affectedRange
echo "61666665 63746564 52616E67 65" | xxd -r -p -s 0x478ab6 - "$XCODE/Contents/SharedFrameworks/DVTKit.framework/Versions/A/DVTKit"

# Change references in IDEInterfaceBuilderKit from _OBJC_IVAR_$_NSFont._fFlags to _OBJC_IVAR_$_NSCell._cFlags
echo "4E534365 6C6C2E5F 63466C61 6773" |  xxd -r -p -s 0x7bed6d - "$XCODE/Contents/PlugIns/IDEInterfaceBuilderKit.framework/Versions/A/IDEInterfaceBuilderKit"
echo "4E534365 6C6C2E5F 63466C61 6773" |  xxd -r -p -s 0x899801 - "$XCODE/Contents/PlugIns/IDEInterfaceBuilderKit.framework/Versions/A/IDEInterfaceBuilderKit"

# Change references from _OBJC_IVAR_$_NSTableView._reserved to _OBJC_IVAR_$_NSTableView._delegate
echo "64656C65 67617465" |  xxd -r -p -s 0x7bee08 - "$XCODE/Contents/PlugIns/IDEInterfaceBuilderKit.framework/Versions/A/IDEInterfaceBuilderKit"
echo "64656C65 67617465" |  xxd -r -p -s 0x899894 - "$XCODE/Contents/PlugIns/IDEInterfaceBuilderKit.framework/Versions/A/IDEInterfaceBuilderKit"

# Fix -[DVTSearchFieldCell willDrawVibrantly] method of DVTKit which crashes the whole UI
echo "66909066 90906690 90" |  xxd -r -p -s 0xB63AE - "$XCODE/Contents/SharedFrameworks/DVTKit.framework/Versions/A/DVTKit"

# Fix build/clean/test/etc square alerts in -[DVTBezelAlertPanel effectViewForBezel] (uses undocumented & outdated method)
echo "66906690 669090" |  xxd -r -p -s 0xD0E40 - "$XCODE/Contents/SharedFrameworks/DVTKit.framework/Versions/A/DVTKit"
echo "66909066 9090" |  xxd -r -p -s 0xD0EA1 - "$XCODE/Contents/SharedFrameworks/DVTKit.framework/Versions/A/DVTKit"

# Copy libtool from the (presumably newer) installed Xcode.app, to fix crashes on Monterey
if [ -f "`xcode-select -p`/Toolchains/XcodeDefault.xctoolchain/usr/bin/libtool" ]; then
    cp -p "`xcode-select -p`/Toolchains/XcodeDefault.xctoolchain/usr/bin/libtool" "$XCODE/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/libtool"
else
    if [ -f "/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/libtool" ]; then
        cp -p "/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/libtool" "$XCODE/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/libtool"
    else
        echo "$0: Unable to find another Xcode to copy libtool from. Beware, Xcode 9.4.1's libtool sometimes crashes on Monterey."
    fi
fi

echo "Downloading Python 2.7.18..." 
echo "Note: It's NOT being installed globally, only in Xcode 9 folder" 

# Download Python 2.7.18 installer to use a part of it for making a working dependency
PY_TMP_DIR="$TMPDIR/python2.7-installer"
XCODE_PY_DIR="$XCODE/Contents/SharedFrameworks/Python.framework"
mkdir $PY_TMP_DIR
curl -o "$PY_TMP_DIR/python2.pkg" "https://www.python.org/ftp/python/2.7.18/python-2.7.18-macosx10.9.pkg"
xar -C $PY_TMP_DIR -xf "$PY_TMP_DIR/python2.pkg"
mkdir $XCODE_PY_DIR
tar xvf "$PY_TMP_DIR/Python_Framework.pkg/Payload" -C $XCODE_PY_DIR &> /dev/null
rm -rf $PY_TMP_DIR

# Replace Python 2.7 system dependency with a local one
echo "40727061 74682F50 7974686F 6E2E6672 616D6577 6F726B2F 2E2E2F50 7974686F 6E2E6672 616D6577 6F726B2F 56657273 696F6E73 2F322E37 2F507974 686F6E" |  xxd -r -p -s 0x9e8 - "$XCODE/Contents/SharedFrameworks/LLDB.framework/Versions/A/LLDB"

codesign -f -s $IDENTITY "$XCODE/Contents/SharedFrameworks/DVTKit.framework"
codesign -f -s $IDENTITY "$XCODE"
codesign -f -s $IDENTITY "$XCODE/Contents/SharedFrameworks/DVTDocumentation.framework"
codesign -f -s $IDENTITY "$XCODE/Contents/Frameworks/IDEFoundation.framework"
codesign -f -s $IDENTITY "$XCODE/Contents/Developer/usr/bin/xcodebuild"
codesign -f -s $IDENTITY "$XCODE/Contents/SharedFrameworks/LLDB.framework"
