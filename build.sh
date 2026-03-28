#!/bin/bash

# --- Configuration ---
CONF="RMX1971_defconfig"
OUT_DIR="out"
JOBS=8
LOG_FILE="build_error.log"

# --- Toolchain Paths ---
export PATH="$HOME/proton-clang/bin:$PATH"
export KBUILD_BUILD_USER="decrypt64bit"
export KBUILD_BUILD_HOST="arch-linux"

OPTS=(
    -j"$JOBS"
    O="$OUT_DIR"
    ARCH=arm64
    CC=clang
    HOSTCC=clang
    HOSTCXX=clang++
    LLVM=1
    LLVM_IAS=1
    CONFIG_LITTLE_CPU_MASK=63
    CONFIG_BIG_CPU_MASK=192
    CONFIG_CC_STACKPROTECTOR_NONE=y
    CLANG_TRIPLE=aarch64-linux-gnu-
    CROSS_COMPILE=aarch64-linux-gnu-
    CROSS_COMPILE_ARM32=arm-linux-gnueabi-
    HOSTCFLAGS="-fuse-ld=lld -Wno-unused-command-line-argument -Wno-unknown-warning-option"
)

# --- Smart Patching Engine ---
# This fixes the "prerequisites cannot be defined in recipes" error for Arch Linux
apply_patches() {
    echo "--- Applying Compatibility Patches ---"
    
    # 1. Fix techpack audio Makefiles (the common culprit)
    find techpack/audio -name "Makefile" -exec sed -i 's/::/:/g' {} +
    find techpack/audio -name "Makefile" -exec sed -i 's/\$(obj)\/\.builtin: /$(obj)\/.builtin: /g' {} +
    # Fix lines that start with a tab and contain a colon (recipe vs target confusion)
    find techpack/audio -name "Makefile" -exec sed -i '/^\t/s/: / : /g' {} +

    # 2. Fix scripts/Makefile.lib line 423/424
    if [ -f scripts/Makefile.lib ]; then
        sed -i '423s/:/ :/' scripts/Makefile.lib
        sed -i '424s/:/ :/' scripts/Makefile.lib
    fi

    # 3. Clean up offending Clang flags
    find scripts -type f -name "Makefile*" -exec sed -i 's/-Wno-undefined-optimized//g' {} +
    sed -i 's/-Wno-undefined-optimized//g' Makefile
}

# --- Build Process ---
echo "Starting smart build for Realme 5 Pro..."
apply_patches

echo "--- Initializing Config ---"
mkdir -p "$OUT_DIR"
make-4.3 "${OPTS[@]}" "$CONF" > /dev/null

echo "--- Forcing Default Configs ---"
yes "" | make-4.3 "${OPTS[@]}" oldconfig > /dev/null

echo "--- Starting Compilation ---"
# Capture standard error to a log file while still showing it on screen
make-4.3 "${OPTS[@]}" 2> >(tee "$LOG_FILE" >&2)

# --- Error Analysis ---
if [ $? -ne 0 ]; then
    echo -e "\n\e[31m[!] BUILD FAILED\e[0m"
    echo "--- Error Diagnosis ---"
    
    # Check for the specific Makefile.lib error
    if grep -q "prerequisites cannot be defined in recipes" "$LOG_FILE"; then
        ERROR_FILE=$(grep -B 1 "prerequisites cannot be defined in recipes" "$LOG_FILE" | head -n 1 | cut -d: -f1)
        echo "Cause: Incompatible 'make' version on Arch Linux."
        echo "Location: $ERROR_FILE (triggered by scripts/Makefile.lib:423)"
        echo "Action: The script attempted to patch this. Ensure your techpack/audio/ files don't have colons in tabbed lines."
    
    # Check for missing headers
    elif grep -q "file not found" "$LOG_FILE"; then
        MISSING_FILE=$(grep "file not found" "$LOG_FILE" | awk '{print $NF}')
        echo "Cause: Missing Header File ($MISSING_FILE)."
    
    # Check for compiler warning errors
    elif grep -q "Werror" "$LOG_FILE"; then
        echo "Cause: Warning treated as error."
        echo "Recommendation: Add -Wno-error to your HOSTCFLAGS in build.sh."
    fi
    
    echo -e "\nFull error log saved to: $LOG_FILE"
    exit 1
else
    echo -e "\n\e[32m[+] BUILD SUCCESSFUL\e[0m"
    exit 0
fi
