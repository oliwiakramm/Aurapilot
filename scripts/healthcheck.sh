#!/bin/bash

set -euo pipefail

PASSED=0
FAILED=0
CONTAINER_NAME="aurapilot"

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

if docker info > /dev/null 2>&1; then
     echo -e "${GREEN}✓${NC} Docker is running"
     PASSED=$((PASSED + 1))
else
    echo -e "${RED}✗${NC} Docker is not running"
    FAILED=$((FAILED + 1))
fi

if docker ps -q -f name=$CONTAINER_NAME | grep -q .; then
    echo -e "${GREEN}✓${NC} Container $CONTAINER_NAME is running"
    PASSED=$((PASSED + 1))
else
     echo -e "${RED}✗${NC} Container $CONTAINER_NAME is not running"
    FAILED=$((FAILED + 1))
fi

if test -f scripts/collector.sh; then
    echo -e "${GREEN}✓${NC} Collector script exists"
    PASSED=$((PASSED + 1))
else
    echo -e "${RED}✗${NC} Collector script does not exist"
    FAILED=$((FAILED + 1))
fi

if docker compose exec aurapilot python3 -c "import yaml" > /dev/null 2>&1 ; then
    echo -e "${GREEN}✓${NC} PyYAML is installed"
    PASSED=$((PASSED + 1))
else
    echo -e "${RED}✗${NC} PyYAML is not installed"
    FAILED=$((FAILED + 1))
fi

echo "Passed: $PASSED/ $(($PASSED + $FAILED))"