#!/bin/sh
#
# tcp_stack_setup.sh
# Enable and switch between TCP stacks and congestion control algorithms
# on FreeBSD (e.g., rack/freebsd + cubic/newreno)
#

set -e

if [ $# -lt 1 ] || [ $# -gt 2 ]; then
    echo "Usage: $0 <rack|freebsd> [cubic|newreno]"
    exit 1
fi

STACK=$1
CC_ALG=${2:-cubic}   # default congestion control: cubic

VALID_STACKS="rack freebsd"
VALID_CCS="cubic newreno"

# --- 1. Validate inputs ------------------------------------------------------
if ! echo "$VALID_STACKS" | grep -qw "$STACK"; then
    echo "Error: Invalid TCP stack '$STACK'. Valid options: rack, freebsd"
    exit 1
fi

if ! echo "$VALID_CCS" | grep -qw "$CC_ALG"; then
    echo "Error: Invalid congestion control '$CC_ALG'. Valid options: cubic, newreno"
    exit 1
fi

echo ">>> Setting TCP stack to: $STACK"
echo ">>> Setting congestion control to: $CC_ALG"

# --- 2. Load modules if needed ----------------------------------------------
if [ "$STACK" = "rack" ]; then
    echo ">>> Loading RACK-related kernel modules..."
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

if [ "$CC_ALG" = "newreno" ]; then
    echo ">>> Loading NewReno congestion control module..."

    # Detect if already loaded
    if kldstat | grep -qw "cc_newreno.ko"; then
        echo "  - Module cc_newreno already loaded"
    else
        echo "  - Loading cc_newreno.ko"
        if ! kldload cc_newreno 2>&1 | tee /tmp/kld_cc_newreno.log; then
            if grep -q "already loaded or in kernel" /tmp/kld_cc_newreno.log; then
                echo "  - cc_newreno already built into kernel"
            else
                echo "ERROR: Failed to load cc_newreno"
                cat /tmp/kld_cc_newreno.log
                exit 1
            fi
        fi
    fi
fi

# --- 3. Check available TCP stacks ------------------------------------------
echo ">>> Checking available TCP stacks..."
AVAILABLE_STACKS=$(sysctl -n net.inet.tcp.functions_available)

if ! echo "$AVAILABLE_STACKS" | grep -qw "$STACK"; then
    echo "ERROR: TCP stack '$STACK' not available on this system."
    echo "$AVAILABLE_STACKS"
    exit 1
fi

# --- 4. Switch TCP stack -----------------------------------------------------
echo ">>> Switching to TCP stack: $STACK"
sysctl net.inet.tcp.functions_default="$STACK"

# --- 5. Check available congestion control algorithms -----------------------
echo ">>> Checking available congestion control modules..."
AVAILABLE_CC=$(sysctl -n net.inet.tcp.cc.available)

if ! echo "$AVAILABLE_CC" | grep -qw "$CC_ALG"; then
    echo "ERROR: Congestion control '$CC_ALG' not available."
    echo "$AVAILABLE_CC"
    exit 1
fi

# --- 6. Switch congestion control -------------------------------------------
echo ">>> Switching to congestion control algorithm: $CC_ALG"
sysctl net.inet.tcp.cc.algorithm="$CC_ALG"

# --- 7. Verify ---------------------------------------------------------------
echo ">>> Available TCP stacks:"
sysctl net.inet.tcp.functions_available
echo ">>> Available congestion control algorithms:"
sysctl net.inet.tcp.cc.available

echo ">>> Verifying configuration..."
sysctl net.inet.tcp.functions_default
sysctl net.inet.tcp.cc.algorithm

echo ">>> TCP stack '$STACK' with congestion control '$CC_ALG' successfully enabled."
