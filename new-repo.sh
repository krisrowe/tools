#!/bin/bash
# =============================================================================
#
# new-repo.sh: Creates a new GitHub repository for housing development tools.
#
# It initializes the repo with a main README and includes both this script
# and 'register-tool.sh' to make the new repository self-sufficient.
#
# =============================================================================
set -e

usage() {
    echo "Usage: $0 <github_user> <repo_name> [visibility]"
    echo
    echo "Arguments:"
    echo "  github_user      Your GitHub username or organization."
    echo "  repo_name        The name for the new repository (e.g., dev-tools)."
    echo "  visibility       (Optional) 'public' or 'private'. Defaults to 'private'."
    echo
    echo "Example: $0 acmecoders dev-tools private"
}

if [[ "$1" == "-h" || "$1" == "--help" || "$#" -lt 2 ]]; then
    usage
    exit 1
fi

# --- Parameters ---
GITHUB_USER=$1
REPO_NAME=$2
VISIBILITY=${3:-private} # Default to private if not specified

# --- Pre-flight Check ---
echo "▶️ Checking if repository '${GITHUB_USER}/${REPO_NAME}' already exists..."
if gh repo view "${GITHUB_USER}/${REPO_NAME}" >/dev/null 2>&1; then
    echo "Error: Repository '${GITHUB_USER}/${REPO_NAME}' already exists. This script is for creating new repositories only." >&2
    exit 1
fi

# --- Execution ---
echo "▶️ Creating ${VISIBILITY} repository '${GITHUB_USER}/${REPO_NAME}'..."
gh repo create "${GITHUB_USER}/${REPO_NAME}" --${VISIBILITY} --clone --description "A collection of development tools."

cd "${REPO_NAME}"

echo "▶️ Creating initial README.md and adding the management scripts..."

# Create the initial main README file with full usage instructions
cat > README.md <<EOF
# ${REPO_NAME}

A collection of development tools and reusable scripts. Each tool is contained in its own directory.

## Usage

This repository contains two primary management scripts:

- **\`new-repo.sh\`**: Used to create a brand new tools repository like this one. You typically only run this once.
- **\`register-tool.sh\`**: Used to add a new tool to this repository. You will run this script from the root of this repository clone every time you want to add a new tool.

### Registering a New Tool

To add a new tool to this repository, run the \`register-tool.sh\` utility from the root directory:

\`\`\`bash
./register-tool.sh <tool-name> /path/to/your/script.sh "A short description of the tool."
\`\`\`

## Registered Tools
EOF

# Copy both management scripts into the new repo
cp ../new-repo.sh .
cp ../register-tool.sh .
chmod +x new-repo.sh register-tool.sh

git add README.md new-repo.sh register-tool.sh
git commit -m "Initial commit: Add repo management scripts and README"

# Rename the local branch to 'main' to match modern standards
git branch -M main

git push -u origin main

echo
echo "🚀 Success! Your '${REPO_NAME}' repository is live."
echo "It includes 'new-repo.sh' and 'register-tool.sh', ready for use."