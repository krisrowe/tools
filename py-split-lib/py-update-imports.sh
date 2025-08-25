#!/bin/bash
# =============================================================================
#
# py-update-imports.sh: A script to recursively update Python import statements
#                       in a given directory.
#
# =============================================================================

set -e

# --- Usage function to display help text ---
usage() {
    echo "Usage: $0 <path> <source_package> <target_package>"
    echo
    echo "This script updates Python import statements in all .py files within a directory."
    echo "It replaces old package names with new ones in 'from' and 'import' statements."
    echo
    echo "Arguments:"
    echo "  <path>             Directory to search for Python files (e.g., '~/my-repo' or '/path/to/repo')"
    echo "  <source_package>   Old package name to replace (e.g., 'old_package')"
    echo "  <target_package>   New package name to use (e.g., 'new_package')"
    echo
    echo "Examples:"
    echo "  # Update imports in a repository directory"
    echo "  $0 '~/my-repo' old_pkg new_pkg"
    echo
    echo "  # Update imports in current directory"
    echo "  $0 . old_pkg new_pkg"
    echo
    echo "  # Update imports in specific path"
    echo "  $0 '/path/to/repo' old_pkg new_pkg"
    echo
    echo "What it does:"
    echo "  - Finds all .py files in the specified directory (recursively)"
    echo "  - Updates 'from old_pkg import ...' to 'from new_pkg import ...' (anywhere in file)"
    echo "  - Updates 'import old_package' to 'import new_package' (anywhere in file)"
    echo "  - Only processes files that actually contain the old package name"
    echo "  - Handles imports at any position in the file, not just line beginnings"
    echo "  - Provides a summary of files that may need manual attention for documentation"
    echo "-------------------------------------------------------------------------------------------"
}

# --- Check for help flag first ---
if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    usage
    exit 0
fi

# --- Check for correct number of arguments ---
if [ "$#" -ne 3 ]; then
    echo "Error: Incorrect number of arguments. Expected 3, got $#." >&2
    echo
    usage
    exit 1
fi

# --- Parameter Assignments ---
TARGET_PATH=$(eval echo "$1") # Expands '~' if present
SOURCE_PACKAGE=$2
TARGET_PACKAGE=$3

# --- Validate the target path ---
if [ ! -d "${TARGET_PATH}" ]; then
    echo "Error: The provided path '${TARGET_PATH}' does not exist." >&2
    exit 1
fi

echo "▶️  Updating import statements in '${TARGET_PATH}'..."
echo "   - Replacing '${SOURCE_PACKAGE}' with '${TARGET_PACKAGE}'."

# --- Find all .py files and perform the replacement ---
# We use `grep` to find files that actually contain the source package name
# to avoid unnecessarily running `sed` on every file.
# The replacement targets all 'from' and 'import' statements containing the source package.
find "${TARGET_PATH}" -type f -name "*.py" -print0 | while IFS= read -r -d $'\0' file; do
    # Check if the file contains the source package name in import statements
    if grep -q -E "(from|import)\s+${SOURCE_PACKAGE}" "$file"; then
        echo "   - Processing: $file"
        # Use a temporary file for sed to avoid issues with writing to the same file
        # Update 'from source_package import ...' to 'from target_package import ...'
        sed -i.bak "s/from\s\+${SOURCE_PACKAGE}/from ${TARGET_PACKAGE}/g" "$file"
        # Update 'import source_package' to 'import target_package'
        sed -i.bak "s/import\s\+${SOURCE_PACKAGE}/import ${TARGET_PACKAGE}/g" "$file"
        rm "${file}.bak" # Remove the backup file created by sed -i
    fi
done

echo "✅ Done. Import statements updated."

# --- Final validation: Check for any remaining references to the old package name ---
echo
echo "🔍 Checking for remaining references to '${SOURCE_PACKAGE}' (non-Python imports)..."
echo "   These files may need manual attention for documentation, comments, or other references:"
echo

REMAINING_FILES=$(grep -r "${SOURCE_PACKAGE}" "${TARGET_PATH}" --exclude="*.pyc" --exclude="*.pyo" --exclude="__pycache__" --exclude=".git" 2>/dev/null | cut -d: -f1 | sort -u)

if [ -n "$REMAINING_FILES" ]; then
    echo "$REMAINING_FILES" | while IFS= read -r file; do
        if [ -f "$file" ]; then
            echo "   - $file"
        fi
    done
    echo
    echo "   ℹ️  These files may contain documentation, comments, or other references"
    echo "       that need manual updating from '${SOURCE_PACKAGE}' to '${TARGET_PACKAGE}'."
else
    echo "   ✅ No remaining references found!"
fi
