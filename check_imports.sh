#!/bin/bash

echo "=== Checking for potential build errors ==="
echo ""

echo "1. Checking for missing Freezed generated files..."
for file in lib/models/*.dart; do
    if [[ "$file" != *".freezed.dart" ]] && [[ "$file" != *".g.dart" ]] && grep -q "@freezed" "$file"; then
        basename="${file%.dart}"
        if [[ ! -f "${basename}.freezed.dart" ]]; then
            echo "⚠️  Missing: ${basename}.freezed.dart"
        fi
        if grep -q "fromJson" "$file" && [[ ! -f "${basename}.g.dart" ]]; then
            echo "⚠️  Missing: ${basename}.g.dart"
        fi
    fi
done

echo ""
echo "2. Checking for import errors in new files..."
grep -r "import.*package:flutter_helix" lib/services/implementations/*.dart lib/controllers/*.dart 2>/dev/null | while read line; do
    file=$(echo "$line" | cut -d: -f1)
    import=$(echo "$line" | cut -d: -f2-)
    import_path=$(echo "$import" | sed "s/import 'package:flutter_helix\///" | sed "s/';//" | sed "s/;//")
    if [[ ! -f "lib/$import_path" ]]; then
        echo "❌ $file: Missing import lib/$import_path"
    fi
done

echo ""
echo "3. Checking for duplicate class definitions..."
classes=$(grep -r "^class " lib/*.dart lib/**/*.dart 2>/dev/null | grep -v ".freezed.dart" | grep -v ".g.dart" | awk '{print $2}' | sort)
duplicates=$(echo "$classes" | uniq -d)
if [[ -n "$duplicates" ]]; then
    echo "⚠️  Potential duplicate classes:"
    echo "$duplicates"
else
    echo "✅ No duplicate class definitions found"
fi

echo ""
echo "4. Checking for syntax errors in new models..."
for file in lib/models/{glasses_connection,conversation_session,transcript_segment,audio_chunk}.dart; do
    if [[ -f "$file" ]]; then
        # Check for basic Freezed structure
        if grep -q "@freezed" "$file" && grep -q "const factory" "$file" && grep -q "fromJson" "$file"; then
            echo "✅ $(basename $file): Freezed structure looks correct"
        else
            echo "⚠️  $(basename $file): Missing Freezed components"
        fi
    fi
done

echo ""
echo "5. Checking service implementations..."
for file in lib/services/implementations/*_impl.dart; do
    if [[ -f "$file" ]]; then
        basename=$(basename "$file" .dart)
        interface_name=$(echo "$basename" | sed 's/_impl//')
        if grep -q "implements I" "$file"; then
            echo "✅ $(basename $file): Implements interface"
        else
            echo "⚠️  $(basename $file): No interface implementation found"
        fi
    fi
done

echo ""
echo "6. Generating summary..."
total_dart_files=$(find lib -name "*.dart" ! -name "*.freezed.dart" ! -name "*.g.dart" | wc -l)
total_test_files=$(find test -name "*_test.dart" 2>/dev/null | wc -l)
echo "📊 Total implementation files: $total_dart_files"
echo "📊 Total test files: $total_test_files"

echo ""
echo "=== Build check complete ==="
echo ""
echo "⚠️  Note: Freezed code generation is required before building:"
echo "   Run: flutter packages pub run build_runner build --delete-conflicting-outputs"
