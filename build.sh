#!/bin/bash

# Настройки
MODULE_NAME="Zygisk-Il2CppDumper"
PACKAGE_NAME="${1:-com.example.game}"
MIN_SDK=21

echo "📦 Building Zygisk module for: $PACKAGE_NAME"

# Проверяем NDK
if [ -z "$ANDROID_NDK_HOME" ]; then
    echo "❌ ANDROID_NDK_HOME not set!"
    exit 1
fi

echo "✅ NDK: $ANDROID_NDK_HOME"

# Создаём директорию для сборки
mkdir -p build
cd build

# CMake конфиг для каждой архитектуры
for ABI in arm64-v8a armeabi-v7a; do
    echo "🔨 Building for $ABI..."
    
    BUILD_DIR="build_$ABI"
    mkdir -p "$BUILD_DIR"
    cd "$BUILD_DIR"
    
    cmake -DCMAKE_TOOLCHAIN_FILE="$ANDROID_NDK_HOME/build/cmake/android.cmake" \
        -DCMAKE_BUILD_TYPE=Release \
        -DANDROID_ABI="$ABI" \
        -DANDROID_PLATFORM="android-$MIN_SDK" \
        -DANDROID_STL=c++_shared \
        ../../src/main/cpp
    
    cmake --build . --config Release
    
    if [ -f "libil2cppdumper.so" ]; then
        echo "✅ Built libil2cppdumper.so for $ABI"
    else
        echo "⚠️  libil2cppdumper.so not found for $ABI"
    fi
    
    cd ..
done

cd ..

# Создаём структуру модуля Magisk
echo "📁 Creating Magisk module structure..."
mkdir -p module/system/lib64
mkdir -p module/system/lib
mkdir -p module/META-INF/com/google/android

# Копируем .so файлы
if [ -f "build/build_arm64-v8a/libil2cppdumper.so" ]; then
    cp build/build_arm64-v8a/libil2cppdumper.so module/system/lib64/
    echo "✅ Copied arm64-v8a .so"
fi

if [ -f "build/build_armeabi-v7a/libil2cppdumper.so" ]; then
    cp build/build_armeabi-v7a/libil2cppdumper.so module/system/lib/
    echo "✅ Copied armeabi-v7a .so"
fi

# Создаём module.prop
cat > module/module.prop << EOF
id=zygisk_il2cppdumper
name=$MODULE_NAME
version=1.0.0
versionCode=1
author=Zygisk
description=Dump IL2CPP metadata at runtime
minMagisk=24000
EOF

echo "✅ Created module.prop"

# Создаём Magisk скрипты
cat > module/META-INF/com/google/android/update-binary << 'SCRIPT'
#!/sbin/sh
echo "ui_print Zygisk Il2CppDumper"
exit 0
SCRIPT

cat > module/META-INF/com/google/android/updater-script << 'SCRIPT'
#MAGISK
SCRIPT

chmod 755 module/META-INF/com/google/android/update-binary

echo "✅ Created META-INF scripts"

# Упаковываем в ZIP
echo "📦 Creating ZIP archive..."
cd module
zip -r -q "../$MODULE_NAME.zip" .
cd ..

if [ -f "$MODULE_NAME.zip" ]; then
    SIZE=$(du -h "$MODULE_NAME.zip" | cut -f1)
    echo "✅ Module built successfully: $MODULE_NAME.zip ($SIZE)"
    echo "📦 Package name: $PACKAGE_NAME"
else
    echo "❌ Failed to create ZIP archive"
    exit 1
fi
