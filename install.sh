#!/bin/bash
set -e

# =======================================================
# MantaCil Interactive Installer
# =======================================================

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Helper for printing messages
print_info() { echo -e "${CYAN}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warn() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check for root
if [ "$EUID" -ne 0 ]; then 
  print_error "Harap jalankan skrip ini sebagai root (Gunakan: sudo bash install.sh)"
  exit 1
fi

clear
echo -e "${CYAN}"
echo "    __  ______    _   ____________   ______________  "
echo "   /  |/  /   |  / | / /_  __/   |  / ____/  _/ __ \\ "
echo "  / /|_/ / /| | /  |/ / / / / /| | / /    / // / / / "
echo " / /  / / ___ |/ /|  / / / / ___ |/ /____/ // /_/ /  "
echo "/_/  /_/_/  |_/_/ |_/ /_/ /_/  |_|\____/___/_____/   "
echo -e "${NC}"
echo -e "${BLUE}=======================================================${NC}"
echo -e "${GREEN}   Selamat Datang di Installer MantaCil!${NC}"
echo -e "${BLUE}=======================================================${NC}"
echo "Apa yang ingin Anda instal hari ini?"
echo "  [1] Install MantaCil Panel Saja"
echo "  [2] Install MantaCil Wings Saja"
echo "  [3] Install Keduanya (Panel + Wings + Egg WhatsApp)"
echo "  [4] Install MantaCil Security Toolkit (Anti-DDoS & Auto-Suspend)"
echo -e "${BLUE}=======================================================${NC}"

read -p "Pilih [1/2/3/4]: " INSTALL_CHOICE

case "$INSTALL_CHOICE" in
    1) DO_PANEL=true; DO_WINGS=false; DO_SEC=false ;;
    2) DO_PANEL=false; DO_WINGS=true; DO_SEC=false ;;
    3) DO_PANEL=true; DO_WINGS=true; DO_SEC=false ;;
    4) DO_PANEL=false; DO_WINGS=false; DO_SEC=true ;;
    *) print_error "Pilihan tidak valid!"; exit 1 ;;
esac

# Collect variables if Panel is selected
if [ "$DO_PANEL" = true ]; then
    echo ""
    echo -e "${YELLOW}--- Konfigurasi Panel ---${NC}"
    read -p "Masukkan IP Publik VPS atau Domain (contoh: 192.168.1.10 atau panel.mantacil.com): " APP_URL
    if [[ ! "$APP_URL" == http* ]]; then
        APP_URL="http://$APP_URL"
    fi
    
    read -p "Masukkan Email Admin (Default: admin@mantacil.com): " ADMIN_EMAIL
    ADMIN_EMAIL=${ADMIN_EMAIL:-admin@mantacil.com}
    
    read -p "Masukkan Username Admin (Default: admin): " ADMIN_USER
    ADMIN_USER=${ADMIN_USER:-admin}
    
    read -p "Masukkan Password Admin (Default: admin123): " ADMIN_PASS
    ADMIN_PASS=${ADMIN_PASS:-admin123}
    
    read -p "Masukkan Password Database MariaDB (Default: mantacil_secure): " DB_PASS
    DB_PASS=${DB_PASS:-mantacil_secure}
fi

echo ""
echo -e "${YELLOW}--- Konfirmasi ---${NC}"
if [ "$DO_PANEL" = true ]; then
    echo "Panel URL: $APP_URL"
    echo "Admin Email: $ADMIN_EMAIL"
fi
if [ "$DO_WINGS" = true ]; then
    echo "Wings: Yes (Port 8080/2022)"
fi
if [ "$DO_SEC" = true ]; then
    echo "Security Toolkit: Yes (Anti-DDoS Cronjob)"
fi
echo ""
read -p "Apakah data di atas sudah benar dan ingin memulai instalasi? [y/N]: " CONFIRM
if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    print_warn "Instalasi dibatalkan oleh pengguna."
    exit 0
fi

# ==========================================
# FUNCTION: INSTALL DEPENDENCIES
# ==========================================
install_dependencies() {
    print_info "Menginstal Dependensi Sistem (PHP, MariaDB, Nginx, Redis)..."
    apt update -y > /dev/null 2>&1
    apt -y install software-properties-common curl apt-transport-https ca-certificates gnupg > /dev/null 2>&1
    LC_ALL=C.UTF-8 add-apt-repository -y ppa:ondrej/php > /dev/null 2>&1
    curl -fsSL https://deb.nodesource.com/setup_18.x | bash - > /dev/null 2>&1
    curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - > /dev/null 2>&1
    echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list > /dev/null
    apt update -y > /dev/null 2>&1
    apt -y install php8.1 php8.1-{common,cli,gd,mysql,mbstring,bcmath,xml,fpm,curl,zip} mariadb-server nginx tar unzip git redis-server nodejs yarn > /dev/null 2>&1
    
    print_info "Menginstal Composer..."
    curl -sS https://getcomposer.org/installer | sudo php -- --install-dir=/usr/local/bin --filename=composer > /dev/null 2>&1
}

# ==========================================
# FUNCTION: INSTALL PANEL
# ==========================================
install_panel() {
    print_info "Menyiapkan Database..."
    mysql -u root -e "CREATE DATABASE IF NOT EXISTS panel;"
    mysql -u root -e "CREATE USER IF NOT EXISTS 'pterodactyl'@'127.0.0.1' IDENTIFIED BY '$DB_PASS';"
    mysql -u root -e "GRANT ALL PRIVILEGES ON panel.* TO 'pterodactyl'@'127.0.0.1' WITH GRANT OPTION;"
    mysql -u root -e "FLUSH PRIVILEGES;"

    print_info "Mendownload Panel MantaCil dari GitHub..."
    mkdir -p /var/www/mantacil
    git clone https://github.com/aisantri17/mantacil-panel.git /var/www/mantacil > /dev/null 2>&1
    cd /var/www/mantacil
    chmod -R 755 storage/* bootstrap/cache/

    print_info "Mengonfigurasi Lingkungan (.env)..."
    cp .env.example .env
    sed -i "s|APP_URL=http://localhost|APP_URL=$APP_URL|g" .env
    sed -i "s/DB_PASSWORD=/DB_PASSWORD=$DB_PASS/g" .env

    print_info "Menjalankan Composer Install (Proses ini memakan waktu beberapa menit)..."
    COMPOSER_ALLOW_SUPERUSER=1 composer install --no-dev --optimize-autoloader > /dev/null 2>&1

    print_info "Generate Application Key..."
    php artisan key:generate --force > /dev/null

    print_info "Migrasi & Seed Database..."
    php artisan migrate --seed --force > /dev/null

    print_info "Membangun Frontend Panel (React)..."
    yarn install > /dev/null 2>&1
    yarn build:production > /dev/null 2>&1

    print_info "Membuat Akun Admin..."
    php artisan p:user:make --email="$ADMIN_EMAIL" --username="$ADMIN_USER" --name-first="MantaCil" --name-last="Admin" --password="$ADMIN_PASS" --admin=1 > /dev/null 2>&1 || true

    print_info "Mengimpor Egg WhatsApp Bot dari GitHub..."
    wget -qO /var/www/mantacil/egg-botwhatsapp.json https://raw.githubusercontent.com/aisantri17/mantacil-installer/main/egg-botwhatsapp.json
    if [ -f "egg-botwhatsapp.json" ]; then
        php artisan p:egg:import egg-botwhatsapp.json > /dev/null 2>&1 || print_warn "Impor egg gagal, harap lakukan manual di UI."
    fi

    print_info "Menyetel Hak Akses File..."
    chown -R www-data:www-data /var/www/mantacil/*

    print_info "Menyiapkan Cronjob..."
    (crontab -l 2>/dev/null; echo "* * * * * php /var/www/mantacil/artisan schedule:run >> /dev/null 2>&1") | crontab -

    print_info "Menyiapkan Nginx VirtualHost..."
    cat << EOF > /etc/nginx/sites-available/mantacil.conf
server {
    listen 80;
    server_name _;
    root /var/www/mantacil/public;
    index index.html index.htm index.php;
    charset utf-8;
    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }
    location = /favicon.ico { access_log off; log_not_found off; }
    location = /robots.txt  { access_log off; log_not_found off; }
    access_log off;
    error_log  /var/log/nginx/mantacil.app-error.log error;
    client_max_body_size 100m;
    client_body_timeout 120s;
    sendfile off;
    location ~ \.php$ {
        fastcgi_split_path_info ^(.+\.php)(/.+)$;
        fastcgi_pass unix:/run/php/php8.1-fpm.sock;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param PHP_VALUE "upload_max_filesize = 100M \n post_max_size=100M";
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        fastcgi_param HTTP_PROXY "";
        fastcgi_intercept_errors off;
        fastcgi_buffer_size 16k;
        fastcgi_buffers 4 16k;
        fastcgi_connect_timeout 300;
        fastcgi_send_timeout 300;
        fastcgi_read_timeout 300;
    }
    location ~ /\.ht {
        deny all;
    }
}
EOF
    ln -sf /etc/nginx/sites-available/mantacil.conf /etc/nginx/sites-enabled/
    rm -f /etc/nginx/sites-enabled/default
    systemctl restart nginx > /dev/null 2>&1
    
    print_info "Menyiapkan MantaCil Pterodactyl Queue Worker..."
    cat << EOF > /etc/systemd/system/pteroq.service
[Unit]
Description=MantaCil Queue Worker
After=redis-server.service

[Service]
User=www-data
Group=www-data
Restart=always
ExecStart=/usr/bin/php /var/www/mantacil/artisan queue:work --queue=high,standard,low --sleep=3 --tries=3
StartLimitInterval=180
StartLimitBurst=30
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF
    systemctl enable --now pteroq.service > /dev/null 2>&1
}

# ==========================================
# FUNCTION: INSTALL WINGS
# ==========================================
install_wings() {
    print_info "Menginstal Docker CE..."
    curl -sSL https://get.docker.com/ | CHANNEL=stable bash > /dev/null 2>&1
    systemctl enable --now docker > /dev/null 2>&1

    print_info "Memasang MantaCil Wings dari GitHub..."
    cd /root
    git clone https://github.com/aisantri17/mantacil-wings.git > /dev/null 2>&1
    cd mantacil-wings
    chmod +x mantacil-wings
    cp mantacil-wings /usr/local/bin/mantacil-wings
    mkdir -p /etc/pterodactyl

    print_info "Mengonfigurasi Wings Service (Systemd)..."
    cat << 'EOF' > /etc/systemd/system/mantacil-wings.service
[Unit]
Description=MantaCil Wings Daemon
After=docker.service
Requires=docker.service
PartOf=docker.service

[Service]
User=root
WorkingDirectory=/etc/pterodactyl
LimitNOFILE=4096
PIDFile=/var/run/wings/daemon.pid
ExecStart=/usr/local/bin/mantacil-wings
Restart=on-failure
StartLimitInterval=180
StartLimitBurst=30
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF

    systemctl enable mantacil-wings > /dev/null 2>&1
}

# ==========================================
# FUNCTION: INSTALL SECURITY TOOLKIT
# ==========================================
install_security() {
    print_info "Menginstal MantaCil Security Toolkit..."
    wget -qO /usr/local/bin/mantacil-security.sh https://raw.githubusercontent.com/aisantri17/mantacil-installer/main/mantacil-security.sh
    chmod +x /usr/local/bin/mantacil-security.sh
    
    print_info "Menyiapkan Cronjob Security (Berjalan setiap 5 menit)..."
    (crontab -l 2>/dev/null | grep -v "mantacil-security.sh"; echo "*/5 * * * * /usr/local/bin/mantacil-security.sh") | crontab -
    
    print_success "Security Toolkit berhasil diinstal! Log akan tersimpan di /var/log/mantacil_security.log"
}

# ==========================================
# EXECUTION
# ==========================================
clear
echo -e "${BLUE}=======================================================${NC}"
echo -e "${GREEN}Mulai memproses instalasi... Mohon tunggu.${NC}"
echo -e "${BLUE}=======================================================${NC}"

if [ "$DO_PANEL" = true ]; then
    install_dependencies
    install_panel
fi

if [ "$DO_WINGS" = true ]; then
    install_wings
fi

if [ "$DO_SEC" = true ]; then
    install_security
fi

echo ""
echo -e "${GREEN}=======================================================${NC}"
echo -e "${GREEN}      INSTALASI MANTACIL SELESAI DENGAN SUKSES! 🦅🟢     ${NC}"
echo -e "${GREEN}=======================================================${NC}"

if [ "$DO_PANEL" = true ]; then
    echo -e "Akses Panel MantaCil Anda di: ${CYAN}$APP_URL${NC}"
    echo -e "Login Email    : ${YELLOW}$ADMIN_EMAIL${NC}"
    echo -e "Login Password : ${YELLOW}$ADMIN_PASS${NC}"
    echo ""
fi

if [ "$DO_WINGS" = true ]; then
    echo -e "${CYAN}--- Langkah Konfigurasi Node ---${NC}"
    echo -e "1. Login ke Panel, masuk ke menu Admin -> Nodes."
    echo -e "2. Buat Node baru, lalu di tab Configuration, salin perintah ${YELLOW}Generate Token${NC}."
    echo -e "3. Tempel (paste) perintah tersebut di terminal ini."
    echo -e "4. Terakhir, ketik: ${YELLOW}systemctl start mantacil-wings${NC}"
fi
echo -e "${GREEN}=======================================================${NC}"
