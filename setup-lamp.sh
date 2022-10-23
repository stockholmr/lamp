#!/bin/bash

sudo apt update
sudo apt install -y wget curl

##
# Add php package repository
##
echo "deb https://packages.sury.org/php/ bullseye main" | sudo tee -a /etc/apt/sources.list.d/php.list
sudo curl --output /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg
sudo apt update

##
# Install packages
##
sudo apt install -y apache2 php-cli php-xdebug php-xml php-mbstring php-intl php-mysql php-zip php-gd php-curl php-apcu php-memcache php-imagick libapache2-mod-php php-pear mariadb-server

##
# Install phpmyadmin
##
cd /var/www
sudo curl --output /var/www/pma.tar.gz https://files.phpmyadmin.net/phpMyAdmin/5.2.0/phpMyAdmin-5.2.0-english.tar.gz
sudo tar -xvzf /var/www/pma.tar.gz
sudo mv /var/www/phpMyAdmin-5.2.0-english /var/www/phpmyadmin
sudo rm /var/www/pma.tar.gz

sudo tee /var/www/phpmyadmin/config.inc.php << EOM
<?php
declare(strict_types=1);

\$cfg['blowfish_secret'] = '{{{ 32 Byte Code Here }}}';

\$cfg['Servers'][1]['auth_type'] = 'cookie';
\$cfg['Servers'][1]['host'] = 'localhost';
\$cfg['Servers'][1]['compress'] = false;
\$cfg['Servers'][1]['AllowNoPassword'] = false;

\$cfg['UploadDir'] = '';
\$cfg['SaveDir'] = '';
\$cfg['TempDir'] = '/tmp';
EOM


sudo tee /etc/apache2/sites-available/000-default.conf << EOM
<VirtualHost *:80>
    ServerName "localhost"
    DocumentRoot "/var/www/html"
    <Directory "/var/www/html">
        Options Indexes FollowSymLinks Includes
        AllowOverride All
        Require all granted
    </Directory>
    ErrorLog \${APACHE_LOG_DIR}/error.log
    CustomLog \${APACHE_LOG_DIR}/access.log combined
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
sudo php /var/www/composer-setup.php --install-dir=/usr/bin --filename=composer

sudo service mariadb start

##
# Secure mariaDB Server
##
sudo tee /var/www/mysql_secure_installation.sql << EOM
UPDATE mysql.global_priv SET priv=json_set(priv, '$.password_last_changed', UNIX_TIMESTAMP(), '$.plugin', 'mysql_native_password', '$.authentication_string', PASSWORD('{{{ ROOT PASSWORD HERE }}}'), '$.auth_or', json_array(json_object(), json_object('plugin', 'unix_socket'))) WHERE User='root';
DELETE FROM mysql.global_priv WHERE User='';
DELETE FROM mysql.global_priv WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
FLUSH PRIVILEGES;
EOM

sudo mysql -sfu root < /var/www/mysql_secure_installation.sql
sudo rm /var/www/mysql_secure_installation.sql

sudo a2enmod rewrite
sudo a2ensite phpmyadmin
sudo service apache2 start