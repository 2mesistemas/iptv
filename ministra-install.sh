#!/bin/bash

# Torne o script executável da seguinte forma >>>> (chmod +x ministra-install.sh).

# Definir senha root do MySql.
while [ $MYSQL_PASSWORD != $MYSQL_PASSWORD_VERIFY ]
    do
        printf "Digite uma senha root para o mysql: "
        read -s MYSQL_PASSWORD
        printf "\nConfirme a senha root para o mysql: "
        read -s MYSQL_PASSWORD_VERIFY
        printf "\n"

        if [ $MYSQL_PASSWORD != $MYSQL_PASSWORD_VERIFY ]
            then
                printf "Senhas não são idênticas, tente de novo\n"
        fi
    done

# Define a variável para evitar prompt do mysql.
export DEBIAN_FRONTEND=noninteractive

# Verificar por atualizações.
apt update -y

# Instalando atualizações.
apt upgrade -y

# Instação do nginx. Feita em separado, para não causar problemas com o apache.
apt install nginx -y

# Instalando o restante de pacote de dependências.
apt install unzip apache2 php7.0-mcrypt php7.0-mbstring nginx memcached mysql-server php php-mysql php-pear nodejs libapache2-mod-php php-curl php-imagick php-sqlite3 unzip -y

pear channel-discover pear.phing.info

pear install -Z phing/phing

# Configurações do Mysql
printf "Configurando o mysql\n"
mysql -u root -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '$MYSQL_PASSWORD';"
printf "sql_mode=\"\"\n" | tee -a /etc/mysql/mysql.conf.d/mysqld.cnf
mysql -u root -p"$MYSQL_PASSWORD" -e "CREATE DATABASE stalker_db;"
mysql -u root -p"$MYSQL_PASSWORD" -e "GRANT ALL PRIVILEGES ON stalker_db.* TO 'stalker'@'localhost' IDENTIFIED BY '1' WITH GRANT OPTION;"
printf "Reiniciando o mysql\n"
systemctl restart mysql

# Configurações do PHP
phpenmod mcrypt
printf "short_open_tag = On\n" | tee -a /etc/php/7.0/apache2/php.ini

# Configurando o Apache
printf "Configurando o apache\n"
a2enmod rewrite
printf "<VirtualHost *:88>
        ServerAdmin webmaster@localhost
        DocumentRoot /var/www
        <Directory /var/www/stalker_portal/>
                Options -Indexes -MultiViews
                AllowOverride ALL
                Require all granted
        </Directory>
        <Directory /var/www/player>
                Options -Indexes -MultiViews
                AllowOverride ALL
                #Require all granted
                DirectoryIndex index.php index.html
        </Directory> 
		ErrorLog ${APACHE_LOG_DIR}/error.log
		CustomLog ${APACHE_LOG_DIR}/access.log combined
</VirtualHost>\n" | tee /etc/apache2/sites-available/000-default.conf
sed -i 's/Listen 80/Listen 88/' /etc/apache2/ports.conf
printf "Reiniciando o apache\n"
systemctl restart apache2

# Configurando o Nginx
printf "server {
	listen 80;
	server_name localhost;

root /var/www;
    location ^~ /player {
        root /var/www/player;
        index index.php;
        rewrite ^/player/(.*) /player/$1 break;
        proxy_pass http://127.0.0.1:88/;
        proxy_set_header Host \$host:\$server_port;
        proxy_set_header X-Real-IP \$remote_addr;
    }

	location / {
	proxy_pass http://127.0.0.1:88/;
	proxy_set_header Host \$host:\$server_port;
	proxy_set_header X-Real-IP \$remote_addr;
	}

	location ~* \.(htm|html|jpeg|jpg|gif|png|css|js)$ {
	root /var/www;
	expires 30d;
	}
}\n" | tee /etc/nginx/sites-available/default
printf "Reiniciando o nginx\n"
systemctl restart nginx

# Instando e configurando o NPM
apt install npm -y
npm install -g npm@2.15.11
ln -s /usr/bin/nodejs /usr/bin/node

# Baixando o sistema, e descompactando-o para a pasta /var/www
wget https://download1498.mediafire.com/xldijqhfl8lg/r3s53onzk6th9xt/ministra-5.6.5.zip
unzip ministra-5.6.5.zip -d /var/www/

# Executando o Script de implantação
cd /var/www/stalker_portal/deploy
phing
cd ~
STALKER="/var/www/stalker_portal"

if [ ! -d $STALKER/deploy ]; then
        wget -O /tmp/stalker.zip https://portal.ottg.de/fl/Ministra_TV_Platform_5.6.6.zip
        unzip /tmp/stalker.zip -d /var/www/
        mv /var/www/stalker_portal-*/* /var/www/stalker_portal/
        rm -rf /var/www/stalker_portal-*
fi

if [ ! -s $STALKER/server/custom.ini ]; then
        #wget -O $STALKER/server/custom.ini https://raw.githubusercontent.com/sybdata/Ministra/master/docker/stalker_custom.ini
         wget -O $STALKER/server/custom.ini https://raw.githubusercontent.com/2mesistemas/iptv/main/stalker_custom.ini
fi

sed -i '/\bmysql_tzinfo_to_sql\b/g' $STALKER/deploy/build.xml

cd $STALKER/deploy && phing
if [ $? -eq 1 ]; then
        phing
fi


# As variáveis de ambiente serão limpas. Obs: (Isto vai ocorrer automaticamente após um logout)
printf "Limpando o ambiente\n"
unset DEBIAN_FRONTEND

echo Instalação terminada com Successo!
