#!/bin/bash
set -euo pipefail

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
METRICS_DIR="metrics"
SNAPSHOT_FILE="${METRICS_DIR}/snapshot_${TIMESTAMP}.json"

mkdir -p "$METRICS_DIR"

# ----- CPU -----

CPU_LINE=$(top -bn1 | grep "Cpu(s)")
CPU_IDLE=$(echo "$CPU_LINE" | grep -oP '[\d.]+(?=\s*id)' | tr -d ' ')
CPU_USAGE=$(echo "scale=1; 100 - $CPU_IDLE" | bc | sed 's/^\./0./')
CPU_CORES=$(nproc)

# ----- LOAD AVERAGE -----

LOAD_1=$(awk '{print $1}' /proc/loadavg)
LOAD_5=$(awk '{print $2}' /proc/loadavg)
LOAD_15=$(awk '{print $3}' /proc/loadavg)

# ----- RAM -----

MEM_TOTAL_KB=$(grep "^MemTotal:" /proc/meminfo | awk '{print $2}')
MEM_AVAILABLE_KB=$(grep "^MemAvailable:" /proc/meminfo | awk '{print $2}')
MEM_FREE_KB=$(grep "^MemFree:" /proc/meminfo | awk '{print $2}')
MEM_BUFFERS_KB=$(grep "^Buffers:" /proc/meminfo | awk '{print $2}')
MEM_CACHED_KB=$(grep "^Cached:" /proc/meminfo | awk '{print $2}')
MEM_USED_KB=$(( MEM_TOTAL_KB - MEM_AVAILABLE_KB ))

MEM_TOTAL_GB=$(echo "scale=2; $MEM_TOTAL_KB / 1048576" | bc | sed 's/^\./0./')
MEM_USED_GB=$(echo "scale=2; $MEM_USED_KB / 1048576" | bc | sed 's/^\./0./')
MEM_FREE_GB=$(echo "scale=2; $MEM_FREE_KB / 1048576" | bc | sed 's/^\./0./')
MEM_USED_PERCENT=$(echo "scale=1; $MEM_USED_KB * 100 / $MEM_TOTAL_KB" | bc | sed 's/^\./0./')

# ----- SWAP -----
SWAP_TOTAL_KB=$(grep "^SwapTotal:" /proc/meminfo | awk '{print $2}')
SWAP_FREE_KB=$(grep "^SwapFree:" /proc/meminfo | awk '{print $2}')
SWAP_USED_KB=$(( SWAP_TOTAL_KB - SWAP_FREE_KB ))
SWAP_TOTAL_GB=$(echo "scale=2; $SWAP_TOTAL_KB / 1048576" | bc | sed 's/^\./0./')
SWAP_USED_GB=$(echo "scale=2; $SWAP_USED_KB / 1048576" | bc | sed 's/^\./0./')

# ----- DISK -----

DISK_LINE=$(df -Pk | grep -v tmpfs | grep -v devtmpfs | tail -n +2 | head -1)
DISK_TOTAL_KB=$(echo "$DISK_LINE" | awk '{print $2}')
DISK_USED_KB=$(echo "$DISK_LINE" | awk '{print $3}')
DISK_FREE_KB=$(echo "$DISK_LINE" | awk '{print $4}')
DISK_PCT=$(echo "$DISK_LINE" | awk '{print $5}' | tr -d '%')
DISK_MOUNT=$(echo "$DISK_LINE" | awk '{print $6}')

# ----- network -----

NET_LINE=$(grep "eth0" /proc/net/dev 2>/dev/null || echo "eth0: 0 0 0 0 0 0 0 0 0 0")
NET_RX_BYTES=$(echo "$NET_LINE" | awk '{print $2}')
NET_TX_BYTES=$(echo "$NET_LINE" | awk '{print $10}')

# ----- TOP PROCESSES -----
TOP_CPU=$(ps -eo pid,comm,pcpu,pmem --sort=-%cpu | head -6 | tail -5 | \
  tr -s ' ' | sed 's/^ //' | \
  awk '{printf "{\"pid\":%s,\"name\":\"%s\",\"cpu\":%s,\"mem\":%s}\n", $1, $2, $3, $4}' | \
  paste -sd',' -)

TOP_MEM=$(ps -eo pid,comm,pcpu,pmem --sort=-%mem | head -6 | tail -5 | \
  tr -s ' ' | sed 's/^ //' | \
  awk '{printf "{\"pid\":%s,\"name\":\"%s\",\"cpu\":%s,\"mem\":%s}\n", $1, $2, $3, $4}' | \
  paste -sd',' -)

# ----- 9. UPTIME -----

UPTIME_SECONDS=$(awk '{print $1}' /proc/uptime | cut -d. -f1)

# ----- SYSTEM ERRORS -----

JOURNAL_ERRORS=$(journalctl --since "10 minutes ago" -p err -q 2>/dev/null | \
  head -10 | \
  awk '{printf "\"%s\"\n", $0}' | \
  paste -sd',' - || echo "")

if [ -z "$JOURNAL_ERRORS" ]; then
  JOURNAL_JSON="[]"
else
  JOURNAL_JSON="[$JOURNAL_ERRORS]"
fi

# ----- BUILDING JSON -----
cat << EOF > "$SNAPSHOT_FILE"
{
  "timestamp": "$TIMESTAMP",
  "cpu": {
    "usage_percent": $CPU_USAGE,
    "idle_percent": $CPU_IDLE,
    "cores": $CPU_CORES,
    "load_avg": {
      "1min": $LOAD_1,
      "5min": $LOAD_5,
      "15min": $LOAD_15
    }
  },
  "ram": {
    "total_gb": $MEM_TOTAL_GB,
    "used_gb": $MEM_USED_GB,
    "free_gb": $MEM_FREE_GB,
    "used_percent": $MEM_USED_PERCENT,
    "buffers_kb": $MEM_BUFFERS_KB,
    "cached_kb": $MEM_CACHED_KB
  },
  "swap": {
    "total_gb": $SWAP_TOTAL_GB,
    "used_gb": $SWAP_USED_GB
  },
  "disk": {
    "mount": "$DISK_MOUNT",
    "total_kb": $DISK_TOTAL_KB,
    "used_kb": $DISK_USED_KB,
    "free_kb": $DISK_FREE_KB,
    "used_percent": $DISK_PCT
  },
  "network": {
    "interface": "eth0",
    "rx_bytes": $NET_RX_BYTES,
    "tx_bytes": $NET_TX_BYTES
  },
  "top_processes": {
    "by_cpu": [$TOP_CPU],
    "by_mem": [$TOP_MEM]
  },
  "uptime_seconds": $UPTIME_SECONDS,
  "system_errors": $JOURNAL_JSON
}
EOF

# ----- JSON VALIDATION -----
echo "JSON validation..."
if python3 -m json.tool "$SNAPSHOT_FILE" > /dev/null 2>&1; then
  echo "✓ Valid JSON: $SNAPSHOT_FILE"
else
  echo "✗ Invalid JSON — removing file"
  rm -f "$SNAPSHOT_FILE"
  exit 1
fi