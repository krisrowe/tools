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
    echo "Usage: $0 <source_package> <target_package> <path>"
    echo
    echo "Arguments:"
    echo "  <source_package>   The original package name to be replaced (e.g., 'multi_env_sdk')."
    echo "  <target_package>   The new package name to use (e.g., 'multieden')."
    echo "  <path>             The directory path to search for Python files recursively."
    echo
    echo "-------------------------------------------------------------------------------------------"
    echo "Example: To replace 'from multi_env_sdk.' with 'from multieden.' in all .py files"
    echo "         under the '~/ws/multieden' directory:"
    echo
    echo "$0 multi_env_sdk multieden '~/ws/multieden'"
    echo "-------------------------------------------------------------------------------------------"
}

# --- Check for correct number of arguments ---
if [ "$#" -ne 3 ]; then
    usage
    exit 1
fi

# --- Parameter Assignments ---
SOURCE_PACKAGE=$1
TARGET_PACKAGE=$2
TARGET_PATH=$(eval echo "$3") # Expands '~' if present

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
# The replacement targets lines starting with 'from' or 'import' to be safer.
find "${TARGET_PATH}" -type f -name "*.py" -print0 | while IFS= read -r -d $'\0' file; do
    # Check if the file contains the import statement to be replaced
    if grep -q -E "^(from|import)\s+${SOURCE_PACKAGE}" "$file"; then
        echo "   - Processing: $file"
        # Use a temporary file for sed to avoid issues with writing to the same file
        sed -i.bak "s/^\(from\|import\)\s\+${SOURCE_PACKAGE}/\1 ${TARGET_PACKAGE}/" "$file"
        rm "${file}.bak" # Remove the backup file created by sed -i
    fi
done

echo "✅ Done. Import statements updated."
