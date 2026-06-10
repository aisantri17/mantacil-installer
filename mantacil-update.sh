#!/bin/bash
# =======================================================
# MantaCil Auto-Update System
# =======================================================

LOG_FILE="/var/log/mantacil_update.log"
echo "[$(date)] Memeriksa pembaruan MantaCil..." >> $LOG_FILE

# 1. Update Panel (Jika diinstal)
if [ -d "/var/www/mantacil" ]; then
    cd /var/www/mantacil
    
    # Cek apakah ada perubahan di remote repository
    git fetch origin main > /dev/null 2>&1
    LOCAL=$(git rev-parse HEAD)
    REMOTE=$(git rev-parse origin/main)
    
    if [ "$LOCAL" != "$REMOTE" ]; then
        echo "[$(date)] Ditemukan pembaruan Panel! Memulai update..." >> $LOG_FILE
        
        # Mode Maintenance
        php artisan down >> $LOG_FILE 2>&1
        
        # Tarik update
        git pull origin main >> $LOG_FILE 2>&1
        
        # Update Dependensi (Jika ada perubahan)
        export COMPOSER_ALLOW_SUPERUSER=1
        composer install --no-dev --optimize-autoloader >> $LOG_FILE 2>&1
        
        # Bersihkan Cache & Migrate
        php artisan view:clear >> $LOG_FILE 2>&1
        php artisan config:clear >> $LOG_FILE 2>&1
        php artisan migrate --seed --force >> $LOG_FILE 2>&1
        
        # Rebuild UI
        yarn install >> $LOG_FILE 2>&1
        yarn build:production >> $LOG_FILE 2>&1
        
        # Fix Permissions
        chown -R www-data:www-data /var/www/mantacil/*
        
        # Hidupkan kembali
        php artisan up >> $LOG_FILE 2>&1
        echo "[$(date)] Panel berhasil diperbarui!" >> $LOG_FILE
    else
        echo "[$(date)] Panel sudah versi terbaru." >> $LOG_FILE
    fi
fi

# 2. Update Wings (Jika diinstal)
if [ -d "/root/mantacil-wings" ]; then
    cd /root/mantacil-wings
    git fetch origin main > /dev/null 2>&1
    LOCAL=$(git rev-parse HEAD)
    REMOTE=$(git rev-parse origin/main)
    
    if [ "$LOCAL" != "$REMOTE" ]; then
        echo "[$(date)] Ditemukan pembaruan Wings! Memulai update..." >> $LOG_FILE
        
        git pull origin main >> $LOG_FILE 2>&1
        
        # Salin binary terbaru
        cp mantacil-wings /usr/local/bin/mantacil-wings
        chmod +x /usr/local/bin/mantacil-wings
        
        # Restart service
        systemctl restart mantacil-wings >> $LOG_FILE 2>&1
        echo "[$(date)] Wings berhasil diperbarui!" >> $LOG_FILE
    else
        echo "[$(date)] Wings sudah versi terbaru." >> $LOG_FILE
    fi
fi
