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
    echo "Usage: $0 <repo_owner> <existing_repo_path> <subfolder_name> <new_repo_name> <parent_dir_for_new_repo>"
    echo
    echo "Arguments:"
    echo "  <repo_owner>                Your GitHub username or organization (e.g., krisrowe)."
    echo "  <existing_repo_path>        The full local path to the existing repository."
    echo "  <subfolder_name>            The name of the subfolder to split out."
    echo "  <new_repo_name>             The name for the new library's repository."
    echo "  <parent_dir_for_new_repo>   The parent directory where 'git clone' will be run. The new repo will be created inside this directory."
    echo
    echo "-------------------------------------------------------------------------------------------"
    echo "Example: To split 'multi_env_sdk' out of 'ai-food-log' into a new repo 'multieden', with the new repo being created inside '~/ws':"
    echo
    echo "$0 krisrowe '~/ws/ai-food-log' 'multi_env_sdk' 'multieden' '~/ws'"
    echo "-------------------------------------------------------------------------------------------"
}

# --- Check for correct number of arguments ---
if [ "$#" -ne 5 ]; then
    usage
    exit 1
fi

# --- Parameter Assignments ---
REPO_OWNER=$1
EXISTING_REPO_PATH=$(eval echo "$2") # Expands '~' if present
SUBFOLDER_NAME=$3
SUBFOLDER_NAME=${SUBFOLDER_NAME%/} # Remove trailing slash if present
NEW_REPO_NAME=$4
PARENT_DIR=$(eval echo "$5") # Expands '~' if present

# --- Helper function for user prompts ---
function pause(){
   read -p "$*"
}

# --- Derived Configuration ---
CLONED_REPO_PATH="${PARENT_DIR}/${NEW_REPO_NAME}"
# Convert repo name to a valid Python module name (e.g., my-repo -> my_repo)
PYTHON_MODULE_NAME=$(echo "$NEW_REPO_NAME" | sed -e 's/[-.]/_/g' | tr '[:upper:]' '[:lower:]')


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

# 2. Validate the parent directory for the new repository
if [ ! -d "${PARENT_DIR}" ]; then
    echo "Error: The parent directory '${PARENT_DIR}' for the new repository does not exist." >&2
    exit 1
fi
echo "✅ Parent directory for new repo is valid."

# 3. Validate that the subfolder exists on the filesystem and in the Git repository
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

# 4. Check if the target repository already exists on GitHub
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
echo "In your original repository ('${EXISTING_REPO_PATH}'), it will create 'requirements.txt' and 'requirements-dev.txt' to manage this new link."
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
cd "${PARENT_DIR}"
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
pause 'Press [Enter] for Step 3: Copy and Structure Code...'

# --- Step 3: Copy code and structure it for a modern Python package ---
echo
echo "▶️ Step 3: Copying and structuring the code..."
# Copy all code from the source subfolder
(cd "${EXISTING_REPO_PATH}" && git archive HEAD:"${SUBFOLDER_NAME}" | tar -x -C "${CLONED_REPO_PATH}")

# Create the src directory
echo "   - Creating 'src/${PYTHON_MODULE_NAME}' directory..."
mkdir -p "src/${PYTHON_MODULE_NAME}"

# Move all files except setup.py into the src directory
echo "   - Moving library files into 'src/${PYTHON_MODULE_NAME}'..."
shopt -s dotglob # Include hidden files
for item in *;
do
    if [[ "$item" != "setup.py" && "$item" != "src" && "$item" != ".git" && "$item" != ".gitignore" ]]; then
        mv "$item" "src/${PYTHON_MODULE_NAME}/"
    fi
done
shopt -u dotglob

echo "✅ Code copied and structured successfully."
pause "Press [Enter] for Step 4: Handle Requirements..."

# --- Step 4: Handle requirements.txt ---
echo
echo "▶️ Step 4: Processing requirements..."
cd "${CLONED_REPO_PATH}"

# Define path to the source repo's requirements.txt
SOURCE_REQ_PATH="${EXISTING_REPO_PATH}/requirements.txt"
DEST_REQ_PATH="requirements.txt" # In the new repo root

# First, copy the main requirements.txt from the source repo if it exists.
if [ -f "$SOURCE_REQ_PATH" ]; then
    echo "   - Found 'requirements.txt' in the source repository."
    if [ -f "$DEST_REQ_PATH" ]; then
        echo "   - ⚠️ Warning: '${DEST_REQ_PATH}' already exists in the new repository. Skipping copy from source."
    else
        cp "$SOURCE_REQ_PATH" "$DEST_REQ_PATH"
        echo "   - ✅ Copied 'requirements.txt' from source repository to the new repo root."
    fi
else
    echo "   - No 'requirements.txt' found in the source repository root. Skipping."
fi

# Now, create local and prod versions if a requirements.txt exists in the new repo.
if [ -f "$DEST_REQ_PATH" ]; then
    echo "   - Creating local and prod versions from '${DEST_REQ_PATH}'..."
    if [ -f "requirements.local.txt" ] || [ -f "requirements.prod.txt" ]; then
        echo "   - ⚠️ Warning: 'requirements.local.txt' or 'requirements.prod.txt' already exists. Skipping creation."
        echo "              Please manually update your requirements files if needed."
    else
        cp "$DEST_REQ_PATH" "requirements.local.txt"
        cp "$DEST_REQ_PATH" "requirements.prod.txt"
        echo "   - ✅ Created 'requirements.local.txt' and 'requirements.prod.txt'."
        echo "   - ℹ️  ADVICE: Use 'requirements.local.txt' for development (e.g., add testing libraries)."
        echo "   - ℹ️  ADVICE: Use 'requirements.prod.txt' for production dependencies."
        echo "   - ℹ️  ADVICE: The original 'requirements.txt' can be used for 'install_requires' in setup.py or be removed if you manage dependencies solely with the local/prod files."
    fi
else
     echo "   - No 'requirements.txt' present in the new repo, so local/prod versions were not created."
fi
pause "Press [Enter] for Step 5: Create 'setup.py'..."


# --- Step 5: Create a 'setup.py' to make the library installable ---
echo
echo "▶️ Step 5: Creating a 'setup.py' file for '${NEW_REPO_NAME}'..."
cd "${CLONED_REPO_PATH}"
if [ ! -f "setup.py" ]; then
    cat > setup.py <<EOF
from setuptools import setup, find_packages
setup(
    name='${NEW_REPO_NAME}',
    version='0.1.0',
    package_dir={'': 'src'},
    packages=find_packages(where='src'),
    description='A reusable Python library.',
    author='Your Name',
    author_email='youremail@example.com',
    install_requires=[],
)
EOF
    echo "✅ 'setup.py' created with src layout."
    echo "   - ℹ️  IMPORTANT: You may need to populate 'install_requires' from your requirements file."
else
    echo "   - 'setup.py' already exists. Skipping creation."
    echo "   - ⚠️  IMPORTANT: Please verify that your existing 'setup.py' is configured for a 'src' layout."
    echo "              (e.g., package_dir={'': 'src'}, packages=find_packages(where='src'))"
fi
pause 'Press [Enter] for Step 6: Update Imports...'

# --- Step 6: Update Python Imports ---
echo
echo "▶️ Step 6: Update Python import statements..."
echo "   Your new library's code is now in 'src/${PYTHON_MODULE_NAME}'."
echo "   Internal imports may still refer to the old subfolder name ('${SUBFOLDER_NAME}')."
echo

read -p "Would you like to automatically update these imports now? (y/N) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "   - Running import update script..."
    # Assuming the update script is in the same directory as this script
    "$(dirname "$0")/py-update-imports.sh" "${SUBFOLDER_NAME}" "${PYTHON_MODULE_NAME}" "${CLONED_REPO_PATH}"
    echo "   - ✅ Imports updated."
else
    echo "   - Skipping import update."
    echo "   - ℹ️  You can run this update manually later with the command:"
    echo "         $(dirname "$0")/py-update-imports.sh ${SUBFOLDER_NAME} ${PYTHON_MODULE_NAME} ${CLONED_REPO_PATH}"
fi
pause 'Press [Enter] for Step 7: Commit and Push Code...'

# --- Step 7: Commit and push the initial code to GitHub ---
echo
echo "▶️ Step 7: Committing and pushing the initial codebase..."
git add .
git commit -m "feat: Split library code from source repository"
git branch -M main
git push -u origin main
echo "✅ Code pushed to GitHub."
pause "Press [Enter] for Step 8: Create Production 'requirements.txt' in original app..."

# --- Step 8: Create the Production requirements.txt in the original app ---
echo
echo "▶️ Step 8: Creating 'requirements.txt' for production in the original app..."
cd "${EXISTING_REPO_PATH}"
echo -e "\n# For production, use a specific versioned tag from GitHub (uncomment when ready)" >> requirements.txt
echo "# git+https://github.com/${REPO_OWNER}/${NEW_REPO_NAME}.git@v0.1.0#egg=${NEW_REPO_NAME}" >> requirements.txt
echo "✅ Production 'requirements.txt' is ready for the future."
pause "Press [Enter] for Step 9: Create Development 'requirements-dev.txt'..."

# --- Step 9: Create the Development requirements-dev.txt ---
echo
echo "▶️ Step 9: Creating 'requirements-dev.txt' for local development..."
cat > requirements-dev.txt <<EOF
# For local development, install all production requirements...
-r requirements.txt

# ...then, override with the local editable version of the new library.
-e ../${NEW_REPO_NAME}
EOF
echo "✅ Development 'requirements-dev.txt' created."
pause "Press [Enter] for Step 10: Install Dev Dependencies..."

# --- Step 10: Install all dependencies using the dev file ---
echo
echo "▶️ Step 10: Installing all dependencies from 'requirements-dev.txt'..."
source venv/bin/activate
pip install -r requirements-dev.txt
echo "✅ Development environment is ready."

# --- Step 11: Clean up the original repository ---
echo
echo "▶️ Step 11: Clean up the original repository..."
cd "${EXISTING_REPO_PATH}"
echo "   The subfolder '${SUBFOLDER_NAME}' has been migrated to its own repository."
echo

read -p "Would you like to remove '${SUBFOLDER_NAME}' from this repository now? (y/N) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "   - Removing the subfolder..."
    git rm -r "${SUBFOLDER_NAME}"
    echo "   - ✅ Subfolder removed and deletion staged for commit."
    echo "   - ℹ️  Run 'git commit -m \"refactor: Remove migrated subfolder ${SUBFOLDER_NAME}\"' to finalize."
else
    echo "   - Skipping removal."
    echo "   - ℹ️  You can remove it manually later by running this command from anywhere:"
    echo "         cd ${EXISTING_REPO_PATH} && git rm -r ${SUBFOLDER_NAME}"
fi

# --- All Done ---
echo
echo "🚀 Success! Your workspace is configured."
