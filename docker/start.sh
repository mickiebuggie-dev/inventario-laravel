# ---------- STAGE 1: PHP + Apache (runtime)
FROM php:8.2-apache AS runtime

# Extensiones necesarias (incluye bcmath, gd, zip, pdo_mysql) y rewrite
RUN apt-get update && apt-get install -y \
    git curl zip unzip libonig-dev libzip-dev \
    libpng-dev libjpeg-dev libfreetype6-dev \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install pdo pdo_mysql mbstring zip exif pcntl bcmath gd \
    && a2enmod rewrite

# Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

WORKDIR /var/www/html
COPY . .

# Instalar dependencias PHP (prod)
RUN composer install --no-dev --optimize-autoloader

# VirtualHost apuntando a /public
RUN printf "<VirtualHost *:80>\n\
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
    && chmod -R 775 storage bootstrap/cache

# Script de arranque (el que ya tienes)
COPY docker/start.sh /usr/local/bin/start.sh
RUN chmod +x /usr/local/bin/start.sh

EXPOSE 8080
CMD ["/usr/local/bin/start.sh"]


# ---------- STAGE 2: Build de assets con Node (solo en build)
FROM node:20-alpine AS assets

WORKDIR /app
# Copiamos package.json/lock primero para aprovechar cache
COPY package*.json ./
# Dependencias de front (usa ci si hay lock; si no, instala normal)
RUN npm ci || npm install

# Copiamos el resto del proyecto necesario para Vite
COPY . .

# Compila a /public/build usando laravel-vite-plugin
RUN npm run build


# ---------- STAGE 3: Unimos assets compilados al runtime
FROM runtime AS final
# Copia la carpeta build generada por Vite
COPY --from=assets /app/public/build /var/www/html/public/build
