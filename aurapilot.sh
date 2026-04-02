#!/bin/bash
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' 

usage() {
    echo "Usage: ./aurapilot.sh [command]"
    echo ""
    echo "Commands:"
    echo "  status   - show current metrics"
    echo "  collect  - collect and save snapshot"
    echo "  analyze  - analyze with AI (not yet implemented)"
    echo "  clean    - remove snapshots older than 7 days"
    echo "  health   - run healthcheck"
}

cmd_status() {
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

    echo -e "${GREEN}========== AURAPILOT STATUS ==========${NC}"
    echo -e "${YELLOW}CPU:${NC}"

    if (( $(echo "$CPU_USAGE >= 95" | bc) )); then
        CPU_COLOR=$RED
    elif (( $(echo "$CPU_USAGE >= 85" | bc) )); then
        CPU_COLOR=$YELLOW
    else
        CPU_COLOR=$GREEN
    fi

    echo -e "Usage: ${CPU_COLOR}${CPU_USAGE}%${NC}"
    echo -e "Cores: ${CPU_CORES}"
    echo -e "${YELLOW}RAM:${NC}"
    echo -e "Total GB: ${RAM_TOTAL_GB}"
    echo -e "Used GB: ${RAM_USED_GB}"
    echo -e "Free GB: ${RAM_FREE_GB}"

    if (( $(echo "$RAM_USED_PERCENT >= 93" | bc) )); then
        RAM_COLOR=$RED
    elif (( $(echo "$RAM_USED_PERCENT >= 80" | bc) )); then
        RAM_COLOR=$YELLOW
    else
        RAM_COLOR=$GREEN
    fi

    echo -e "Used %: ${RAM_COLOR}${RAM_USED_PERCENT}%${NC}"
    echo -e "${YELLOW}Disk:${NC}"
    echo -e "Total KB: ${DISK_TOTAL_KB}"
    echo -e "Used KB: ${DISK_USED_KB}"
    echo -e "Free KB: ${DISK_FREE_KB}"

    if (( $(echo "$DISK_PCT >= 92" | bc) )); then
        DISK_COLOR=$RED
    elif (( $(echo "$DISK_PCT >= 80" | bc) )); then
        DISK_COLOR=$YELLOW
    else
        DISK_COLOR=$GREEN
    fi

    echo -e "Used %: ${DISK_COLOR}${DISK_PCT}%${NC}"
}

cmd_collect() {
    echo "Collecting system metrics"
    ./scripts/collector.sh
}

cmd_analyze() {
    echo -e "${YELLOW} Checking API status.${NC}"
    if ! curl -sf http://localhost:8000/health > /dev/null; then
        echo -e "${RED}Error: API is not responding."
        exit 1
    fi

    echo -e "${GREEN} API is available. Downloading and analysing new snapshot..."

    RESPONSE=$(curl -sf http://localhost:8000/analyze/latest)

    if [ -z "$RESPONSE" ]; then
        echo -e "${RED}Error: API did not return anything. Are there any snapshots generated in metrics/? First run './aurapilot.sh collect'.${NC}"
        exit 1
    fi

    ALERTS_COUNT=$(echo "$RESPONSE" | jq '.alerts | length')

    echo -e "\n================ ALERTS ($ALERTS_COUNT) ================"

    if [ "$ALERTS_COUNT" -gt 0 ]; then
        echo "$RESPONSE" | jq -c '.alerts[]' | while read -r alert; do
            SEVERITY=$(echo "$alert" | jq -r '.severity')
            NAME=$(echo "$alert" | jq -r '.name')
            MESSAGE=$(echo "$alert" | jq -r '.message')
            
            if [ "$SEVERITY" == "CRITICAL" ]; then
                echo -e "🔴 ${RED}[$SEVERITY]${NC} $NAME: $MESSAGE"
            elif [ "$SEVERITY" == "WARNING" ]; then
                echo -e "🟡 ${YELLOW}[$SEVERITY]${NC} $NAME: $MESSAGE"
            else
                echo -e "🔵 ${BLUE}[$SEVERITY]${NC} $NAME: $MESSAGE"
            fi
        done
    else
        echo -e " ${GREEN}All is good. No alerts.${NC}"
    fi

    echo -e "\n================ AI REPORT  ================"
    echo "$RESPONSE" | jq -r '.analysis'
    echo -e "===========================================\n"
}

cmd_clean() {
    echo -e "${YELLOW}Removing old snapshots...${NC}"
    find metrics/ -name "*.json" -type f -mtime +7 -delete
    echo -e "${GREEN}Removed snapshots older than 7 days.${NC}"
}

cmd_health() {
    ./scripts/healthcheck.sh
}

case "${1:-}" in
    status)  cmd_status ;;
    collect) cmd_collect ;;
    analyze) cmd_analyze ;;
    clean)   cmd_clean ;;
    health)  cmd_health ;;
    *)       usage ;;
esac