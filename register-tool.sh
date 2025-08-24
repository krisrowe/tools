#!/bin/bash
# =============================================================================
#
# register-tool.sh: Registers a new tool into the current dev-tools repository.
#
# It creates a dedicated subdirectory for the tool, with its own README,
# and updates the main README with a link to the new tool's folder.
# This script must be run from the root of the dev-tools repository.
#
# =============================================================================
set -e

usage() {
    echo "Usage: $0 <tool-name> <initial_file_path> \"<description>\""
    echo
    echo "Arguments:"
    echo "  tool-name          A short name for the tool, which will become the folder name."
    echo "  initial_file_path  The full or relative path to the initial script or file for the tool."
    echo "  \"<description>\"    A short, quoted description of the tool."
    echo
    echo "Example: $0 my-new-script ./scripts/run.sh \"This is a new script that does amazing things.\""
}

if [[ "$1" == "-h" || "$1" == "--help" || "$#" -ne 3 ]]; then
    usage
    exit 1
fi

# --- Parameters ---
TOOL_NAME=$1
INITIAL_FILE_PATH=$(eval echo "$2") # Use eval to expand '~' if present
DESCRIPTION=$3
INITIAL_FILENAME=$(basename -- "$INITIAL_FILE_PATH")

# --- Pre-flight Checks ---
if [ ! -f ".git/config" ]; then
    echo "Error: This script must be run from the root of a Git repository." >&2
    exit 1
fi
if [ ! -f "$INITIAL_FILE_PATH" ]; then
    echo "Error: Initial file not found at '${INITIAL_FILE_PATH}'." >&2
    exit 1
fi
if [ -d "$TOOL_NAME" ]; then
    echo "Error: A directory named '${TOOL_NAME}' already exists." >&2
    exit 1
fi

# --- Idempotency Check ---
echo "▶️ Checking if '${TOOL_NAME}' is already registered in the main README..."
if grep -q "\[${TOOL_NAME}\]" README.md; then
    echo "✅ Tool '${TOOL_NAME}' is already registered. No changes needed."
    exit 0
fi

# --- Execution ---
echo "▶️ Registering new tool: '${TOOL_NAME}'..."

# 1. Create the tool's subdirectory
mkdir "$TOOL_NAME"
cd "$TOOL_NAME"

# 2. Create the tool-specific README.md using a robust echo block
{
    echo "# ${TOOL_NAME}"
    echo ""
    echo "${DESCRIPTION}"
} > README.md

# 3. Copy the initial file into the tool's directory
cp "${INITIAL_FILE_PATH}" .
cd ..

# 4. Update the main README.md at the root
echo "▶️ Updating main README.md..."
echo "- **[${TOOL_NAME}](./${TOOL_NAME}/)**: ${DESCRIPTION}" >> README.md

# 5. Commit all changes to Git
git add README.md "${TOOL_NAME}/"
git commit -m "feat: Add new tool: ${TOOL_NAME}"
git push

echo
echo "🚀 Success! The '${TOOL_NAME}' tool has been registered in this repository."