#!/usr/bin/env bash
# docker/start.sh
# Arranque para Laravel en Render (Apache). Hace warm-up, reintenta migraciones y lanza Apache.

set -e

# Render inyecta $PORT; si no existe, usa 8080
: "${PORT:=8080}"

echo "[start] Booting with PORT=${PORT}"

# Hacer que Apache escuche en $PORT
sed -ri "s/Listen 80/Listen ${PORT}/" /etc/apache2/ports.conf
sed -ri "s/:80>/:${PORT}>/g" /etc/apache2/sites-available/000-default.conf

# Crear archivo de healthcheck simple
mkdir -p /var/www/html/public/.well-known
echo "ok" > /var/www/html/public/.well-known/health

# Warm-up de Laravel (sin route:cache porque hay closures en rutas)
echo "[start] Laravel warm-up (permisos, caches)..."
mkdir -p storage/framework/{cache,sessions,views}
chown -R www-data:www-data storage bootstrap/cache
chmod -R 775 storage bootstrap/cache

php artisan storage:link || true
php artisan config:clear || true
php artisan view:clear   || true
php artisan config:cache || true
php artisan view:cache   || true

# Mostrar variables clave para diagnosticar en logs
echo "[start] DB_HOST=${DB_HOST} DB_PORT=${DB_PORT} DB_DATABASE=${DB_DATABASE} DB_USERNAME=${DB_USERNAME}"

# Reintentos de migración (espera a que la BD esté lista)
ATTEMPTS="${MIGRATE_ATTEMPTS:-20}"   # configurable por env si quieres (default 20)
SLEEP_SECS="${MIGRATE_WAIT_SECONDS:-5}" # configurable por env si quieres (default 5s)

i=1
while [ "$i " -le "$ATTEMPTS" ]; do
  echo "[start] Running migrations (attempt ${i}/${ATTEMPTS})..."
  if php artisan migrate --force --no-interaction; then
    echo "[start] Migrations OK ✅"
    break
  else
    echo "[start] Migrations failed. Retrying in ${SLEEP_SECS}s..."
    sleep "${SLEEP_SECS}"
    i=$((i+1))
  fi
done

# Seed opcional controlado por variable de entorno RUN_SEED=1 (ejecútalo una sola vez y quítalo)
if [ "${RUN_SEED:-0}" = "1" ]; then
  echo "[start] Running db:seed (RUN_SEED=1)..."
  php artisan db:seed --force --no-interaction || true
fi

echo "[start] Starting Apache…"
exec apache2-foreground
