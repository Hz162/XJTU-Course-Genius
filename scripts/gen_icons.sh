#!/bin/bash
# Generate all platform icons from assets/logo.png
# Run this once after cloning or when logo.png changes
# Requires: ImageMagick (convert) or .NET System.Drawing

SRC="assets/logo.png"

if command -v convert &>/dev/null; then
  echo "Using ImageMagick..."
  # macOS AppIcon
  for size in 16 32 64 128 256 512 1024; do
    convert "$SRC" -resize "${size}x${size}" \
      "frontend/macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_${size}.png"
  done
  # Linux hicolor icons
  for size in 48 64 128 256; do
    mkdir -p "assets/linux_icons/${size}x${size}/apps"
    convert "$SRC" -resize "${size}x${size}" \
      "assets/linux_icons/${size}x${size}/apps/xjtu-course-genius.png"
  done
  # Windows icon
  convert "$SRC" -resize 256x256 "frontend/windows/runner/resources/app_icon.ico"
  echo "All icons generated."
elif command -v magick &>/dev/null; then
  echo "Using ImageMagick (magick)..."
  for size in 16 32 64 128 256 512 1024; do
    magick "$SRC" -resize "${size}x${size}" \
      "frontend/macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_${size}.png"
  done
  for size in 48 64 128 256; do
    mkdir -p "assets/linux_icons/${size}x${size}/apps"
    magick "$SRC" -resize "${size}x${size}" \
      "assets/linux_icons/${size}x${size}/apps/xjtu-course-genius.png"
  done
  magick "$SRC" -resize 256x256 "frontend/windows/runner/resources/app_icon.ico"
  echo "All icons generated."
else
  echo "ImageMagick not found. On macOS: brew install imagemagick"
  echo "On Ubuntu: sudo apt-get install imagemagick"
  echo "On Windows: winget install ImageMagick.ImageMagick"
  exit 1
fi
