#!/usr/bin/env bash
set -e

# Render inyecta $PORT. Si no viene, usa 8080.
: "${PORT:=8080}"

# Hacer que Apache escuche en $PORT
sed -ri "s/Listen 80/Listen ${PORT}/" /etc/apache2/ports.conf
sed -ri "s/:80>/:${PORT}>/g" /etc/apache2/sites-available/000-default.conf

# Migrations (no fallar el contenedor si BD aún no responde en el primer intento)
php artisan migrate --force || true

# Lanzar Apache en primer plano
exec apache2-foreground
