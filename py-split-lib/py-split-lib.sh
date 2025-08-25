#!/bin/bash
# =============================================================================
#
# split-lib.sh: A reusable script to split a subfolder out of an existing
#               Git repository into a new, standalone repository for reusable code.
#
# It performs all local validations upfront before creating any new repositories.
#
# =============================================================================

# --- Immediately exit the script if any command fails ---
set -e

# --- Usage function to display help text ---
usage() {
    echo "Usage: $0 <repo_owner> <existing_repo_path> <subfolder_name> <new_repo_name>"
    echo
    echo "Arguments:"
    echo "  <repo_owner>           Your GitHub username or organization (e.g., krisrowe)."
    echo "  <existing_repo_path>   The full local path to the existing repository."
    echo "  <subfolder_name>       The name of the subfolder to split out."
    echo "  <new_repo_name>        The name for the new library's repository."
    echo
    echo "-------------------------------------------------------------------------------------------"
    echo "Example: To split 'multi_env_sdk' out of 'ai-food-log' into 'multieden':"
    echo
    echo "$0 krisrowe '~/ws/ai-food-log' 'multi_env_sdk' 'multieden'"
    echo "-------------------------------------------------------------------------------------------"
}

# --- Check for correct number of arguments ---
if [ "$#" -ne 4 ]; then
    usage
    exit 1
fi

# --- Parameter Assignments ---
REPO_OWNER=$1
EXISTING_REPO_PATH=$(eval echo "$2") # Expands '~' if present
SUBFOLDER_NAME=$3
NEW_REPO_NAME=$4

# --- Helper function for user prompts ---
function pause(){
   read -p "$*"
}

# --- Derived Configuration ---
WORKSPACE_DIR=$(dirname "${EXISTING_REPO_PATH}")
CLONED_REPO_PATH="${WORKSPACE_DIR}/${NEW_REPO_NAME}"

# =============================================================================
# --- Pre-flight Checks ---
# All validations are performed here before any actions are taken.
# =============================================================================
echo "▶️ Performing pre-flight checks..."

# 1. Validate the source repository path
if [ ! -d "${EXISTING_REPO_PATH}" ]; then
    echo "Error: The provided path '${EXISTING_REPO_PATH}' does not exist." >&2
    exit 1
fi
if [ ! -d "${EXISTING_REPO_PATH}/.git" ]; then
    echo "Error: The provided path '${EXISTING_REPO_PATH}' is not a valid Git repository." >&2
    exit 1
fi
echo "✅ Source repository is valid."

# 2. Validate that the subfolder exists on the filesystem and in the Git repository
if [ ! -d "${EXISTING_REPO_PATH}/${SUBFOLDER_NAME}" ]; then
    echo "Error: Source subfolder '${EXISTING_REPO_PATH}/${SUBFOLDER_NAME}' does not exist on the filesystem." >&2
    exit 1
fi
if ! (cd "${EXISTING_REPO_PATH}" && git ls-tree -d HEAD "${SUBFOLDER_NAME}" >/dev/null 2>&1); then
    echo "Error: Subfolder '${SUBFOLDER_NAME}' does not exist in the HEAD commit of '${EXISTING_REPO_PATH}'." >&2
    echo "Please check for typos and ensure your latest changes are committed." >&2
    exit 1
fi
echo "✅ Subfolder '${SUBFOLDER_NAME}' found."

# 3. Check if the target repository already exists on GitHub
REPO_EXISTS=false
if gh repo view "${REPO_OWNER}/${NEW_REPO_NAME}" >/dev/null 2>&1; then
    REPO_EXISTS=true
    echo "⚠️  Warning: A repository named '${REPO_OWNER}/${NEW_REPO_NAME}' already exists on GitHub."

    # Check the contents of the repository
    CONTENTS=$(gh api "repos/${REPO_OWNER}/${NEW_REPO_NAME}/contents" 2>/dev/null)

    if [[ -z "$CONTENTS" || "$CONTENTS" == "[]" ]]; then
        # The repository is completely empty (no commits).
        echo "✅ The existing repository is empty and is safe to use."
    else
        # The repository has contents. Check if it's only a .gitignore file.
        OTHER_FILES_COUNT=$(echo "$CONTENTS" | jq '[.[] | select(.name != ".gitignore")] | length')
        if [[ "$OTHER_FILES_COUNT" -eq 0 ]]; then
            echo "✅ The existing repository only contains a .gitignore file and is safe to use."
        else
            echo "Error: The existing repository contains files other than .gitignore. To prevent data loss, this script must start with a new or empty repository." >&2
            exit 1
        fi
    fi
else
    echo "✅ Target repository '${NEW_REPO_NAME}' is available on GitHub."
fi
echo "------------------------------------------------------------------"


# --- Introduction ---
echo "✅ This script will set up your '${NEW_REPO_NAME}' library and link it to '${EXISTING_REPO_PATH}'."
echo "It will create two files: 'requirements.txt' for production and 'requirements-dev.txt' for local work."
echo "------------------------------------------------------------------"
pause 'Press [Enter] to begin...'

# --- Step 1: Create a new, public repository on GitHub (if needed) ---
if [ "$REPO_EXISTS" = false ]; then
    echo
    echo "▶️ Step 1: Creating a new public repository named '${NEW_REPO_NAME}' under '${REPO_OWNER}'..."
    gh repo create "${REPO_OWNER}/${NEW_REPO_NAME}" --public --description "A reusable Python library." --gitignore Python
    echo "✅ Done."
else
    echo
    echo "▶️ Step 1: Skipped. Using existing empty repository."
fi


# --- Step 2: Clone the repository into your workspace ---
echo
echo "▶️ Step 2: Cloning the repository..."
cd "${WORKSPACE_DIR}"
if [ -d "${CLONED_REPO_PATH}" ]; then
    echo "   - Directory '${CLONED_REPO_PATH}' already exists."
    # Check for unexpected files. We allow only .git and .gitignore
    shopt -s dotglob # Include hidden files in globbing
    HAS_OTHER_FILES=false
    for item in "${CLONED_REPO_PATH}"/*;
    do
        # Check if the item exists to handle empty directories
        [ -e "$item" ] || continue
        base_item=$(basename "$item")
        if [[ "$base_item" != ".git" && "$base_item" != ".gitignore" ]]; then
            echo "   - Error: The directory contains an unexpected item: $base_item" >&2
            HAS_OTHER_FILES=true
            break # No need to check further
        fi
    done
    shopt -u dotglob # Reset globbing option

    if [ "$HAS_OTHER_FILES" = true ]; then
        exit 1
    fi
    echo "   - The directory is clean (only .git and/or .gitignore found), which is safe to use."
    cd "${CLONED_REPO_PATH}"
else
    git clone "https://github.com/${REPO_OWNER}/${NEW_REPO_NAME}.git"
    cd "${CLONED_REPO_PATH}"
fi
echo "✅ Successfully cloned to ${CLONED_REPO_PATH}"
pause 'Press [Enter] for Step 3: Copy Code...'

# --- Step 3: Copy code cleanly using 'git archive' ---
echo
echo "▶️ Step 3: Copying clean, version-controlled code from '${SUBFOLDER_NAME}'..."
(cd "${EXISTING_REPO_PATH}" && git archive HEAD:"${SUBFOLDER_NAME}" | tar -x -C "${CLONED_REPO_PATH}")
echo "✅ Code copied successfully."
pause "Press [Enter] for Step 4: Create 'setup.py'..."

# --- Step 4: Create a 'setup.py' to make the library installable ---
echo
echo "▶️ Step 4: Creating a 'setup.py' file for '${NEW_REPO_NAME}'..."
cd "${CLONED_REPO_PATH}"
if [ ! -f "setup.py" ]; then
    cat > setup.py <<EOF
from setuptools import setup, find_packages
setup(
    name='${NEW_REPO_NAME}',
    version='0.1.0',
    packages=find_packages(),
    description='A reusable Python library.',
    author='Your Name',
    author_email='youremail@example.com',
    install_requires=[],
)
EOF
    echo "✅ 'setup.py' created."
else
    echo "   - 'setup.py' already exists. Skipping creation."
fi
pause 'Press [Enter] for Step 5: Commit and Push Code...'

# --- Step 5: Commit and push the initial code to GitHub ---
echo
echo "▶️ Step 5: Committing and pushing the initial codebase..."
git add .
git commit -m "feat: Split library code from source repository"
git branch -M main
git push -u origin main
echo "✅ Code pushed to GitHub."
pause "Press [Enter] for Step 6: Create Production 'requirements.txt'..."

# --- Step 6: Create the Production requirements.txt ---
echo
echo "▶️ Step 6: Creating 'requirements.txt' for production in the original app..."
cd "${EXISTING_REPO_PATH}"
echo -e "\n# For production, use a specific versioned tag from GitHub (uncomment when ready)" >> requirements.txt
echo "# git+https://github.com/${REPO_OWNER}/${NEW_REPO_NAME}.git@v0.1.0#egg=${NEW_REPO_NAME}" >> requirements.txt
echo "✅ Production 'requirements.txt' is ready for the future."
pause "Press [Enter] for Step 7: Create Development 'requirements-dev.txt'..."

# --- Step 7: Create the Development requirements-dev.txt ---
echo
echo "▶️ Step 7: Creating 'requirements-dev.txt' for local development..."
cat > requirements-dev.txt <<EOF
# For local development, install all production requirements...
-r requirements.txt

# ...then, override with the local editable version of the new library.
-e ../${NEW_REPO_NAME}
EOF
echo "✅ Development 'requirements-dev.txt' created."
pause "Press [Enter] for Step 8: Install Dev Dependencies..."

# --- Step 8: Install all dependencies using the dev file ---
echo
echo "▶️ Step 8: Installing all dependencies from 'requirements-dev.txt'..."
source venv/bin/activate
pip install -r requirements-dev.txt
echo "✅ Development environment is ready."

# --- All Done ---
echo
echo "🚀 Success! Your workspace is configured."
