#!/bin/bash
set -euo pipefail

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
METRICS_DIR="metrics"
OUTPUT_FILE="${METRICS_DIR}/snapshot_${TIMESTAMP}.json"


# ----- CPU -----

CPU_LINE=$(top -bn1 | grep "Cpu(s)")
CPU_IDLE=$(echo "$CPU_LINE" | grep -oP '[\d.]+(?=\s*id)' | tr -d ' ')
CPU_USAGE=$(echo "scale=1; 100 - $CPU_IDLE" | bc | sed 's/^\./0./')
CPU_CORES=$(nproc)


# ----- LOAD AVERAGE -----

LOAD_1=$(cat /proc/loadavg | awk '{print $1}')
LOAD_5=$(cat /proc/loadavg | awk '{print $2}')
LOAD_15=$(cat /proc/loadavg | awk '{print $3}')

# ----- RAM -----

RAM_TOTAL_BYTES=$(free -b | grep Mem | awk '{print $2}')
RAM_USED_BYTES=$(free -b | grep Mem | awk '{print $3}')
RAM_FREE_BYTES=$(free -b | grep Mem | awk '{print $4}')
RAM_TOTAL_GB=$(echo "scale=2; $RAM_TOTAL_BYTES / 1073741824" | bc | sed 's/^\./0./')
RAM_USED_GB=$(echo "scale=2; $RAM_USED_BYTES / 1073741824" | bc | sed 's/^\./0./')
RAM_FREE_GB=$(echo "scale=2; $RAM_FREE_BYTES / 1073741824" | bc | sed 's/^\./0./')
RAM_USED_PERCENT=$(echo "scale=1; $RAM_USED_BYTES * 100 / $RAM_TOTAL_BYTES" | bc | sed 's/^\./0./')
# ----- DISK -----
DISK_LINE=$(df -k / | tail -1)
DISK_TOTAL_KB=$(echo "$DISK_LINE" | awk '{print $2}')
DISK_USED_KB=$(echo "$DISK_LINE" | awk '{print $3}')
DISK_FREE_KB=$(echo "$DISK_LINE" | awk '{print $4}')
DISK_PCT=$(echo "$DISK_LINE" | awk '{print $5}' | tr -d '%')

# ----- TOP PROCESSES -----
TOP_CPU=$(ps -eo pid,comm,pcpu,pmem --sort=-%cpu | head -6 | tail -5 | \
  tr -s ' ' | sed 's/^ //' | \
  awk '{printf "{\"pid\":%s,\"name\":\"%s\",\"cpu\":%s,\"mem\":%s}\n", $1, $2, $3, $4}' | \
  paste -sd',' -)

TOP_MEM=$(ps -eo pid,comm,pcpu,pmem --sort=-%mem | head -6 | tail -5 | \
  tr -s ' ' | sed 's/^ //' | \
  awk '{printf "{\"pid\":%s,\"name\":\"%s\",\"cpu\":%s,\"mem\":%s}\n", $1, $2, $3, $4}' | \
  paste -sd',' -)

# ----- UPTIME -----
UPTIME_STR=$(uptime | awk -F'up ' '{print $2}' | awk -F',' '{print $1}' | xargs)

# ----- JSON -----
cat << EOF > "$OUTPUT_FILE"
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
    "total_gb": $RAM_TOTAL_GB,
    "used_gb": $RAM_USED_GB,
    "free_gb": $RAM_FREE_GB,
     "used_percent": $RAM_USED_PERCENT
  },
  "disk": {
    "total_kb": $DISK_TOTAL_KB,
    "used_kb": $DISK_USED_KB,
    "free_kb": $DISK_FREE_KB,
    "used_percent": $DISK_PCT
  },
  "top_processes": {
    "by_cpu": [$TOP_CPU],
    "by_mem": [$TOP_MEM]
  },
  "uptime": "$UPTIME_STR"
}
EOF

# ----- JSON VALIDATION -----
echo "JSON validation..."
python3 -m json.tool "$OUTPUT_FILE" > /dev/null && echo "Valid JSON: $OUTPUT_FILE"