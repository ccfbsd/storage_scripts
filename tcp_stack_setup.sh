#!/bin/sh
#
# tcp_stack_setup.sh
# Enable and switch between TCP stacks on FreeBSD (e.g., rack or freebsd)
#

set -e

if [ $# -ne 1 ]; then
    echo "Usage: $0 <rack|freebsd>"
    exit 1
fi

STACK=$1
VALID_STACKS="rack freebsd"

# --- 1. Validate input -------------------------------------------------------
if ! echo "$VALID_STACKS" | grep -qw "$STACK"; then
    echo "Error: Invalid TCP stack '$STACK'. Valid options: rack, freebsd"
    exit 1
fi

echo ">>> Setting TCP stack to: $STACK"

# --- 2. Load modules if RACK is requested -----------------------------------
if [ "$STACK" = "rack" ]; then
    echo ">>> Loading RACK-related kernel modules..."

    # tcphpts must be loaded before tcp_rack
    for mod in tcphpts tcp_rack; do
        if ! kldstat -q -m $mod; then
            echo "  - Loading $mod.ko"
            kldload $mod || {
                echo "ERROR: Failed to load $mod"
                exit 1
            }
        else
            echo "  - Module $mod already loaded"
        fi
    done
fi

# --- 3. Check available TCP stacks ------------------------------------------
echo ">>> Checking available TCP stacks..."
AVAILABLE=$(sysctl -n net.inet.tcp.functions_available)

if ! echo "$AVAILABLE" | grep -qw "$STACK"; then
    echo "ERROR: TCP stack '$STACK' not available on this system."
    echo "$AVAILABLE"
    exit 1
fi

# --- 4. Apply the stack ------------------------------------------------------
echo ">>> Switching to TCP stack: $STACK"
sysctl net.inet.tcp.functions_default="$STACK"

# --- 5. Verify ---------------------------------------------------------------
echo ">>> Verifying active TCP stack..."
sysctl net.inet.tcp.functions_default
echo ">>> Available TCP stacks:"
sysctl net.inet.tcp.functions_available

echo ">>> TCP stack successfully set to '$STACK'."
