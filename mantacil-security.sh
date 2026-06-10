#!/bin/bash
# =======================================================
# MantaCil Security Toolkit (Anti-DDoS & CPU Abuse)
# =======================================================

LOG_FILE="/var/log/mantacil_security.log"
PTERO_VOLUMES="/var/lib/pterodactyl/volumes"

# 1. SCAN FILE BERBAHAYA (DDoS / Flooders)
for VOLUME in $PTERO_VOLUMES/*; do
    if [ -d "$VOLUME" ]; then
        UUID=$(basename "$VOLUME")
        # Cari file dengan nama mencurigakan
        BAD_FILES=$(find "$VOLUME" -maxdepth 3 -type f -iregex '.*\(ddos\|flood\|udp\.py\|stress\|botnet\).*')
        
        if [ ! -z "$BAD_FILES" ]; then
            echo "[$(date)] TERDETEKSI SCRIPT BERBAHAYA pada Server UUID: $UUID" >> $LOG_FILE
            echo "$BAD_FILES" >> $LOG_FILE
            
            # Action: Stop Container & Suspend in Database
            echo "Mengambil tindakan: FORCE STOP & SUSPEND..." >> $LOG_FILE
            docker stop "$UUID" >> $LOG_FILE 2>&1 || true
            mysql -u root -e "UPDATE panel.servers SET suspended = 1 WHERE uuid = '$UUID';" >> $LOG_FILE 2>&1
            
            # Hapus file berbahaya agar tidak bisa dijalankan lagi
            rm -f $BAD_FILES
        fi
    fi
done

# 2. AUTO DETECT HIGH RISK CPU (Batas > 95% selama pengecekan)
# Mendapatkan daftar container Wings
DOCKER_STATS=$(docker stats --no-stream --format "{{.Name}},{{.CPUPerc}}" | grep -v "mantacil-wings")

while IFS= read -r line; do
    if [ -z "$line" ]; then continue; fi
    CONTAINER_NAME=$(echo "$line" | cut -d',' -f1)
    CPU_USAGE_STR=$(echo "$line" | cut -d',' -f2 | sed 's/%//g')
    
    # Ambil angka bulatnya saja
    CPU_USAGE=${CPU_USAGE_STR%.*}
    
    # Jika CPU di atas 95%
    if [ "$CPU_USAGE" -gt 95 ]; then
        echo "[$(date)] TERDETEKSI HIGH CPU ABUSE ($CPU_USAGE%) pada Server UUID: $CONTAINER_NAME" >> $LOG_FILE
        echo "Mengambil tindakan: FORCE STOP & SUSPEND..." >> $LOG_FILE
        docker stop "$CONTAINER_NAME" >> $LOG_FILE 2>&1 || true
        mysql -u root -e "UPDATE panel.servers SET suspended = 1 WHERE uuid = '$CONTAINER_NAME';" >> $LOG_FILE 2>&1
    fi
done <<< "$DOCKER_STATS"
