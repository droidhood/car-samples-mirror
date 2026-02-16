#!/bin/bash
# Toggle between AOSP and Android Studio gradle build configurations
#
# This script intelligently detects the current build mode and switches to the opposite:
# 
# AOSP/GitHub CI mode:
#   - build.gradle = AOSP configuration
#   - github_build.gradle = Android Studio configuration
#
# Android Studio mode:
#   - aosp_build.gradle = AOSP configuration
#   - build.gradle = Android Studio configuration (from github_build.gradle)
#
# Usage:
#   ./scripts/toggle_gradle_build.sh           # Toggle build mode
#   ./scripts/toggle_gradle_build.sh --dry-run # Preview changes without executing

# Exit immediately if a command exits with a non-zero status
set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DRY_RUN=false

# Parse command line arguments
if [ "$1" == "--dry-run" ] || [ "$1" == "-n" ]; then
  DRY_RUN=true
fi

# Define all directories that contain gradle files to toggle
GRADLE_DIRS=(
  "car/app/app-samples"
  "car/app/app-samples/navigation/automotive"
  "car/app/app-samples/navigation/common"
  "car/app/app-samples/navigation/mobile"
  "car/app/app-samples/showcase/automotive"
  "car/app/app-samples/showcase/common"
  "car/app/app-samples/showcase/mobile"
)

# Detect current mode by checking if aosp_build.gradle exists
detect_current_mode() {
  cd "$PROJECT_ROOT"
  
  # Check first directory that should have both files
  local check_dir="car/app/app-samples/navigation/automotive"
  
  if [ -f "$check_dir/aosp_build.gradle" ]; then
    echo "ANDROID_STUDIO"
  else
    echo "AOSP"
  fi
}

# Execute or preview a move operation
execute_move() {
  local src="$1"
  local dst="$2"
  
  if [ "$DRY_RUN" == true ]; then
    echo "  [DRY RUN] $src → $dst"
  else
    echo "  $src → $dst"
    mv "$src" "$dst"
  fi
}

# Switch from AOSP mode to Android Studio mode
switch_to_android_studio() {
  echo ""
  echo "Switching to Android Studio mode..."
  echo ""
  
  cd "$PROJECT_ROOT"
  
  for dir in "${GRADLE_DIRS[@]}"; do
    # Check if build.gradle exists in this directory
    if [ -f "$dir/build.gradle" ]; then
      execute_move "$dir/build.gradle" "$dir/aosp_build.gradle"
    fi
    
    # Check if github_build.gradle exists in this directory
    if [ -f "$dir/github_build.gradle" ]; then
      execute_move "$dir/github_build.gradle" "$dir/build.gradle"
    fi
  done
  
  echo ""
  if [ "$DRY_RUN" == true ]; then
    echo "[DRY RUN] Would switch to Android Studio mode"
  else
    echo "✓ Successfully switched to Android Studio mode!"
    echo "  You can now open the project in Android Studio."
  fi
}

# Switch from Android Studio mode to AOSP mode
switch_to_aosp() {
  echo ""
  echo "Switching to AOSP/GitHub CI mode..."
  echo ""
  
  cd "$PROJECT_ROOT"
  
  for dir in "${GRADLE_DIRS[@]}"; do
    # Check if build.gradle exists in this directory
    if [ -f "$dir/build.gradle" ]; then
      execute_move "$dir/build.gradle" "$dir/github_build.gradle"
    fi
    
    # Check if aosp_build.gradle exists in this directory
    if [ -f "$dir/aosp_build.gradle" ]; then
      execute_move "$dir/aosp_build.gradle" "$dir/build.gradle"
    fi
  done
  
  echo ""
  if [ "$DRY_RUN" == true ]; then
    echo "[DRY RUN] Would switch to AOSP/GitHub CI mode"
  else
    echo "✓ Successfully switched to AOSP/GitHub CI mode!"
    echo "  The project is now configured for GitHub CI builds."
  fi
}

# Main execution
main() {
  echo "========================================="
  echo "  Gradle Build Configuration Toggle"
  echo "========================================="
  
  if [ "$DRY_RUN" == true ]; then
    echo ""
    echo "🔍 DRY RUN MODE - No changes will be made"
  fi
  
  echo ""
  echo "Detecting current build configuration..."
  
  CURRENT_MODE=$(detect_current_mode)
  
  if [ "$CURRENT_MODE" == "ANDROID_STUDIO" ]; then
    echo "Current mode: Android Studio"
    echo "Target mode:  AOSP/GitHub CI"
    switch_to_aosp
  else
    echo "Current mode: AOSP/GitHub CI"
    echo "Target mode:  Android Studio"
    switch_to_android_studio
  fi
  
  echo ""
  echo "========================================="
  
  if [ "$DRY_RUN" == true ]; then
    echo ""
    echo "To execute these changes, run without --dry-run flag:"
    echo "  $0"
  fi
}

# Run main function
main
