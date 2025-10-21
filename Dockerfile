# Usa PHP 8.2 con FPM
FROM php:8.2-fpm

# Instalar dependencias de sistema y extensiones de PHP
RUN apt-get update && apt-get install -y \
    git curl zip unzip libpng-dev libjpeg-dev libfreetype6-dev libonig-dev libzip-dev \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install pdo pdo_mysql mbstring zip exif pcntl bcmath gd

# Instalar Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Establecer directorio de trabajo
WORKDIR /var/www

# Copiar todos los archivos del proyecto
COPY . .

# Instalar dependencias de Laravel (sin desarrollo, optimizado)
RUN composer install --no-dev --optimize-autoloader

# Asignar permisos necesarios
RUN chown -R www-data:www-data /var/www \
    && chmod -R 755 /var/www/storage /var/www/bootstrap/cache

# Puerto expuesto
EXPOSE 9000

# Ejecutar migraciones y luego iniciar PHP-FPM
CMD php artisan migrate --force && php-fpm
