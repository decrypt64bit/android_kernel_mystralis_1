#!/bin/bash

echo "--- 🔍 Starting KSU Integrity Check ---"

# 1. Check Config
echo -n "[ ] Checking RMX1971_defconfig... "
if grep -q "CONFIG_KSU=y" arch/arm64/configs/RMX1971_defconfig; then
    echo "✅ OK"
else
    echo "❌ MISSING (Run Phase 4 cat command)"
fi

# 2. Check fs/open.c
echo -n "[ ] Checking fs/open.c hooks... "
if grep -q "ksu_handle_faccessat" fs/open.c; then
    echo "✅ OK"
else
    echo "❌ MISSING (Check your edits in open.c)"
fi

# 3. Check fs/read_write.c
echo -n "[ ] Checking fs/read_write.c hooks... "
if grep -q "ksu_handle_sys_read" fs/read_write.c && grep -q "ksu_handle_sys_write" fs/read_write.c; then
    echo "✅ OK"
else
    echo "❌ MISSING (Ensure you added both read and write hooks)"
fi

# 4. Check for duplicate declarations (Common 4.9 error)
echo -n "[ ] Checking for duplicate KSU declarations... "
DUP_COUNT=$(grep -c "extern int ksu_handle_faccessat" fs/open.c)
if [ "$DUP_COUNT" -gt 1 ]; then
    echo "❌ FAILED (Found $DUP_COUNT declarations in open.c - remove duplicates!)"
else
    echo "✅ OK"
fi

# 5. Check Toolchain
echo -n "[ ] Checking Proton Clang... "
if [ -d "$HOME/proton-clang" ]; then
    echo "✅ OK"
else
    echo "❌ MISSING (Check ~/proton-clang path)"
fi

echo "--- 🏁 Check Complete ---"
