#!/bin/bash
# =============================================================================
#
# split-lib.sh: A reusable script to split a subfolder out of an existing
#               Git repository into a new, standalone repository for reusable code.
#
# It sets up a professional development environment with separate production
# and development requirement files for the original application.
#
# =============================================================================

# --- Immediately exit the script if any command fails ---
set -e

# --- Usage function to display help text ---
usage() {
    echo "Usage: $0 <repo_owner> <existing_repo_path> <subfolder_name> <new_repo_name>"
    echo
    echo "Arguments:"
    echo "  <repo_owner>           Your GitHub username or organization (e.g., acmecoders)."
    echo "  <existing_repo_path>   The full local path to the existing repository."
    echo "  <subfolder_name>       The name of the subfolder to split out."
    echo "  <new_repo_name>        The name for the new library's repository."
    echo
    echo "-------------------------------------------------------------------------------------------"
    echo "Example: To split 'multi_env_sdk' out of 'ai-food-log' into 'multieden':"
    echo
    echo "$0 acmecoders '~/ws/ai-food-log' 'multi_env_sdk' 'multieden'"
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
SOURCE_SUBFOLDER_DIR="${EXISTING_REPO_PATH}/${SUBFOLDER_NAME}"

# --- Introduction ---
echo "✅ This script will set up your '${NEW_REPO_NAME}' library and link it to '${EXISTING_REPO_PATH}'."
echo "It will create two files: 'requirements.txt' for production and 'requirements-dev.txt' for local work."
echo "------------------------------------------------------------------"
pause 'Press [Enter] to begin...'

# --- Step 0: Navigate to the Workspace ---
echo
echo "▶️ Step 0: Changing directory to workspace: ${WORKSPACE_DIR}"
cd "${WORKSPACE_DIR}"
echo "✅ Done."
pause "Press [Enter] for Step 1: Create GitHub Repo for '${NEW_REPO_NAME}'..."

# --- Step 1: Create a new, public repository on GitHub ---
echo
echo "▶️ Step 1: Creating a new public GitHub repository named '${NEW_REPO_NAME}' under '${REPO_OWNER}'..."
gh repo create "${REPO_OWNER}/${NEW_REPO_NAME}" --public --description "A reusable Python library."
echo "✅ Done."
pause 'Press [Enter] for Step 2: Clone Repo Locally...'

# --- Step 2: Clone the new, empty repository into your workspace ---
echo
echo "▶️ Step 2: Cloning the empty repository..."
git clone "https://github.com/${REPO_OWNER}/${NEW_REPO_NAME}.git"
echo "✅ Successfully cloned to ${WORKSPACE_DIR}/${NEW_REPO_NAME}"
pause 'Press [Enter] for Step 3: Copy Code...'

# --- Step 3: Copy the existing code into the new repo ---
echo
echo "▶️ Step 3: Copying code from ${SOURCE_SUBFOLDER_DIR}..."
cp -R "${SOURCE_SUBFOLDER_DIR}/"* "./${NEW_REPO_NAME}/"
echo "✅ Code copied successfully."
pause "Press [Enter] for Step 4: Create 'setup.py'..."

# --- Step 4: Create a 'setup.py' to make the library installable ---
echo
echo "▶️ Step 4: Creating a 'setup.py' file for '${NEW_REPO_NAME}'..."
cd "./${NEW_REPO_NAME}"
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
pause 'Press [Enter] for Step 5: Commit and Push Code...'

# --- Step 5: Commit and push the initial code to GitHub ---
echo
echo "▶️ Step 5: Committing and pushing the initial codebase for '${NEW_REPO_NAME}'..."
git add .
git commit -m "Initial commit of library code and setup configuration"
git push -u origin main
echo "✅ Code pushed to GitHub."
pause "Press [Enter] for Step 6: Create Production 'requirements.txt' in '${EXISTING_REPO_PATH##*/}'..."

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
# This file includes the production requirements and adds the local editable install.
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
echo "🚀 Success! Your workspace is configured with the standard two-file requirements system."
echo "For local work, your setup is complete."
echo "For production, commit a tagged version of the new library and uncomment the line in 'requirements.txt'."
