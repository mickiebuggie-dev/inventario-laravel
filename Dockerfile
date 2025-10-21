# PHP 8.2 + Apache
FROM php:8.2-apache

# Paquetes del sistema y extensiones PHP necesarias (incluye bcmath)
RUN apt-get update && apt-get install -y \
    git curl zip unzip libonig-dev libzip-dev \
    libpng-dev libjpeg-dev libfreetype6-dev \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install pdo pdo_mysql mbstring zip exif pcntl bcmath gd \
    && a2enmod rewrite

# Composer desde imagen oficial
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Código
WORKDIR /var/www/html
COPY . .

# Instalar dependencias de Laravel
RUN composer install --no-dev --optimize-autoloader

# VirtualHost apuntando a /public y AllowOverride On
RUN printf "<VirtualHost *:80>\n\
    ServerAdmin webmaster@localhost\n\
    DocumentRoot /var/www/html/public\n\
    <Directory /var/www/html/public>\n\
        AllowOverride All\n\
        Require all granted\n\
    </Directory>\n\
    ErrorLog \${APACHE_LOG_DIR}/error.log\n\
    CustomLog \${APACHE_LOG_DIR}/access.log combined\n\
</VirtualHost>\n" > /etc/apache2/sites-available/000-default.conf

# Permisos
RUN chown -R www-data:www-data /var/www/html \
    && chmod -R 755 storage bootstrap/cache

# Script de arranque: ajusta Apache al $PORT, migra y lanza
COPY docker/start.sh /usr/local/bin/start.sh
RUN chmod +x /usr/local/bin/start.sh

# Exponer un puerto "default" (Render usará $PORT igualmente)
EXPOSE 8080

# Arranque
CMD ["/usr/local/bin/start.sh"]
