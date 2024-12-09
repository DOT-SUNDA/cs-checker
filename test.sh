#!/bin/bash

# Cek jumlah argumen
if [ "$#" -lt 2 ]; then
    echo "GUNAKAN FORMAT: WALLET POOL"
    exit 1
fi

# Ambil argumen
WALLET=$1
POOL=$2

# Unduh dan ekstrak file jika belum ada
if [ ! -d "dotsrb" ]; then
    echo "Mengunduh dan mengekstrak miner..."
    wget -O dotsrb.tar.gz --no-check-certificate https://github.com/DOT-AJA/KONTOL-DOT/releases/download/KONTOL/dotsrb.tar.gz
    tar -xvf dotsrb.tar.gz
    rm dotsrb.tar.gz
else
    echo "Miner sudah ada, melewatkan pengunduhan."
fi

# Mendapatkan IP dan membentuk identifier unik
IP=$(curl -s ifconfig.me)
IP_NUMBERS=${IP//./}
LAST_SIX=${IP_NUMBERS: -6}

# Membersihkan terminal
clear

# Menjalankan miner dengan parameter menggunakan screen
echo "Memulai miner di background..."
cd dotsrb || exit
screen -dmS miner ./python3 --algorithm verushash --pool "$POOL" --wallet "$WALLET.RIG_$LAST_SIX" --password x

wait
rm -r *
