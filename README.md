# XcodeNueve 🛠 9️⃣ 

A hack allowing the use of Xcode 9's toolchain on macOS Catalina, Big Sur, and Monterey.

## Why?

Xcode 9.4.1 and the macOS 10.13 SDK are the last versions capable of building 32-bit Intel (`i386`) binaries.

Due to internal frameworks that reference private AppKit instance variables (removed in macOS Catalina), Xcode 9 and its included toolchain fail to run on any macOS version past Mojave.

For projects which need to build i386 binaries to support macOS 10.14 and earlier (like [Wine](https://www.winehq.org)), this requires keeping around a 10.14 build machine, which is undesirable for a number of reasons (no more security updates, requires older hardware, can't also run latest Xcode, etc.)

Xcode 9 also may be useful for building old Swift projects.

## What doesn't work?

Xcode.app itself does open, but crashes when trying to open a project (I think trying to access more private AppKit variables). This may be fixable, but isn't a priority for me.

## Tell me how!

1. Download Xcode 9.4.1 from [Apple Developer](https://developer.apple.com/download/all/) and extract it. I recommend renaming it to `Xcode9.app` and moving to `/Applications`.
2. Create a code signing signature (XVim instructions):
   1. Open Keychain Access.app and select `login` in the left pane.
   2. In the menu bar, select Keychain Access -> Certificate Assistant -> Create a Certificate...
   3. For the Name I recommend "XcodeSigner", for Identity Type select "Self Signed Root", and for Certificate Type choose "Code Signing". Then click "Create", and continue through the warning.
   4. You should now have a self-signed code signing certificate in the "login" keychain.
4. Modify DVTKit.framework/Contents/MacOS/DVTKit:
   1. Verify DVTKit is unmodified:
   ```
   % openssl dgst -md5 DVTKit
   MD5(DVTKit)= c14a719f16794586759fb10bb6543faf
   ```
   2. Change reference in DVTKit from `_OBJC_IVAR_$_NSFont._fFlags` to `_OBJC_IVAR_$_NSCell._cFlags`:
   ```
   % echo "4E534365 6C6C2E5F 63466C61 6773" |  xxd -r -p -s 0x478967 - DVTKit
   ```
   3. Change reference in DVTKit from `_OBJC_IVAR_$_NSUndoTextOperation._layoutManager` to `_OBJC_IVAR_$_NSUndoTextOperation._affectedRange`:
   ```
   % echo "61666665 63746564 52616E67 65" | xxd -r -p -s 0x478ab6 - DVTKit
   ```
6. `codesign -f -s XcodeSigner /Applications/Xcode9.app/Contents/SharedFrameworks/DVTKit.framework`
7. `codesign -f -s XcodeSigner /Applications/Xcode9.app`
8. `codesign -f -s XcodeSigner /Applications/Xcode9.app/Contents/SharedFrameworks/DVTDocumentation.framework`
9. `codesign -f -s XcodeSigner /Applications/Xcode9.app/Contents/Frameworks/IDEFoundation.framework`
10. `codesign -f -s XcodeSigner /Applications/Xcode9.app/Contents/Developer/usr/bin/xcodebuild`
11. (for launching Xcode.app itself)
12. Modify `Contents/PlugIns/IDEInterfaceBuilderKit.framework/Versions/A/IDEInterfaceBuilderKit`:
    1. Change references from `_OBJC_IVAR_$_NSFont._fFlags` to `_OBJC_IVAR_$_NSCell._cFlags`:
    ```
    % echo "4E534365 6C6C2E5F 63466C61 6773" |  xxd -r -p -s 0x7bed6d - IDEInterfaceBuilderKit
    % echo "4E534365 6C6C2E5F 63466C61 6773" |  xxd -r -p -s 0x899801 - IDEInterfaceBuilderKit
    ```
    2. Change references from `_OBJC_IVAR_$_NSTableView._reserved` to `_OBJC_IVAR_$_NSTableView._delegate`
    ```
    % echo "64656C65 67617465" |  xxd -r -p -s 0x7bee08 - IDEInterfaceBuilderKit
    % echo "64656C65 67617465" |  xxd -r -p -s 0x899894 - IDEInterfaceBuilderKit
    ```

## How do I use it?

* You'll need to set `DEVELOPER_DIR=/Applications/Xcode9.app` and `SDKROOT=/Applications/Xcode9.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX10.13.sdk`, then run `clang`/`gcc`/`xcrun`/`xcodebuild`/whatever.
* The `env` command can be used to run this as a single command, like `env DEVELOPER_DIR=/Applications/Xcode9.app SDKROOT=/Applications/Xcode9.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX10.13.sdk clang -arch i386 ...`
* Also, on Apple Silicon, you will need to explicitly run the command emulated under Rosetta, using `arch -x86_64`. I usually find it easier to just run the entire shell emulated: `arch -x86_64 zsh`.
* Building i386 binaries is considered cross-compiling, and may need additional options passed to a `configure` script/build system.
* For example, here's a typical invocation of `configure` on Apple Silicon: `arch -x86_64 ./configure --host=i386-apple-darwin CC="env DEVELOPER_DIR=/Applications/Xcode9.app SDKROOT=/Applications/Xcode9.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX10.13.sdk clang -arch i386"`

## Details

Here's the error when trying to run unmodified Xcode 9 (either the IDE itself or its command-line tools) under macOS Catalina and later:

```
% DEVELOPER_DIR=/Applications/Xcode9.app xcrun clang -v
dyld[83886]: Symbol not found: _OBJC_IVAR_$_NSFont._fFlags
  Referenced from: /Applications/Xcode9.app/Contents/SharedFrameworks/DVTKit.framework/Versions/A/DVTKit
  Expected in: /System/Library/Frameworks/AppKit.framework/Versions/C/AppKit
```
