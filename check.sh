#!/bin/bash

# Warna untuk output terminal
RED="\e[31m"
GREEN="\e[32m"
ENDCOLOR="\e[0m"

# File berisi daftar IP
IP_LIST="ips.txt"

# File output untuk IP yang terbuka
OUTPUT_FILE="ipopen.txt"

# Port SSH yang akan diperiksa
SSH_PORT=22

# Nama file output untuk daftar IP
OUTPUT_FILE="ips.txt"

# Meminta input untuk IP base, START, dan END dengan nilai default
read -p "Masukkan IP base : " IP_BASE
IP_BASE=${IP_BASE:-94.156.202}

read -p "Masukkan nilai AWAL: " START
START=${START:-1}

read -p "Masukkan nilai AKHIR: " END
END=${END:-100}

# Hapus file jika sudah ada sebelumnya
if [[ -f $OUTPUT_FILE ]]; then
    rm $OUTPUT_FILE
fi

# Loop untuk membuat daftar IP
for i in $(seq $START $END); do
    echo "$IP_BASE.$i" >> $OUTPUT_FILE
done

echo "IP berhasil digenerate ke file $OUTPUT_FILE"

# Membersihkan layar
clear

# Bersihkan file output jika sudah ada sebelumnya
> $OUTPUT_FILE

# Fungsi untuk memeriksa status SSH
check_ssh() {
    local ip=$1
    timeout 3 bash -c "</dev/tcp/$ip/$SSH_PORT" &>/dev/null
    if [ $? -eq 0 ]; then
        echo -e "$ip:${GREEN} AKTIF ${ENDCOLOR}"
        echo "$ip" >> $OUTPUT_FILE
    else
        echo -e "$ip:${RED} CLOSED ${ENDCOLOR}"
    fi
}

# Periksa apakah file daftar IP ada
if [[ ! -f $IP_LIST ]]; then
    echo "File $IP_LIST tidak ditemukan!"
    exit 1
fi

# Loop melalui setiap IP di file untuk memeriksa status SSH
while IFS= read -r ip; do
    check_ssh "$ip"
done < "$IP_LIST"

echo "IP yang terbuka disimpan di $OUTPUT_FILE"

# Menghapus host SSH yang sudah dikenal
while IFS= read -r IP; do
    ssh-keygen -f "/home/codespace/.ssh/known_hosts" -R "$IP"
done < "$OUTPUT_FILE"

clear

# File berisi daftar IP yang terbuka
IP_LIST="ipopen.txt"

# Username dan password SSH
USERNAME="cloudsigma"
PASSWORD="Cloud2024"

# Fungsi untuk mencoba login SSH
check_ssh_login() {
    local ip=$1
    # Gunakan sshpass untuk mencoba login, simpan output untuk analisis
    OUTPUT=$(sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 "$USERNAME@$ip" exit 2>&1)
    
    # Periksa output
    if [[ "$OUTPUT" == *"Login Successful"* ]]; then
        echo -e "$ip:${GREEN} OPEN (Login Successful) ${ENDCOLOR}"
        echo "$ip" >> open_ips.txt
    elif [[ "$OUTPUT" == *"Your password has expired"* ]]; then
        echo -e "$ip:${GREEN} OPEN (Password Expired) ${ENDCOLOR}"
        echo "$ip" >> open_ips.txt
    elif [[ "$OUTPUT" == *"Permission denied"* ]]; then
        echo -e "$ip:${RED} CLOSED (Permission Denied) ${ENDCOLOR}"
    elif [[ "$OUTPUT" == *"Connection timed out"* || "$OUTPUT" == *"No route to host"* ]]; then
        echo -e "$ip:${RED} CLOSED (Host Unreachable) ${ENDCOLOR}"
    else
        echo -e "$ip:${RED} CLOSED (Unknown Error) ${ENDCOLOR}"
    fi
}

# Periksa apakah file daftar IP ada
if [[ ! -f $IP_LIST ]]; then
    echo "File $IP_LIST tidak ditemukan!"
    exit 1
fi

# Bersihkan file output sebelum digunakan
> open_ips.txt

# Loop melalui setiap IP di file untuk mencoba login SSH
while IFS= read -r ip; do
    echo "Memeriksa IP: $ip"
    check_ssh_login "$ip"
done < "$IP_LIST"

echo "IP yang terbuka disimpan di 'open_ips.txt'."
