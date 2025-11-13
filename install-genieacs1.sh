#!/bin/bash
# ===============================================
#  GENIEACS INSTALLER by EGA CHANEL
#  Version: 1.2.13 Original Source + Optional Restore
#  Universal Installer (auto detect username)
# ===============================================

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Deteksi username aktif
if [ "$SUDO_USER" ]; then
    USERNAME=$SUDO_USER
else
    USERNAME=$USER
fi

USER_HOME=$(eval echo ~$USERNAME)
LOCAL_IP=$(hostname -I | awk '{print $1}')

clear
echo -e "${GREEN}======================================================================${NC}"
echo -e "${GREEN}     ███████╗ ██████╗  █████╗      ██████╗██╗  ██╗ █████╗ ███╗   ██╗ ${NC}"
echo -e "${GREEN}     ██╔════╝██╔═══██╗██╔══██╗    ██╔════╝██║  ██║██╔══██╗████╗  ██║ ${NC}"
echo -e "${GREEN}     █████╗  ██║   ██║███████║    ██║     ███████║███████║██╔██╗ ██║ ${NC}"
echo -e "${GREEN}     ██╔══╝  ██║   ██║██╔══██║    ██║     ██╔══██║██╔══██║██║╚██╗██║ ${NC}"
echo -e "${GREEN}     ██║     ╚██████╔╝██║  ██║    ╚██████╗██║  ██║██║  ██║██║ ╚████║ ${NC}"
echo -e "${GREEN}     ╚═╝      ╚═════╝ ╚═╝  ╚═╝     ╚═════╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═══╝ ${NC}"
echo -e "${GREEN}======================================================================${NC}"
echo -e "${GREEN}     GenieACS Installer v1.2.13 — by EGA CHANEL                       ${NC}"
echo -e "${GREEN}======================================================================${NC}"
echo ""
read -p "Apakah Anda ingin melanjutkan instalasi? (y/n): " confirmation
if [ "$confirmation" != "y" ]; then
    echo -e "${RED}Install dibatalkan.${NC}"
    exit 1
fi

echo -e "${GREEN}Memulai instalasi...${NC}"
sleep 2

# --------------------------------------------------------------
# 1. Install dependency dasar
# --------------------------------------------------------------
apt update -y
apt install -y curl git build-essential

# --------------------------------------------------------------
# 2. Install Node.js 18.x
# --------------------------------------------------------------
echo -e "${GREEN}Menginstal Node.js...${NC}"
curl -sL https://deb.nodesource.com/setup_18.x | bash -
apt install -y nodejs
node -v
npm -v

# --------------------------------------------------------------
# 3. Install MongoDB 4.4
# --------------------------------------------------------------
echo -e "${GREEN}Menginstal MongoDB...${NC}"
curl -fsSL https://www.mongodb.org/static/pgp/server-4.4.asc | apt-key add -
echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu focal/mongodb-org/4.4 multiverse" | tee /etc/apt/sources.list.d/mongodb-org-4.4.list
apt update
apt install -y mongodb-org
systemctl enable --now mongod
mongo --eval 'db.runCommand({ connectionStatus: 1 })'

# --------------------------------------------------------------
# 4. Install GenieACS (Original)
# --------------------------------------------------------------
echo -e "${GREEN}Menginstal GenieACS v1.2.13 ...${NC}"
npm install -g genieacs@1.2.13

# Buat user dan direktori
useradd --system --no-create-home --user-group genieacs || true
mkdir -p /opt/genieacs/ext /var/log/genieacs
chown -R genieacs:genieacs /opt/genieacs /var/log/genieacs

# Buat environment file
cat << EOF > /opt/genieacs/genieacs.env
GENIEACS_CWMP_ACCESS_LOG_FILE=/var/log/genieacs/genieacs-cwmp-access.log
GENIEACS_NBI_ACCESS_LOG_FILE=/var/log/genieacs/genieacs-nbi-access.log
GENIEACS_FS_ACCESS_LOG_FILE=/var/log/genieacs/genieacs-fs-access.log
GENIEACS_UI_ACCESS_LOG_FILE=/var/log/genieacs/genieacs-ui-access.log
GENIEACS_DEBUG_FILE=/var/log/genieacs/genieacs-debug.yaml
GENIEACS_EXT_DIR=/opt/genieacs/ext
GENIEACS_UI_JWT_SECRET=secret
EOF

chmod 600 /opt/genieacs/genieacs.env
chown genieacs:genieacs /opt/genieacs/genieacs.env

# --------------------------------------------------------------
# 5. Systemd service files
# --------------------------------------------------------------
services=("cwmp" "nbi" "fs" "ui")

for svc in "${services[@]}"; do
cat << EOF > /etc/systemd/system/genieacs-$svc.service
[Unit]
Description=GenieACS $svc Service
After=network.target

[Service]
User=genieacs
EnvironmentFile=/opt/genieacs/genieacs.env
ExecStart=/usr/bin/genieacs-$svc

[Install]
WantedBy=multi-user.target
EOF
done

# Enable and start all services
systemctl daemon-reload
systemctl enable --now genieacs-{cwmp,nbi,fs,ui}

echo -e "${GREEN}==============================================================${NC}"
echo -e "${GREEN}GenieACS berhasil diinstal dan berjalan.${NC}"
echo -e "${GREEN}Akses GUI: http://$LOCAL_IP:3000${NC}"
echo -e "${GREEN}==============================================================${NC}"

# --------------------------------------------------------------
# 6. Opsi Restore Parameter Full (EGA CHANEL)
# --------------------------------------------------------------
read -p "Apakah Anda ingin menginstall parameter full dari backup EGA CHANEL? (y/n): " restore
if [ "$restore" == "y" ]; then
    echo -e "${GREEN}Menyiapkan restore parameter full...${NC}"
    cd "$USER_HOME"
    git clone https://github.com/egachanel2626-sketch/genieacs-backup-full.git

    echo -e "${GREEN}Menghentikan service GenieACS...${NC}"
    systemctl stop genieacs-{cwmp,nbi,fs,ui}

    echo -e "${GREEN}Melakukan restore database...${NC}"
    mongorestore --drop --db genieacs "$USER_HOME/genieacs-backup-full/genieacs"

    echo -e "${GREEN}Menyalakan ulang service GenieACS...${NC}"
    systemctl start genieacs-{cwmp,nbi,fs,ui}

    echo -e "${GREEN}==============================================================${NC}"
    echo -e "${GREEN}Restore parameter full berhasil!${NC}"
else
    echo -e "${YELLOW}Restore parameter dilewati.${NC}"
fi

# --------------------------------------------------------------
# 7. Selesai
# --------------------------------------------------------------
echo -e "${GREEN}======================================================================${NC}"
echo -e "${GREEN}=======  Installasi Selesai - GenieACS by EGA CHANEL  ===============${NC}"
echo -e "${GREEN}=======  Akses: http://$LOCAL_IP:3000 ===============================${NC}"
echo -e "${GREEN}======================================================================${NC}"
