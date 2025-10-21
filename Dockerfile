# Usa PHP con Apache para servir Laravel
FROM php:8.2-apache

# Instala extensiones del sistema necesarias
RUN apt-get update && apt-get install -y \
    git curl zip unzip nano libpng-dev libjpeg-dev libfreetype6-dev \
    libonig-dev libxml2-dev libzip-dev libpq-dev \
    && docker-php-ext-install pdo pdo_mysql mbstring zip exif pcntl bcmath gd

# Instala Composer desde la imagen oficial
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Establece el directorio de trabajo
WORKDIR /var/www/html

# Copia los archivos del proyecto Laravel al contenedor
COPY . .

# Instala dependencias PHP de Laravel
RUN composer install --no-dev --optimize-autoloader

# Ajusta permisos para Laravel
RUN chown -R www-data:www-data /var/www/html \
    && chmod -R 755 /var/www/html/storage /var/www/html/bootstrap/cache

# Habilita mod_rewrite de Apache (necesario para rutas amigables de Laravel)
RUN a2enmod rewrite

# Configura Apache para que apunte al directorio public/
RUN echo "<VirtualHost *:80>\n\
    ServerAdmin webmaster@localhost\n\
    DocumentRoot /var/www/html/public\n\
    <Directory /var/www/html/public>\n\
        AllowOverride All\n\
        Require all granted\n\
    </Directory>\n\
    ErrorLog \${APACHE_LOG_DIR}/error.log\n\
    CustomLog \${APACHE_LOG_DIR}/access.log combined\n\
</VirtualHost>" > /etc/apache2/sites-available/000-default.conf

# Expone el puerto 8080 (Render redirige internamente)
EXPOSE 8080

# Ejecuta migraciones y levanta el servidor Laravel automáticamente
CMD php artisan migrate --force && apache2-foreground
