# Etapa base: PHP + composer
FROM php:8.2-fpm

# Instalar extensiones de sistema y PHP
RUN apt-get update && apt-get install -y \
    libonig-dev libzip-dev unzip curl libpng-dev libjpeg-dev libfreetype6-dev \
    zip git mariadb-client && \
    docker-php-ext-install pdo pdo_mysql mbstring zip gd

# Instalar Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Setear directorio de trabajo
WORKDIR /var/www

# Copiar archivos del proyecto
COPY . .

# Instalar dependencias de Laravel
RUN composer install --no-dev --optimize-autoloader

# Asignar permisos
RUN chown -R www-data:www-data /var/www \
    && chmod -R 755 /var/www/storage

# Expone puerto (no usado en fpm, pero útil para debugging)
EXPOSE 9000

# Comando final (migraciones + servidor PHP integrado si lo usas en local)
CMD php artisan migrate --force && php-fpm
