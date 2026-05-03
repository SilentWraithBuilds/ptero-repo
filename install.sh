#!/bin/bash

set -e
trap 'echo -e "\e[31m❌ Error occurred. Returning to menu...\e[0m"; sleep 2' ERR

# COLORS
GREEN="\e[32m"; CYAN="\e[36m"; YELLOW="\e[33m"; RED="\e[31m"; RESET="\e[0m"

progress() {
  echo -ne "${CYAN}["
  for i in $(seq 1 20); do echo -ne "#"; sleep 0.02; done
  echo -e "]${RESET}"
}

while true; do
clear

echo -e "${CYAN}"
echo "                                                                                                                                                                                                                        ";
echo "                   iiii  lllllll                                                tttt                                                                                     iiii          tttt         hhhhhhh             ";
echo "                  i::::i l:::::l                                             ttt:::t                                                                                    i::::i      ttt:::t         h:::::h             ";
echo "                   iiii  l:::::l                                             t:::::t                                                                                     iiii       t:::::t         h:::::h             ";
echo "                         l:::::l                                             t:::::t                                                                                                t:::::t         h:::::h             ";
echo "    ssssssssss   iiiiiii  l::::l     eeeeeeeeeeee    nnnn  nnnnnnnn    ttttttt:::::tttttttwwwwwww           wwwww           wwwwwwwrrrrr   rrrrrrrrr   aaaaaaaaaaaaa   iiiiiiittttttt:::::ttttttt    h::::h hhhhh       ";
echo "  ss::::::::::s  i:::::i  l::::l   ee::::::::::::ee  n:::nn::::::::nn  t:::::::::::::::::t w:::::w         w:::::w         w:::::w r::::rrr:::::::::r  a::::::::::::a  i:::::it:::::::::::::::::t    h::::hh:::::hhh    ";
echo "ss:::::::::::::s  i::::i  l::::l  e::::::eeeee:::::een::::::::::::::nn t:::::::::::::::::t  w:::::w       w:::::::w       w:::::w  r:::::::::::::::::r aaaaaaaaa:::::a  i::::it:::::::::::::::::t    h::::::::::::::hh  ";
echo "s::::::ssss:::::s i::::i  l::::l e::::::e     e:::::enn:::::::::::::::ntttttt:::::::tttttt   w:::::w     w:::::::::w     w:::::w   rr::::::rrrrr::::::r         a::::a  i::::itttttt:::::::tttttt    h:::::::hhh::::::h ";
echo " s:::::s  ssssss  i::::i  l::::l e:::::::eeeee::::::e  n:::::nnnn:::::n      t:::::t          w:::::w   w:::::w:::::w   w:::::w     r:::::r     r:::::r  aaaaaaa:::::a  i::::i      t:::::t          h::::::h   h::::::h";
echo "   s::::::s       i::::i  l::::l e:::::::::::::::::e   n::::n    n::::n      t:::::t           w:::::w w:::::w w:::::w w:::::w      r:::::r     rrrrrrraa::::::::::::a  i::::i      t:::::t          h:::::h     h:::::h";
echo "      s::::::s    i::::i  l::::l e::::::eeeeeeeeeee    n::::n    n::::n      t:::::t            w:::::w:::::w   w:::::w:::::w       r:::::r           a::::aaaa::::::a  i::::i      t:::::t          h:::::h     h:::::h";
echo "ssssss   s:::::s  i::::i  l::::l e:::::::e             n::::n    n::::n      t:::::t    tttttt   w:::::::::w     w:::::::::w        r:::::r          a::::a    a:::::a  i::::i      t:::::t    tttttth:::::h     h:::::h";
echo "s:::::ssss::::::si::::::il::::::le::::::::e            n::::n    n::::n      t::::::tttt:::::t    w:::::::w       w:::::::w         r:::::r          a::::a    a:::::a i::::::i     t::::::tttt:::::th:::::h     h:::::h";
echo "s::::::::::::::s i::::::il::::::l e::::::::eeeeeeee    n::::n    n::::n      tt::::::::::::::t     w:::::w         w:::::w          r:::::r          a:::::aaaa::::::a i::::::i     tt::::::::::::::th:::::h     h:::::h";
echo " s:::::::::::ss  i::::::il::::::l  ee:::::::::::::e    n::::n    n::::n        tt:::::::::::tt      w:::w           w:::w           r:::::r           a::::::::::aa:::ai::::::i       tt:::::::::::tth:::::h     h:::::h";
echo "  sssssssssss    iiiiiiiillllllll    eeeeeeeeeeeeee    nnnnnn    nnnnnn          ttttttttttt         www             www            rrrrrrr            aaaaaaaaaa  aaaaiiiiiiii         ttttttttttt  hhhhhhh     hhhhhhh";
echo "                                                                                                                                                                                                                        ";
echo "      🦖 PTERODACTYL INSTALL SCRIPT"
echo "            SILENT WRAITH"
echo -e "${RESET}"

echo "1) Install Panel"
echo "2) Install Wings"
echo "3) Install XRDP"
echo "4) Install Tailscale"
echo "5) Exit"
echo ""
read -p "Choose [1-5]: " choice

# ================= PANEL =================
if [ "$choice" == "1" ]; then

read -p "Domain: " DOMAIN
DBPASS=$(openssl rand -base64 12)

apt update -y && apt upgrade -y
apt install -y curl tar unzip git nginx mariadb-server redis-server ufw php php-cli php-fpm php-mysql php-gd php-mbstring php-bcmath php-xml php-curl php-zip
progress

curl -sS https://getcomposer.org/installer | php
mv composer.phar /usr/local/bin/composer

mysql -u root <<MYSQL
CREATE DATABASE panel;
CREATE USER 'ptero'@'127.0.0.1' IDENTIFIED BY '$DBPASS';
GRANT ALL PRIVILEGES ON panel.* TO 'ptero'@'127.0.0.1';
FLUSH PRIVILEGES;
MYSQL

mkdir -p /var/www/pterodactyl && cd /var/www/pterodactyl
curl -Lo panel.tar.gz https://github.com/pterodactyl/panel/releases/latest/download/panel.tar.gz
tar -xzvf panel.tar.gz
cp .env.example .env

composer install --no-dev --optimize-autoloader
php artisan key:generate --force

sed -i "s|APP_URL=.*|APP_URL=http://$DOMAIN|" .env
sed -i "s|DB_PASSWORD=.*|DB_PASSWORD=$DBPASS|" .env

php artisan migrate --seed --force

php artisan p:user:make <<EOF
admin
admin
admin@$DOMAIN
Admin
User
y
EOF

chown -R www-data:www-data /var/www/pterodactyl

cat > /etc/nginx/sites-available/ptero <<EOF
server {
 listen 80;
 server_name $DOMAIN;
 root /var/www/pterodactyl/public;
 index index.php;
 location / { try_files \$uri \$uri/ /index.php?\$query_string; }
 location ~ \.php$ {
  fastcgi_pass unix:/run/php/php-fpm.sock;
  include fastcgi_params;
 }
}
EOF

ln -sf /etc/nginx/sites-available/ptero /etc/nginx/sites-enabled/
systemctl restart nginx php-fpm

# Queue
cat > /etc/systemd/system/pteroq.service <<EOF
[Service]
ExecStart=/usr/bin/php /var/www/pterodactyl/artisan queue:work
Restart=always
User=www-data
EOF

systemctl daemon-reload
systemctl enable pteroq
systemctl start pteroq

ufw allow 22 80 443 8080 2022/tcp
ufw --force enable

echo -e "${GREEN}✅ Panel Installed${RESET}"
echo "URL: http://$DOMAIN"
echo "Login: admin/admin"

# ================= WINGS =================
elif [ "$choice" == "2" ]; then

apt install -y docker.io curl
systemctl enable docker --now

curl -L https://github.com/pterodactyl/wings/releases/latest/download/wings_linux_amd64 -o /usr/local/bin/wings
chmod +x /usr/local/bin/wings

mkdir -p /etc/pterodactyl

read -p "Panel URL: " PANEL
read -p "UUID: " UUID
read -p "Token: " TOKEN

cat > /etc/pterodactyl/config.yml <<EOF
uuid: $UUID
token: $TOKEN
remote: "$PANEL"
EOF

cat > /etc/systemd/system/wings.service <<EOF
[Service]
ExecStart=/usr/local/bin/wings
Restart=always
EOF

systemctl daemon-reload
systemctl enable wings
systemctl start wings

echo -e "${GREEN}✅ Wings Installed${RESET}"

# ================= XRDP =================
elif [ "$choice" == "3" ]; then

apt install -y xfce4 xfce4-goodies xrdp
systemctl enable xrdp --now
echo -e "${GREEN}✅ XRDP Ready (3389)${RESET}"

# ================= TAILSCALE =================
elif [ "$choice" == "4" ]; then

curl -fsSL https://tailscale.com/install.sh | sh
tailscale up
echo -e "${GREEN}✅ Tailscale Connected${RESET}"

# ================= EXIT =================
elif [ "$choice" == "5" ]; then
exit
fi

echo ""
read -p "Press Enter to return to menu..."
done
