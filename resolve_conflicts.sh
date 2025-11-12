#!/bin/bash

# Script to resolve merge conflicts by accepting both sides where appropriate

resolve_conflict() {
    local file="$1"
    echo "Resolving conflicts in $file"
    
    # Create a temporary file
    temp_file=$(mktemp)
    
    # Process the file line by line
    in_conflict=false
    keep_head=true
    keep_origin=true
    
    while IFS= read -r line; do
        if [[ "$line" == "<<<<<<< HEAD" ]]; then
            in_conflict=true
            continue
        elif [[ "$line" == "=======" ]]; then
            continue
        elif [[ "$line" == ">>>>>>> origin/main" ]]; then
            in_conflict=false
            continue
        elif [[ ! $in_conflict ]]; then
            echo "$line" >> "$temp_file"
        fi
    done < "$file"
    
    # Replace original file with resolved version
    mv "$temp_file" "$file"
    echo "Resolved conflicts in $file"
}

# List of files with conflicts
files=(
    "lib/ble_manager.dart"
    "lib/screens/ai_assistant_screen.dart"
    "lib/screens/even_ai_history_screen.dart"
    "lib/screens/recording_screen.dart"
    "lib/services/evenai.dart"
    "lib/services/features_services.dart"
    "lib/services/implementations/audio_service_impl.dart"
    "lib/services/text_service.dart"
    "macos/Flutter/GeneratedPluginRegistrant.swift"
    "ios/Podfile.lock"
    "pubspec.lock"
)

# Resolve conflicts in each file
for file in "${files[@]}"; do
    if [[ -f "$file" ]]; then
        resolve_conflict "$file"
    else
        echo "File $file not found"
    fi
done

echo "All conflicts resolved!"
