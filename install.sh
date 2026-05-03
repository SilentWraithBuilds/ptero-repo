#!/bin/bash

set -e
clear

# ===== COLORS =====
GREEN="\e[32m"
CYAN="\e[36m"
YELLOW="\e[33m"
RED="\e[31m"
RESET="\e[0m"

# ===== PROGRESS BAR =====
progress() {
  echo -ne "${CYAN}["
  for i in $(seq 1 20); do
    echo -ne "#"
    sleep 0.05
  done
  echo -e "]${RESET}"
}

# ===== BANNER =====
echo -e "${CYAN}"
echo "========================================="
echo "     🦖 PTERODACTYL INSTALL SCRIPT"
echo "           SILENT WRAITH"
echo "========================================="
echo -e "${RESET}"

# ===== MENU =====
echo "1) Install Panel"
echo "2) Install Wings"
echo "3) Install Tailscale"
echo ""
read -p "Enter choice [1-3]: " choice

# =========================
# PANEL INSTALL
# =========================
if [ "$choice" == "1" ]; then

read -p "🌐 Domain (panel.example.com): " DOMAIN

echo -e "${GREEN}Updating system...${RESET}"
apt update -y && apt upgrade -y
progress

echo -e "${GREEN}Installing dependencies...${RESET}"
apt install -y curl tar unzip git nginx mariadb-server redis-server software-properties-common
progress

echo -e "${GREEN}Installing PHP...${RESET}"
add-apt-repository ppa:ondrej/php -y
apt update
apt install -y php8.2 php8.2-cli php8.2-fpm php8.2-mysql php8.2-gd php8.2-mbstring php8.2-bcmath php8.2-xml php8.2-curl php8.2-zip
progress

echo -e "${GREEN}Installing Composer...${RESET}"
curl -sS https://getcomposer.org/installer | php
mv composer.phar /usr/local/bin/composer
progress

DBPASS=$(openssl rand -base64 12)

echo -e "${GREEN}Setting up database...${RESET}"
mysql -u root <<MYSQL
CREATE DATABASE panel;
CREATE USER 'ptero'@'127.0.0.1' IDENTIFIED BY '$DBPASS';
GRANT ALL PRIVILEGES ON panel.* TO 'ptero'@'127.0.0.1';
FLUSH PRIVILEGES;
MYSQL
progress

echo -e "${GREEN}Downloading panel...${RESET}"
mkdir -p /var/www/pterodactyl && cd /var/www/pterodactyl
curl -Lo panel.tar.gz https://github.com/pterodactyl/panel/releases/latest/download/panel.tar.gz
tar -xzvf panel.tar.gz
chmod -R 755 storage bootstrap/cache
cp .env.example .env
progress

echo -e "${GREEN}Installing panel dependencies...${RESET}"
composer install --no-dev --optimize-autoloader
php artisan key:generate --force
progress

echo -e "${GREEN}Configuring environment...${RESET}"
sed -i "s|APP_URL=.*|APP_URL=http://$DOMAIN|" .env
sed -i "s|DB_PASSWORD=.*|DB_PASSWORD=$DBPASS|" .env
sed -i "s|DB_DATABASE=.*|DB_DATABASE=panel|" .env
sed -i "s|DB_USERNAME=.*|DB_USERNAME=ptero|" .env
progress

echo -e "${GREEN}Running migrations...${RESET}"
php artisan migrate --seed --force
progress

echo -e "${GREEN}Creating admin (admin/admin)...${RESET}"
php artisan p:user:make <<EOF
admin
admin
admin@$DOMAIN
Admin
User
y
EOF
progress

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

ln -sf /etc/nginx/sites-available/pterodactyl /etc/nginx/sites-enabled/
systemctl restart nginx php8.2-fpm redis-server mariadb
progress

echo -e "${GREEN}✅ PANEL READY${RESET}"
echo "🌐 http://$DOMAIN"
echo "👤 admin / admin"
echo "DB PASS: $DBPASS"

# =========================
# WINGS INSTALL
# =========================
elif [ "$choice" == "2" ]; then

echo -e "${GREEN}Installing Docker...${RESET}"
curl -sSL https://get.docker.com/ | sh
progress

echo -e "${GREEN}Installing Wings...${RESET}"
mkdir -p /etc/pterodactyl
curl -L https://github.com/pterodactyl/wings/releases/latest/download/wings_linux_amd64 -o /usr/local/bin/wings
chmod +x /usr/local/bin/wings
progress

echo ""
echo -e "${YELLOW}--- Wings Auto Configuration ---${RESET}"

read -p "Panel URL (http://panel.domain.com): " PANEL_URL
read -p "Node UUID: " UUID
read -p "Node Token: " TOKEN

cat > /etc/pterodactyl/config.yml <<EOF
debug: false
uuid: $UUID
token_id: $UUID
token: $TOKEN

api:
  host: 0.0.0.0
  port: 8080
  ssl:
    enabled: false

system:
  data: /var/lib/pterodactyl/volumes
  sftp:
    bind_port: 2022
EOF

echo -e "${GREEN}Starting Wings...${RESET}"
wings &
progress

echo -e "${GREEN}✅ Wings running on port 8080${RESET}"

# =========================
# TAILSCALE INSTALL
# =========================
elif [ "$choice" == "3" ]; then

echo -e "${GREEN}Installing Tailscale...${RESET}"
curl -fsSL https://tailscale.com/install.sh | sh
progress

echo -e "${GREEN}Starting Tailscale...${RESET}"
tailscale up
progress

echo -e "${GREEN}✅ Tailscale connected${RESET}"

else
echo -e "${RED}Invalid choice${RESET}"
fi
