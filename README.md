# macOS Native PHP & Laravel Stack Benchmark

A lightweight, read-only benchmark script for Apple Silicon and Intel Macs that measures actual RSS memory usage and cold CLI/Artisan execution timing on your own machine—without touching project files or system settings.

## Usage

Inspect and run locally:

```bash
curl -fsSLO https://stratosapp.dev/tools/macos-laravel-stack-benchmark.sh
bash macos-laravel-stack-benchmark.sh /path/to/laravel-app
```

Or run directly from this repo against the current directory:

```bash
bash macos-laravel-stack-benchmark.sh .
```

## What It Measures

1. **Process Memory Footprint (`ps -axo rss,comm`)**: Compares resident memory (MB) of native `nginx`, `dnsmasq`, `php-fpm`, and `Stratos` processes against running Docker Desktop VM processes (`com.docker.virtualization`, `com.docker.hyperkit`, `qemu-system-aarch64`, `Docker Desktop`).
2. **20-Iteration PHP CLI Startup (`php -r 'echo 1;'`)**: Measures total, average, min, and max milliseconds per PHP process launch using Python's `time.perf_counter()`.
3. **10-Iteration Laravel `artisan --version` Timing**: When pointed at a Laravel directory containing `artisan`, measures real composer-autoload + Laravel bootstrap latency on native APFS.

> **Ready to move off Docker Desktop / Sail overhead on macOS?**  
> Check the architecture guide at [Apple Silicon Docker Desktop vs. Native Swift PHP & Laravel](https://stratosapp.dev/docs/apple-silicon-docker-desktop-vs-native-swift-php-laravel/) or download [Stratos](https://stratosapp.dev/download/) (PHP 8.1–8.5, Nginx, trusted `.test` HTTPS, Visual Tinker, DB Hub & built-in Cursor/Claude Code MCP bridge).
