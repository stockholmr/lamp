#!/bin/bash

read -p "Name (no spaces or special chars): " wwwName
read -p "Domain: " domain



# Reference
# C = GB
# ST = Test State
# L = Test Locality
# O = Org Name
# OU = Org Unit Name
# CN = Common Name
sudo mkdir /etc/cert

sudo openssl req -new -newkey rsa:4096 -days 365 -nodes -x509 \
    -subj "/C=GB/ST=None/L=None/O=None/CN=$domain" \
    -keyout /etc/cert/$domain.key  -out /etc/cert/$domain.crt


sudo mkdir -p /var/www/$wwwName/public

sudo tee /etc/apache2/sites-available/$wwwName.conf << EOM
<VirtualHost *:80>
    ServerName "$domain"
    DocumentRoot "/var/www/$wwwName/public"
    <Directory "/var/www/$wwwName/public">
        Options Indexes FollowSymLinks Includes
        AllowOverride All
        Require all granted
    </Directory>
</VirtualHost>

<VirtualHost *:443>
    ServerName "$domain"
    DocumentRoot "/var/www/$wwwName/public"
    <Directory "/var/www/$wwwName/public">
        Options Indexes FollowSymLinks Includes
        AllowOverride All
        Require all granted
    </Directory>
    SSLEngine on
    SSLCertificateFile /etc/cert/$domain.crt
    SSLCertificateKeyFile /etc/cert/$domain.key
</VirtualHost>
EOM

sudo a2ensite $wwwName
sudo systemctl restart apache2