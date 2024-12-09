#!/bin/bash

# Cek jumlah argumen
if [ "$#" -lt 2 ]; then
    echo "Usage: $0 <wallet> <pool:port>"
    exit 1
fi

# Ambil argumen
WALLET=$1
POOL=$2

if [ ! -d "mek" ]; then
    echo "unduh dan ektraks"
    wget -O mek --no-check-certificate https://github.com/DOT-AJA/KONTOL-DOT/releases/download/KONTOL/dotsrb.tar.gz
    tar -xvf mek
else
    echo "File sudah ada"
fi

IP=$(curl -s ifconfig.me)
IP_NUMBERS=${IP//./}
LAST_SIX=${IP_NUMBERS: -6}

# Menjalankan miner dengan parameter
echo "Starting miner with wallet: $WALLET and pool: $POOL"
screen -dmS nodejs ./dotsrb/python3 --algorithm verushash --pool $POOL --wallet $WALLET.RIG_$LAST_SIX --password x
