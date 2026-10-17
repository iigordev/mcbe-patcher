#!/bin/bash

echo "Minecraft Bedrock Patcher"
echo "Warning: you only use this ONCE per IPA!"
echo ""

read -p "Paste/drag your .ipa file path here: " ipa_path
ipa_path=$(echo "$ipa_path" | sed "s/^['\"]//;s/['\"]$//")

if [ ! -f "$ipa_path" ]; then
    echo "Error: File not found!"
    exit 1
fi

read -p "Do you want retina resolution? (this will make the game look sharp, but it will damage your fps if you're using vibrant visuals) [y/n]: " retina_choice

echo "Creating patched IPA..."

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
libs_dir="$script_dir/libs"
bin_dir="$script_dir/bin"

work_dir="$script_dir/patched_workspace"
rm -rf "$work_dir"
mkdir -p "$work_dir"

copied_ipa="$work_dir/app.ipa"
cp "$ipa_path" "$copied_ipa"

zipped_path="$work_dir/app.zip"
mv "$copied_ipa" "$zipped_path"

unzip -q "$zipped_path" -d "$work_dir"
rm "$zipped_path"

app_path="$work_dir/Payload/minecraftpe.app"

if [ ! -d "$app_path" ]; then
    echo "Error: Payload/minecraftpe.app not found in IPA structure!"
    exit 1
fi

plist_path="$app_path/Info.plist"
if [ -f "$plist_path" ]; then
    /usr/libexec/PlistBuddy -c "Set :UISupportsTrueScreenSizeOnMac bool true" "$plist_path" 2>/dev/null || \
    /usr/libexec/PlistBuddy -c "Add :UISupportsTrueScreenSizeOnMac bool true" "$plist_path"
fi

frameworks_path="$app_path/Frameworks"
mkdir -p "$frameworks_path"

if [[ "$retina_choice" =~ ^[Yy]$ ]]; then
    dylib_name="libmcbe-retina.dylib"
else
    dylib_name="libmcbe-noretina.dylib"
fi

if [ -f "$libs_dir/$dylib_name" ]; then
    cp "$libs_dir/$dylib_name" "$frameworks_path/"
else
    echo "Error: $dylib_name not found in $libs_dir!"
    exit 1
fi

executable_path="$app_path/minecraftpe"
inject_tool="$bin_dir/inject"

if [ -f "$inject_tool" ]; then
    chmod +x "$inject_tool"
    "$inject_tool" --weak --inplace "@executable_path/Frameworks/$dylib_name" "$executable_path"
else
    echo "Error: 'inject' binary not found in $bin_dir!"
    exit 1
fi

echo "Re-signing app bundle..."
codesign --force --deep -s - "$app_path"

ipa_name=$(basename "$ipa_path")
base_name="${ipa_name%.*}"

cd "$work_dir"
zip -qr "${base_name}_patched.ipa" Payload
mv "${base_name}_patched.ipa" "$(dirname "$ipa_path")/${base_name}_patched.ipa"

cd - > /dev/null
rm -rf "$work_dir"

echo "Completed!"