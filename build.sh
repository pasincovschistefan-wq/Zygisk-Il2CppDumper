#!/bin/bash

set -x  # Debug mode - показывает каждую команду

# Настройки
MODULE_NAME="Zygisk-Il2CppDumper"
LIB_NAME="il2cppdumper"
PACKAGE_NAME="${1:-com.example.game}"
MIN_SDK=21

echo "📦 Building Zygisk module for: $PACKAGE_NAME"
echo "🔧 NDK Home: $ANDROID_NDK_HOME"
echo "📁 Current directory: $(pwd)"
echo "📂 CMake toolchain: $ANDROID_NDK_HOME/build/cmake/android.cmake"

# Проверяем NDK
if [ -z "$ANDROID_NDK_HOME" ]; then
    echo "❌ ANDROID_NDK_HOME not set!"
    exit 1
fi

# Проверяем CMake
if ! command -v cmake &> /dev/null; then
    echo "❌ CMake not found!"
    exit 1
fi

# Проверяем тулчейн
if [ ! -f "$ANDROID_NDK_HOME/build/cmake/android.cmake" ]; then
    echo "❌ Toolchain file not found: $ANDROID_NDK_HOME/build/cmake/android.cmake"
    exit 1
fi

echo "✅ NDK: $ANDROID_NDK_HOME"
echo "✅ CMake version: $(cmake --version | head -n 1)"

# Создаём директорию для сборки
mkdir -p build
cd build

echo "📁 Changed to build directory: $(pwd)"
echo "📂 Contents of module/src/main/cpp:"
ls -la ../module/src/main/cpp/

# CMake конфиг для каждой архитектуры
for ABI in arm64-v8a armeabi-v7a; do
    echo ""
    echo "═══════════════════════════════════════"
    echo "🔨 Building for $ABI..."
    echo "═══════════════════════════════════════"
    
    BUILD_DIR="build_$ABI"
    mkdir -p "$BUILD_DIR"
    cd "$BUILD_DIR"
    
    echo "📁 Build directory: $(pwd)"
    
    cmake -DCMAKE_TOOLCHAIN_FILE="$ANDROID_NDK_HOME/build/cmake/android.cmake" \
        -DCMAKE_BUILD_TYPE=Release \
        -DANDROID_ABI="$ABI" \
        -DANDROID_PLATFORM="android-$MIN_SDK" \
        -DANDROID_STL=c++_shared \
        -DMODULE_NAME="$LIB_NAME" \
        ../../module/src/main/cpp
    
    echo "📂 CMake output:"
    ls -la
    
    cmake --build . --config Release
    
    echo "📂 After build:"
    ls -la
    
    if [ -f "lib${LIB_NAME}.so" ]; then
        echo "✅ Built lib${LIB_NAME}.so for $ABI"
        ls -lh "lib${LIB_NAME}.so"
    else
        echo "⚠️  lib${LIB_NAME}.so not found for $ABI"
        echo "📂 Looking for .so files:"
        find . -name "*.so" -ls
    fi
    
    cd ..
done

cd ..

# Создаём структуру модуля Magisk
echo ""
echo "═══════════════════════════════════════"
echo "📁 Creating Magisk module structure..."
echo "═══════════════════════════════════════"
mkdir -p module/system/lib64
mkdir -p module/system/lib
mkdir -p module/META-INF/com/google/android

# Копируем .so файлы
if [ -f "build/build_arm64-v8a/lib${LIB_NAME}.so" ]; then
    cp "build/build_arm64-v8a/lib${LIB_NAME}.so" module/system/lib64/
    echo "✅ Copied arm64-v8a .so"
else
    echo "⚠️  arm64-v8a .so not found"
fi

if [ -f "build/build_armeabi-v7a/lib${LIB_NAME}.so" ]; then
    cp "build/build_armeabi-v7a/lib${LIB_NAME}.so" module/system/lib/
    echo "✅ Copied armeabi-v7a .so"
else
    echo "⚠️  armeabi-v7a .so not found"
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
echo ""
echo "═══════════════════════════════════════"
echo "📦 Creating ZIP archive..."
echo "═══════════════════════════════════════"
cd module
echo "📂 Module contents:"
find . -type f -ls
zip -r "../$MODULE_NAME.zip" .
cd ..

if [ -f "$MODULE_NAME.zip" ]; then
    SIZE=$(du -h "$MODULE_NAME.zip" | cut -f1)
    echo "✅ Module built successfully: $MODULE_NAME.zip ($SIZE)"
    echo "📦 Package name: $PACKAGE_NAME"
    ls -lh "$MODULE_NAME.zip"
else
    echo "❌ Failed to create ZIP archive"
    exit 1
fi

set +x  # Disable debug mode
