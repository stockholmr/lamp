#!/bin/bash

read -p "Domain: " domain

phpmyadmin_secret=`mktemp -u XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX`

echo MySQL Root Password

while true; do
    read -s -p "Password: " password
    read -s -p "Repeat Password: " password2

    if [ "$password" = "$password2" ]
    then
            break
    else
            echo "passwords do not match try again"
    fi
done


##
# Add php package repository
##

# Ubuntu
sudo add-apt-repository ppa:ondrej/php -y
sudo add-apt-repository ppa:ondrej/apache2 -y

# Debian
#echo "deb https://packages.sury.org/php/ bookworm main" | sudo tee -a /etc/apt/sources.list.d/php.list
#sudo curl --output /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg
#sudo apt update

##
# Install packages
##
sudo apt update
sudo apt install apache2 wget curl unzip mariadb-server libapache2-mod-php8.3 php-xdebug php8.3 php8.3-cli php8.3-{bz2,mysql,mbstring,xml,zip,gd,imagick,intl,curl,sqlite3} -y

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

sudo tee /etc/php/8.3/apache2/conf.d/20-xdebug.ini << EOM
zend_extension=xdebug.so

[XDEBUG]
xdebug.mode = debug
xdebug.client_host = 127.0.0.1
xdebug.client_port = 9003
xdebug.start_with_request = trigger
xdebug.idekey = PHPSTORM
EOM

##
# Install phpmyadmin
##
sudo mkdir /var/www/phpmyadmin
cd /var/www/phpmyadmin
sudo wget https://files.phpmyadmin.net/phpMyAdmin/5.2.2/phpMyAdmin-5.2.2-english.zip
sudo unzip phpMyAdmin-5.2.2-english.zip
sudo rm phpMyAdmin-5.2.2-english.zip
cd phpMyAdmin-5.2.2-english
sudo mv ./* ../
cd ..
sudo rm -R phpMyAdmin-5.2.2-english

sudo tee /var/www/phpmyadmin/config.inc.php << EOM
<?php
declare(strict_types=1);

\$cfg['blowfish_secret'] = '$phpmyadmin_secret';

\$cfg['Servers'][1]['auth_type'] = 'cookie';
\$cfg['Servers'][1]['host'] = 'localhost';
\$cfg['Servers'][1]['compress'] = false;
\$cfg['Servers'][1]['AllowNoPassword'] = false;

\$cfg['UploadDir'] = '';
\$cfg['SaveDir'] = '';
\$cfg['TempDir'] = '/tmp';
EOM


sudo mkdir -p /var/www/html/public

sudo tee /etc/apache2/sites-available/000-default.conf << EOM
<VirtualHost *:80>
    ServerName "$domain"
    DocumentRoot "/var/www/html/public"
    <Directory "/var/www/html/public">
        Options Indexes FollowSymLinks Includes
        AllowOverride All
        Require all granted
    </Directory>
</VirtualHost>

<VirtualHost *:443>
    ServerName "$domain"
    DocumentRoot "/var/www/html/public"
    <Directory "/var/www/html/public">
        Options Indexes FollowSymLinks Includes
        AllowOverride All
        Require all granted
    </Directory>
    SSLEngine on
    SSLCertificateFile /etc/cert/$domain.crt
    SSLCertificateKeyFile /etc/cert/$domain.key
</VirtualHost>
EOM

sudo tee /etc/apache2/sites-available/phpmyadmin.conf << EOM
<IfModule alias_module>
    Alias /phpmyadmin "/var/www/phpmyadmin"
    <Directory "/var/www/phpmyadmin">
        Options ExecCGI
        AllowOverride All
        Require all granted
    </Directory>
</IfModule>
EOM

##
# Install Composer
##
sudo curl --output /var/www/composer-setup.php https://getcomposer.org/installer
sudo php /var/www/composer-setup.php --install-dir=/usr/local/bin --filename=composer
sudo rm /var/www/composer-setup.php

##
# Secure mariaDB Server
##
sudo tee /var/www/mysql_secure_installation.sql << EOM
UPDATE mysql.global_priv SET priv=json_set(priv, '$.password_last_changed', UNIX_TIMESTAMP(), '$.plugin', 'mysql_native_password', '$.authentication_string', PASSWORD('$password'), '$.auth_or', json_array(json_object(), json_object('plugin', 'unix_socket'))) WHERE User='root';
DELETE FROM mysql.global_priv WHERE User='';
DELETE FROM mysql.global_priv WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
FLUSH PRIVILEGES;
EOM

sudo mysql -sfu root < /var/www/mysql_secure_installation.sql
sudo rm /var/www/mysql_secure_installation.sql

sudo a2enmod ssl
sudo a2enmod rewrite
sudo a2ensite phpmyadmin
sudo systemctl restart apache2
