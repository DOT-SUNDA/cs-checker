#!/bin/bash

# Warna untuk output terminal
RED="\e[31m"
GREEN="\e[32m"
ENDCOLOR="\e[0m"

# File untuk daftar IP yang digenerate
GENERATED_IPS="generated_ips.txt"

# File output untuk IP yang terbuka
OPEN_IPS="open_ips.txt"

# Port SSH yang akan diperiksa
SSH_PORT=22

# Meminta input untuk IP base, START, dan END dengan nilai default
read -p "Masukkan IP base (default: 94.156.202): " IP_BASE
IP_BASE=${IP_BASE:-94.156.202}

read -p "Masukkan nilai AWAL (default: 1): " START
START=${START:-1}

read -p "Masukkan nilai AKHIR (default: 100): " END
END=${END:-100}

# Bersihkan file output jika sudah ada sebelumnya
> "$GENERATED_IPS"
> "$OPEN_IPS"

# Hapus file jika sudah ada sebelumnya
if [[ -f $GENERATED_IPS ]]; then
    rm $GENERATED_IPS
fi

# Loop untuk membuat daftar IP
for i in $(seq "$START" "$END"); do
    echo "$IP_BASE.$i" >> "$GENERATED_IPS"
done

echo "IP berhasil digenerate ke file $GENERATED_IPS"
sleep 1

# Membersihkan layar
clear

# Fungsi untuk memeriksa status SSH
check_ssh() {
    local ip=$1
    if timeout 3 bash -c "</dev/tcp/$ip/$SSH_PORT" &>/dev/null; then
        echo -e "$ip:${GREEN} AKTIF ${ENDCOLOR}"
        echo "$ip" >> "$OPEN_IPS"
    else
        echo -e "$ip:${RED} CLOSED ${ENDCOLOR}"
    fi
}

# Periksa apakah file daftar IP ada
if [[ ! -f $GENERATED_IPS ]]; then
    echo "File $GENERATED_IPS tidak ditemukan!"
    exit 1
fi

# Loop melalui setiap IP di file untuk memeriksa status SSH
while IFS= read -r ip || [[ -n "$ip" ]]; do
    check_ssh "$ip"
done < "$GENERATED_IPS"

echo "IP yang terbuka disimpan di $OPEN_IPS"
sleep 1

# Menghapus host SSH yang sudah dikenal
if [[ -s $OPEN_IPS ]]; then
    while IFS= read -r ip || [[ -n "$ip" ]]; do
        ssh-keygen -f "/root/.ssh/known_hosts" -R "$ip" &>/dev/null
    done < "$OPEN_IPS"
fi

clear

# Username dan password SSH
USERNAME="cloudsigma"
PASSWORD="Cloud2025"

# Fungsi untuk mencoba login SSH
check_ssh_login() {
    local ip=$1
    OUTPUT=$(sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 "$USERNAME@$ip" exit 2>&1)
    
    if [[ "$OUTPUT" == *"Login Successful"* ]]; then
        echo -e "$ip:${GREEN} OPEN (Login Successful) ${ENDCOLOR}"
        echo "ssh $USERNAME@$ip" >> successful_logins.txt
    elif [[ "$OUTPUT" == *"Your password has expired"* ]]; then
        echo -e "$ip:${GREEN} OPEN (Password Expired) ${ENDCOLOR}"
        echo "ssh $USERNAME@$ip" >> successful_logins.txt
    elif [[ "$OUTPUT" == *"Permission denied"* ]]; then
        echo -e "$ip:${RED} CLOSED (Permission Denied) ${ENDCOLOR}"
    elif [[ "$OUTPUT" == *"Connection timed out"* || "$OUTPUT" == *"No route to host"* ]]; then
        echo -e "$ip:${RED} CLOSED (Host Unreachable) ${ENDCOLOR}"
    else
        echo -e "$ip:${RED} CLOSED (Unknown Error) ${ENDCOLOR}"
        echo "Debug Output: $OUTPUT" >> ssh_debug.log
    fi
}

# Periksa apakah file daftar IP yang terbuka ada
if [[ ! -f $OPEN_IPS || ! -s $OPEN_IPS ]]; then
    echo "File $OPEN_IPS tidak ditemukan atau kosong!"
    exit 1
fi

# Bersihkan file log debug sebelum digunakan
> ssh_debug.log

# Loop melalui setiap IP di file untuk mencoba login SSH
while IFS= read -r ip || [[ -n "$ip" ]]; do
    echo "Memeriksa IP: $ip"
    check_ssh_login "$ip"
done < "$OPEN_IPS"

echo "Pemeriksaan selesai. Detail login disimpan di 'ssh_debug.log'."
