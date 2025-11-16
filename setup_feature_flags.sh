#!/bin/bash

# Feature Flags Setup Script
# This script generates the required Freezed code for feature flag models

echo "🚀 Setting up Feature Flags..."
echo ""

# Check if Flutter is available
if ! command -v flutter &> /dev/null
then
    echo "❌ Error: Flutter is not installed or not in PATH"
    echo "Please install Flutter: https://flutter.dev/docs/get-started/install"
    exit 1
fi

echo "✓ Flutter found"

# Check if we're in the right directory
if [ ! -f "pubspec.yaml" ]; then
    echo "❌ Error: pubspec.yaml not found"
    echo "Please run this script from the project root directory"
    exit 1
fi

echo "✓ In project directory"

# Check if feature_flags.json exists
if [ ! -f "feature_flags.json" ]; then
    echo "❌ Error: feature_flags.json not found"
    echo "Please ensure feature_flags.json exists in the project root"
    exit 1
fi

echo "✓ Configuration file found"

# Get dependencies
echo ""
echo "📦 Getting dependencies..."
flutter pub get

# Run build_runner
echo ""
echo "🔨 Generating Freezed code..."
flutter pub run build_runner build --delete-conflicting-outputs

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Feature flags setup complete!"
    echo ""
    echo "Available flags:"
    echo "  - modelSelection"
    echo "  - advancedAIAnalysis"
    echo "  - enhancedFactChecking"
    echo "  - whisperTranscription"
    echo "  - conversationInsights"
    echo "  - offlineMode"
    echo "  - voiceCommands"
    echo "  - advancedLogging"
    echo "  - performanceMonitoring"
    echo "  - betaFeatures"
    echo ""
    echo "📚 Documentation:"
    echo "  - Quick Start: FEATURE_FLAGS_QUICK_START.md"
    echo "  - Full Docs: docs/FEATURE_FLAGS.md"
    echo "  - Examples: lib/core/config/feature_flag_examples.dart"
    echo ""
else
    echo ""
    echo "❌ Code generation failed"
    echo "Please check the error messages above"
    exit 1
fi
