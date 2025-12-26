#!/bin/sh
# Check syntax of all scripts

echo "Checking script syntax..."
echo ""

ERRORS=0
for file in modules/*.sh main-installer.sh; do
    if [ -f "$file" ]; then
        if bash -n "$file" 2>/dev/null; then
            echo "✓ $(basename $file)"
        else
            echo "✗ $(basename $file)"
            ERRORS=$((ERRORS + 1))
        fi
    fi
done

echo ""
if [ $ERRORS -eq 0 ]; then
    echo "✅ All scripts have valid syntax"
else
    echo "❌ Found $ERRORS script(s) with syntax errors"
    exit 1
fi
