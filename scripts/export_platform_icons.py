#!/usr/bin/env python3
"""Export app icons at all required sizes for iOS and Android.

This script generates platform-specific icon files from the source 1024x1024 icon.
It can be used as a fallback when `dart run flutter_launcher_icons` is unavailable,
or to pre-generate icons for the project.

iOS sizes: 1024x1024 (App Store), plus @1x/@2x/@3x for various use cases
Android sizes: mdpi (48), hdpi (72), xhdpi (96), xxhdpi (144), xxxhdpi (192)
Android adaptive: mdpi (108), hdpi (162), xhdpi (216), xxhdpi (324), xxxhdpi (432)
"""

import os
import json
from PIL import Image

APP_DIR = "/p/gocalgo/src/app"
ICON_SRC = os.path.join(APP_DIR, "assets/icons/app_icon.png")
ADAPTIVE_FG_SRC = os.path.join(APP_DIR, "assets/icons/app_icon_adaptive_foreground.png")
ADAPTIVE_BG_SRC = os.path.join(APP_DIR, "assets/icons/app_icon_adaptive_background.png")

# Android standard icon sizes (launcher icon)
ANDROID_SIZES = {
    "mipmap-mdpi": 48,
    "mipmap-hdpi": 72,
    "mipmap-xhdpi": 96,
    "mipmap-xxhdpi": 144,
    "mipmap-xxxhdpi": 192,
}

# Android adaptive icon sizes (foreground/background layers)
ANDROID_ADAPTIVE_SIZES = {
    "mipmap-mdpi": 108,
    "mipmap-hdpi": 162,
    "mipmap-xhdpi": 216,
    "mipmap-xxhdpi": 324,
    "mipmap-xxxhdpi": 432,
}

# iOS icon sizes (all required for modern iOS)
IOS_SIZES = {
    "Icon-App-1024x1024@1x.png": 1024,  # App Store
    "Icon-App-20x20@1x.png": 20,
    "Icon-App-20x20@2x.png": 40,
    "Icon-App-20x20@3x.png": 60,
    "Icon-App-29x29@1x.png": 29,
    "Icon-App-29x29@2x.png": 58,
    "Icon-App-29x29@3x.png": 87,
    "Icon-App-40x40@1x.png": 40,
    "Icon-App-40x40@2x.png": 80,
    "Icon-App-40x40@3x.png": 120,
    "Icon-App-60x60@2x.png": 120,
    "Icon-App-60x60@3x.png": 180,
    "Icon-App-76x76@1x.png": 76,
    "Icon-App-76x76@2x.png": 152,
    "Icon-App-83.5x83.5@2x.png": 167,
}


def export_android(src_img):
    """Export standard Android launcher icons."""
    res_dir = os.path.join(APP_DIR, "android/app/src/main/res")
    for density, size in ANDROID_SIZES.items():
        out_dir = os.path.join(res_dir, density)
        os.makedirs(out_dir, exist_ok=True)
        resized = src_img.resize((size, size), Image.LANCZOS)
        # Convert to RGB (no alpha) for Android standard icons
        rgb = Image.new("RGB", (size, size), (238, 21, 21))
        rgb.paste(resized, mask=resized.split()[3] if resized.mode == "RGBA" else None)
        rgb.save(os.path.join(out_dir, "ic_launcher.png"), "PNG")
        print(f"  Android {density}: {size}x{size}")


def export_android_adaptive(fg_img, bg_img):
    """Export Android adaptive icon layers."""
    res_dir = os.path.join(APP_DIR, "android/app/src/main/res")
    for density, size in ANDROID_ADAPTIVE_SIZES.items():
        out_dir = os.path.join(res_dir, density)
        os.makedirs(out_dir, exist_ok=True)

        fg_resized = fg_img.resize((size, size), Image.LANCZOS)
        fg_resized.save(os.path.join(out_dir, "ic_launcher_foreground.png"), "PNG")

        bg_resized = bg_img.resize((size, size), Image.LANCZOS)
        bg_resized.save(os.path.join(out_dir, "ic_launcher_background.png"), "PNG")
        print(f"  Android adaptive {density}: {size}x{size}")

    # Write adaptive icon XML
    xml_dir = os.path.join(res_dir, "mipmap-anydpi-v26")
    os.makedirs(xml_dir, exist_ok=True)

    adaptive_xml = '''<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@mipmap/ic_launcher_background"/>
    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>
</adaptive-icon>
'''
    with open(os.path.join(xml_dir, "ic_launcher.xml"), "w") as f:
        f.write(adaptive_xml)
    print(f"  Android adaptive icon XML written")


def export_ios(src_img):
    """Export iOS app icons."""
    ios_dir = os.path.join(APP_DIR, "ios/Runner/Assets.xcassets/AppIcon.appiconset")
    os.makedirs(ios_dir, exist_ok=True)

    contents_images = []
    for filename, size in IOS_SIZES.items():
        resized = src_img.resize((size, size), Image.LANCZOS)
        # iOS requires no alpha for App Store icon
        rgb = Image.new("RGB", (size, size), (238, 21, 21))
        rgb.paste(resized, mask=resized.split()[3] if resized.mode == "RGBA" else None)
        rgb.save(os.path.join(ios_dir, filename), "PNG")
        print(f"  iOS {filename}: {size}x{size}")

        # Parse the filename to build Contents.json
        # e.g. "Icon-App-60x60@3x.png" -> size=60, scale=3
        parts = filename.replace(".png", "").split("@")
        scale_str = parts[1] if len(parts) > 1 else "1x"
        size_part = parts[0].split("-")[-1]  # e.g. "60x60" or "1024x1024"
        point_size = size_part.split("x")[0]

        idiom = "iphone"
        if point_size == "1024":
            idiom = "ios-marketing"
        elif point_size in ("76", "83.5"):
            idiom = "ipad"
        elif point_size == "20" and scale_str == "1x":
            idiom = "ipad"
        elif point_size == "29" and scale_str == "1x":
            idiom = "ipad"
        elif point_size == "40" and scale_str == "1x":
            idiom = "ipad"

        contents_images.append({
            "filename": filename,
            "idiom": idiom,
            "scale": scale_str,
            "size": f"{point_size}x{point_size}",
        })

    contents = {
        "images": contents_images,
        "info": {
            "author": "flutter_launcher_icons",
            "version": 1,
        },
    }
    with open(os.path.join(ios_dir, "Contents.json"), "w") as f:
        json.dump(contents, f, indent=2)
    print(f"  iOS Contents.json written")


def main():
    print("Loading source icons...")
    src = Image.open(ICON_SRC)
    fg = Image.open(ADAPTIVE_FG_SRC)
    bg = Image.open(ADAPTIVE_BG_SRC)

    print("\nExporting Android icons...")
    export_android(src)

    print("\nExporting Android adaptive icons...")
    export_android_adaptive(fg, bg)

    print("\nExporting iOS icons...")
    export_ios(src)

    print("\nAll platform icons exported successfully!")


if __name__ == "__main__":
    main()
