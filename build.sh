#!/bin/bash

# Настройки
MODULE_NAME="Zygisk-Il2CppDumper"
PACKAGE_NAME="$1"

if [ -z "$PACKAGE_NAME" ]; then
    echo "❌ Package name is required!"
    echo "Usage: ./build.sh <package_name>"
    exit 1
fi

echo "📦 Building for package: $PACKAGE_NAME"

# Создаём структуру модуля
mkdir -p module
mkdir -p module/zygisk
mkdir -p module/META-INF/com/google/android

# Копируем файлы
cp -r src/* module/zygisk/ 2>/dev/null || echo "⚠️ No src directory found"
cp module_template/customize.sh module/ 2>/dev/null || echo "⚠️ No customize.sh found"

# Создаём module.prop
cat > module/module.prop << EOF
id=zygisk_il2cppdumper
name=$MODULE_NAME
version=1.0.0
versionCode=1
author=Zygisk
description=Dump IL2CPP metadata at runtime
EOF

# Создаём служебные файлы для Magisk
cat > module/META-INF/com/google/android/update-binary << 'EOF'
#MAGISK
EOF

cat > module/META-INF/com/google/android/updater-script << 'EOF'
#MAGISK
EOF

# Создаём ZIP
cd module
zip -r ../$MODULE_NAME.zip .
cd ..

echo "✅ Module built: $MODULE_NAME.zip"
echo "📌 Package name: $PACKAGE_NAME"