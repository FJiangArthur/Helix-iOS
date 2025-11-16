#!/bin/bash

# Script to fix strict mode violations across the codebase
# This script will:
# 1. Replace print statements with proper logging
# 2. The remaining type annotations and const fixes should be done via IDE

echo "Fixing strict mode violations..."

# Function to add app_logger import if not present
add_logger_import() {
    local file="$1"
    if ! grep -q "import.*app_logger.dart" "$file"; then
        # Find the last import line and add after it
        sed -i "/^import /a import 'package:flutter_helix/utils/app_logger.dart';" "$file"
    fi
}

# Find all Dart files (excluding generated files)
find /home/user/Helix-iOS/lib -name "*.dart" \
    ! -name "*.g.dart" \
    ! -name "*.freezed.dart" \
    -type f | while read -r file; do

    echo "Processing: $file"

    # Check if file contains print statements
    if grep -q "print(" "$file"; then
        # Add logger import
        if ! grep -q "import.*app_logger.dart" "$file"; then
            # Add import after the last import statement
            last_import_line=$(grep -n "^import " "$file" | tail -1 | cut -d: -f1)
            if [ -n "$last_import_line" ]; then
                sed -i "${last_import_line}a import 'package:flutter_helix/utils/app_logger.dart';" "$file"
            fi
        fi

        # Replace print statements with logger calls
        # Handle different print patterns:
        # print('message') -> appLogger.i('message')
        # print("message") -> appLogger.i("message")
        # print('Error: $e') -> appLogger.e('Error', error: e)
        # print('❌ ...') -> appLogger.e('...')
        # print('✅ ...') -> appLogger.i('...')
        # print('[TAG] ...') -> appLogger.i('[TAG] ...')

        # Replace error prints
        sed -i "s/print('❌ /appLogger.e('/g" "$file"
        sed -i 's/print("❌ /appLogger.e("/g' "$file"
        sed -i "s/print('Error:/appLogger.e('Error:/g" "$file"
        sed -i 's/print("Error:/appLogger.e("Error:/g' "$file"

        # Replace success/info prints
        sed -i "s/print('✅ /appLogger.i('/g" "$file"
        sed -i 's/print("✅ /appLogger.i("/g' "$file"
        sed -i "s/print('/appLogger.i('/g" "$file"
        sed -i 's/print("/appLogger.i("/g' "$file"
        sed -i 's/print(/appLogger.i(/g' "$file"
    fi
done

echo "Print statements fixed!"
echo ""
echo "Remaining tasks to complete in your IDE:"
echo "1. Run: flutter analyze"
echo "2. Fix any remaining type annotation errors flagged by the analyzer"
echo "3. Add trailing commas where suggested"
echo "4. Make variables 'final' where appropriate"
echo "5. Re-run: flutter analyze to verify all errors are fixed"
