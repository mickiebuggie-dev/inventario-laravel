# ---------- STAGE 1: runtime PHP + Apache
FROM php:8.2-apache AS runtime

RUN apt-get update && apt-get install -y \
    git curl zip unzip libonig-dev libzip-dev \
    libpng-dev libjpeg-dev libfreetype6-dev \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install pdo pdo_mysql mbstring zip exif pcntl bcmath gd \
    && a2enmod rewrite

COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

WORKDIR /var/www/html
COPY . .

# Dependencias PHP (prod)
RUN composer install --no-dev --optimize-autoloader

# VirtualHost -> /public
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

# Script de arranque
COPY docker/start.sh /usr/local/bin/start.sh
RUN chmod +x /usr/local/bin/start.sh

EXPOSE 8080
CMD ["/usr/local/bin/start.sh"]


# ---------- STAGE 2: build de assets con Node (Vite)
# Usa Node 18 LTS para evitar conflictos de peer deps
FROM node:18-alpine AS assets
WORKDIR /app

# variables para reducir ruido y conflictos
ENV NPM_CONFIG_FUND=false \
    NPM_CONFIG_AUDIT=false

# Copiamos sólo los manifests primero para cache
COPY package*.json ./

# 1) Si hay package-lock.json, npm ci puede fallar si se generó con otra versión de npm
# 2) Forzamos legacy-peer-deps para resolver conflictos de plugins
RUN npm ci --legacy-peer-deps || npm install --legacy-peer-deps

# Copiamos el resto del proyecto necesario para Vite
COPY . .

# Compila (genera public/build/manifest.json)
RUN npm run build


# ---------- STAGE 3: unir assets compilados al runtime
FROM runtime AS final
COPY --from=assets /app/public/build /var/www/html/public/build
