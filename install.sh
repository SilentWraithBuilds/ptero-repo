#!/bin/bash

set -e
clear

# ====== COLORS ======
GREEN="\e[32m"
CYAN="\e[36m"
RED="\e[31m"
RESET="\e[0m"

# ====== BANNER ======
echo -e "${CYAN}"
echo "========================================="
echo "     🦖 PTERODACTYL INSTALL SCRIPT"
echo "           SILENT WRAITH"
echo "========================================="
echo -e "${RESET}"

# ====== CHOICE ======
echo "1) Install Panel"
echo "2) Install Wings"
echo ""
read -p "Enter choice [1-2]: " choice

# =========================
# ===== PANEL INSTALL =====
# =========================
if [ "$choice" == "1" ]; then

read -p "🌐 Enter domain (panel.example.com): " DOMAIN

DBPASS=$(openssl rand -base64 12)
APP_KEY=$(openssl rand -base64 32)

echo -e "${GREEN}Updating system...${RESET}"
apt update -y && apt upgrade -y

echo -e "${GREEN}Installing dependencies...${RESET}"
apt install -y curl tar unzip git nginx mariadb-server redis-server \
software-properties-common apt-transport-https ca-certificates lsb-release

echo -e "${GREEN}Installing PHP...${RESET}"
add-apt-repository ppa:ondrej/php -y
apt update
apt install -y php8.2 php8.2-cli php8.2-gd php8.2-mysql php8.2-mbstring \
php8.2-bcmath php8.2-xml php8.2-fpm php8.2-curl php8.2-zip php8.2-intl

echo -e "${GREEN}Installing Composer...${RESET}"
curl -sS https://getcomposer.org/installer | php
mv composer.phar /usr/local/bin/composer

echo -e "${GREEN}Setting up database...${RESET}"
mysql -u root <<MYSQL
CREATE DATABASE panel;
CREATE USER 'ptero'@'127.0.0.1' IDENTIFIED BY '$DBPASS';
GRANT ALL PRIVILEGES ON panel.* TO 'ptero'@'127.0.0.1';
FLUSH PRIVILEGES;
MYSQL

echo -e "${GREEN}Downloading panel...${RESET}"
mkdir -p /var/www/pterodactyl
cd /var/www/pterodactyl

curl -Lo panel.tar.gz https://github.com/pterodactyl/panel/releases/latest/download/panel.tar.gz
tar -xzvf panel.tar.gz
chmod -R 755 storage bootstrap/cache

cp .env.example .env

echo -e "${GREEN}Installing dependencies...${RESET}"
composer install --no-dev --optimize-autoloader

php artisan key:generate --force

echo -e "${GREEN}Auto configuring environment...${RESET}"

sed -i "s|APP_URL=.*|APP_URL=http://$DOMAIN|" .env
sed -i "s|DB_PASSWORD=.*|DB_PASSWORD=$DBPASS|" .env
sed -i "s|DB_DATABASE=.*|DB_DATABASE=panel|" .env
sed -i "s|DB_USERNAME=.*|DB_USERNAME=ptero|" .env

echo -e "${GREEN}Running migrations...${RESET}"
php artisan migrate --seed --force

echo -e "${GREEN}Creating admin user (AUTO)...${RESET}"
php artisan p:user:make <<EOF
admin
admin
admin@$DOMAIN
Admin
User
y
EOF

chown -R www-data:www-data /var/www/pterodactyl/*

echo -e "${GREEN}Configuring nginx...${RESET}"
cat > /etc/nginx/sites-available/pterodactyl <<EOF
server {
    listen 80;
    server_name $DOMAIN;

    root /var/www/pterodactyl/public;
    index index.php;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php$ {
        fastcgi_pass unix:/run/php/php8.2-fpm.sock;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
    }
}
EOF

ln -sf /etc/nginx/sites-available/pterodactyl /etc/nginx/sites-enabled/pterodactyl

systemctl enable nginx php8.2-fpm redis-server mariadb
systemctl restart nginx php8.2-fpm redis-server mariadb

echo ""
echo -e "${CYAN}=========================================${RESET}"
echo -e "${GREEN}✅ PANEL INSTALLED SUCCESSFULLY${RESET}"
echo -e "🌐 URL: http://$DOMAIN"
echo -e "👤 USER: admin"
echo -e "🔑 PASS: admin"
echo -e "🛢️ DB PASS: $DBPASS"
echo -e "${CYAN}=========================================${RESET}"

# =========================
# ===== WINGS INSTALL =====
# =========================
elif [ "$choice" == "2" ]; then

echo -e "${GREEN}Installing Docker...${RESET}"
curl -sSL https://get.docker.com/ | sh

echo -e "${GREEN}Installing Wings...${RESET}"
mkdir -p /etc/pterodactyl

curl -L https://github.com/pterodactyl/wings/releases/latest/download/wings_linux_amd64 \
-o /usr/local/bin/wings

chmod +x /usr/local/bin/wings

echo ""
echo -e "${GREEN}✅ Wings Installed!${RESET}"
echo "👉 Configure node from panel"

else
echo -e "${RED}Invalid choice${RESET}"
fi
