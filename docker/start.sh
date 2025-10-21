#!/usr/bin/env bash
set -e

: "${PORT:=8080}"

# Apache escucha en $PORT
sed -ri "s/Listen 80/Listen ${PORT}/" /etc/apache2/ports.conf
sed -ri "s/:80>/:${PORT}>/g" /etc/apache2/sites-available/000-default.conf

# Warm-up
php artisan storage:link || true
php artisan config:clear || true
php artisan config:cache || true
php artisan view:clear || true
php artisan view:cache || true

# Reintentos de migración (20 intentos, 5s entre cada uno)
ATTEMPTS=20
for i in $(seq 1 $ATTEMPTS); do
  echo "[start] migrate attempt $i/$ATTEMPTS"
  if php artisan migrate --force --no-interaction; then
    echo "[start] migrations OK"
    break
  fi
  sleep 5
done

# Seed opcional controlado por variable de entorno
if [ "${RUN_SEED}" = "1" ]; then
  echo "[start] running db:seed"
  php artisan db:seed --force --no-interaction || true
fi

exec apache2-foreground
