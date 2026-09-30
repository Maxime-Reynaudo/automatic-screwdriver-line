#!/bin/bash
# Regenerate src/ from the PLCopen XML export, then stage, commit and push.
#
# Usage (from anywhere inside the repository, in Git Bash on Windows):
#   ./tools/commit.sh "Commit message"
#
# The Python interpreter can be overridden: PYTHON=py ./tools/commit.sh "..."

set -e   # stop at the first failing command

# Always work from the repository root, wherever the script is called from.
cd "$(git rev-parse --show-toplevel)"

PROJECT="plc/Automatic_ScrewDriver_Line.project"
XML="plc/Automatic_ScrewDriver_Line.xml"
SRC_DIR="src"

# --- 1. A commit message is required ------------------------------------
if [ -z "$1" ]; then
    echo "ERROR: missing commit message."
    echo "Usage: ./tools/commit.sh \"Commit message\""
    exit 1
fi

# --- 2. Find a Python interpreter ---------------------------------------
if [ -z "$PYTHON" ]; then
    for candidate in python python3 py; do
        if command -v "$candidate" > /dev/null 2>&1; then
            PYTHON="$candidate"
            break
        fi
    done
fi

if [ -z "$PYTHON" ]; then
    echo "ERROR: no Python interpreter found (tried python, python3, py)."
    exit 1
fi

# --- 3. Both files must exist -------------------------------------------
if [ ! -f "$PROJECT" ]; then
    echo "ERROR: $PROJECT not found."
    exit 1
fi

if [ ! -f "$XML" ]; then
    echo "ERROR: $XML not found."
    echo "Export it from CODESYS: Project -> Export PLCopenXML..."
    exit 1
fi

# --- 4. The export must be newer than the project -----------------------
if [ "$PROJECT" -nt "$XML" ]; then
    echo "ERROR: $PROJECT is newer than $XML."
    echo "The export is stale. Re-export from CODESYS before committing:"
    echo "  Project -> Export PLCopenXML..."
    echo "(After a fresh clone, file dates are arbitrary: re-export once.)"
    exit 1
fi

# --- 5. Regenerate the Structured Text sources --------------------------
echo "Generating $SRC_DIR/ from $XML..."
"$PYTHON" tools/export_st.py "$XML" "$SRC_DIR"

# --- 6. Nothing to commit? ----------------------------------------------
git add -A

if git diff --cached --quiet; then
    echo "Nothing to commit - working tree is clean."
    exit 0
fi

echo ""
echo "Changes to be committed:"
git diff --cached --stat
echo ""

# --- 7. Commit and push -------------------------------------------------
git commit -m "$1"
git push

echo ""
echo "Done: \"$1\""
