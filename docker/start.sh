#!/usr/bin/env bash
# docker/start.sh — arranque en Render (Apache), warm-up + migraciones con reintentos

set -e

: "${PORT:=8080}"
echo "[start] Booting with PORT=${PORT}"

# Apache escucha en $PORT
sed -ri "s/Listen 80/Listen ${PORT}/" /etc/apache2/ports.conf
sed -ri "s/:80>/:${PORT}>/g" /etc/apache2/sites-available/000-default.conf

# Healthcheck simple
mkdir -p /var/www/html/public/.well-known
echo "ok" > /var/www/html/public/.well-known/health

# Warm-up Laravel (NO route:cache, hay closures)
echo "[start] Laravel warm-up..."
mkdir -p storage/framework/{cache,sessions,views}
chown -R www-data:www-data storage bootstrap/cache
chmod -R 775 storage bootstrap/cache

php artisan storage:link || true
php artisan config:clear || true
php artisan view:clear   || true
php artisan config:cache || true
php artisan view:cache   || true

echo "[start] DB_HOST=${DB_HOST} DB_PORT=${DB_PORT} DB_DATABASE=${DB_DATABASE} DB_USERNAME=${DB_USERNAME}"

# Migraciones con reintentos
ATTEMPTS="${MIGRATE_ATTEMPTS:-20}"
SLEEP_SECS="${MIGRATE_WAIT_SECONDS:-5}"

for i in $(seq 1 "${ATTEMPTS}"); do
  echo "[start] migrate attempt ${i}/${ATTEMPTS}"
  if php artisan migrate --force --no-interaction; then
    echo "[start] migrations OK"
    break
  fi
  sleep "${SLEEP_SECS}"
done

# Seed opcional (activa RUN_SEED=1 una sola vez en Environment)
if [ "${RUN_SEED:-0}" = "1" ]; then
  echo "[start] running db:seed"
  php artisan db:seed --force --no-interaction || true
fi

echo "[start] Starting Apache..."
exec apache2-foreground
