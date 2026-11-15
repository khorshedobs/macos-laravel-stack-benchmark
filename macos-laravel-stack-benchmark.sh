#!/usr/bin/env bash
set -uo pipefail

# macos-laravel-stack-benchmark.sh
# Read-only macOS diagnostic & local timing helper comparing native PHP/Nginx memory & CLI latency
# against running Docker Desktop VM processes on your own Mac.
# Part of Stratos open-source sidecar tools (https://stratosapp.dev)

TARGET_DIR="${1:-.}"
if [ ! -d "$TARGET_DIR" ]; then
  echo "Error: Directory not found: ${TARGET_DIR}" >&2
  exit 1
fi

PROJECT_DIR="$(cd "$TARGET_DIR" && pwd)"
ARCH="$(uname -m)"
MACOS_VER="$(sw_vers -productVersion 2>/dev/null || echo unknown)"
CPU_BRAND="$(sysctl -n machdep.cpu.brand_string 2>/dev/null || echo "Apple Silicon / macOS")"

echo "================================================================"
echo " macOS Native PHP / Laravel Stack Benchmark (Read-Only)"
echo " Host:    macOS ${MACOS_VER} (${ARCH}) — ${CPU_BRAND}"
echo " Target:  ${PROJECT_DIR}"
echo "================================================================"
echo ""

# 1. Process Memory Snapshot (RSS in MB via ps)
echo "[1/3] Measuring local web stack vs Docker Desktop memory (RSS MB)..."
PS_SNAPSHOT="$(ps -axo rss,comm 2>/dev/null || true)"

sum_rss_mb() {
  local pattern="$1"
  printf '%s\n' "$PS_SNAPSHOT" | awk -v pat="$pattern" '
    BEGIN { IGNORECASE = 1; sum = 0; count = 0 }
    $0 ~ pat { sum += $1; count += 1 }
    END { printf "%d %.1f", count, sum / 1024.0 }
  '
}

read -r NATIVE_NGINX_CNT NATIVE_NGINX_MB <<< "$(sum_rss_mb '(^|/)(nginx|dnsmasq)$')"
read -r NATIVE_PHP_CNT NATIVE_PHP_MB <<< "$(sum_rss_mb '(^|/)php-fpm')"
read -r STRATOS_CNT STRATOS_MB <<< "$(sum_rss_mb '(^|/)Stratos$')"
read -r DOCKER_CNT DOCKER_MB <<< "$(sum_rss_mb 'com\.docker\.(virtualization|hyperkit|backend|vpnkit)|qemu-system-|Docker Desktop')"

echo "  Native Nginx/Dnsmasq : ${NATIVE_NGINX_MB} MB (${NATIVE_NGINX_CNT} process(es))"
echo "  Native PHP-FPM       : ${NATIVE_PHP_MB} MB (${NATIVE_PHP_CNT} process(es))"
echo "  Stratos App (UI)     : ${STRATOS_MB} MB (${STRATOS_CNT} process(es))"
if [ "$DOCKER_CNT" -gt 0 ]; then
  echo "  Docker Desktop / VM  : ${DOCKER_MB} MB (${DOCKER_CNT} process(es))"
else
  echo "  Docker Desktop / VM  : Not currently running (0 processes)"
fi
echo ""

# Locate PHP binary (PATH or Stratos managed runtime)
PHP_BIN="$(command -v php || true)"
if [ -z "$PHP_BIN" ]; then
  for CAND in "$HOME/Library/Application Support/Stratos/bin/php8.4/bin/php" \
              "$HOME/Library/Application Support/Stratos/bin/php8.3/bin/php" \
              "$HOME/Library/Application Support/Stratos/bin/php8.2/bin/php"; do
    if [ -x "$CAND" ]; then
      PHP_BIN="$CAND"
      break
    fi
  done
fi

PYTHON_BIN="$(command -v python3 || true)"

# 2. 20-iteration PHP CLI cold startup latency
echo "[2/3] Measuring 20-iteration PHP CLI cold startup latency..."
if [ -n "$PHP_BIN" ] && [ -n "$PYTHON_BIN" ]; then
  PHP_VER="$("$PHP_BIN" -r 'echo PHP_VERSION;' 2>/dev/null || echo "unknown")"
  echo "  PHP binary: ${PHP_BIN} (PHP ${PHP_VER})"
  "$PYTHON_BIN" - "$PHP_BIN" <<'PY'
import subprocess
import sys
import time

php_bin = sys.argv[1]
iterations = 20
samples = []
for _ in range(iterations):
    t0 = time.perf_counter()
    subprocess.run([php_bin, "-r", "echo 1;"], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    samples.append((time.perf_counter() - t0) * 1000.0)

total_ms = sum(samples)
avg_ms = total_ms / iterations
min_ms = min(samples)
max_ms = max(samples)
print(f"  20 runs total: {total_ms:.1f} ms | avg: {avg_ms:.2f} ms | min: {min_ms:.2f} ms | max: {max_ms:.2f} ms")
PY
else
  echo "  INFO: Skipping PHP CLI timing (requires both php and python3)."
fi
echo ""

# 3. 10-iteration php artisan --version timing inside a Laravel project
echo "[3/3] Measuring 10-iteration Laravel 'php artisan --version' startup..."
ARTISAN_FILE="${PROJECT_DIR}/artisan"
if [ -f "$ARTISAN_FILE" ] && [ -n "$PHP_BIN" ] && [ -n "$PYTHON_BIN" ]; then
  ARTISAN_OUT="$("$PHP_BIN" "$ARTISAN_FILE" --version 2>/dev/null | head -n 1 || echo "Laravel")"
  echo "  Project: ${ARTISAN_OUT} (${PROJECT_DIR})"
  "$PYTHON_BIN" - "$PHP_BIN" "$PROJECT_DIR" <<'PY'
import subprocess
import sys
import time

php_bin, cwd = sys.argv[1], sys.argv[2]
iterations = 10
samples = []
for _ in range(iterations):
    t0 = time.perf_counter()
    res = subprocess.run([php_bin, "artisan", "--version"], cwd=cwd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    if res.returncode != 0:
        print(f"  WARN: 'php artisan --version' exited with code {res.returncode}; aborting Artisan benchmark.")
        sys.exit(0)
    samples.append((time.perf_counter() - t0) * 1000.0)

total_ms = sum(samples)
avg_ms = total_ms / iterations
min_ms = min(samples)
max_ms = max(samples)
print(f"  10 runs total: {total_ms:.1f} ms | avg: {avg_ms:.2f} ms | min: {min_ms:.2f} ms | max: {max_ms:.2f} ms")
PY
elif [ ! -f "$ARTISAN_FILE" ]; then
  echo "  INFO: No 'artisan' file found in ${PROJECT_DIR}; pass a Laravel directory to measure Artisan startup."
  echo "        Example: bash macos-laravel-stack-benchmark.sh ~/Sites/my-laravel-app"
else
  echo "  INFO: Skipping Artisan timing (requires php and python3)."
fi
echo ""

echo "================================================================"
echo " Done! Compare VirtioFS vs native APFS architecture notes here:"
echo "   https://stratosapp.dev/docs/apple-silicon-docker-desktop-vs-native-swift-php-laravel/"
echo " Run native PHP 8.1-8.5, Nginx, DB Hub & MCP on macOS -> https://stratosapp.dev/download/"
echo "================================================================"
