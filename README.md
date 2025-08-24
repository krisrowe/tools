# tools

A collection of development tools and reusable scripts. Each tool is contained in its own directory.

## Usage

This repository contains two primary management scripts:

- **`new-repo.sh`**: Used to create a brand new tools repository like this one. You typically only run this once.
- **`register-tool.sh`**: Used to add a new tool to this repository. You will run this script from the root of this repository clone every time you want to add a new tool.

### Registering a New Tool

To add a new tool to this repository, run the `register-tool.sh` utility from the root directory:

```bash
./register-tool.sh <tool-name> /path/to/your/script.sh "A short description of the tool."
```

## Registered Tools
