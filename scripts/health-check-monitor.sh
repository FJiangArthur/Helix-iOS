#!/bin/bash
# Health Check Monitoring Script
# Continuously monitors all services and reports health status

set -e

# Configuration
CHECK_INTERVAL=30
LOG_FILE="logs/health-check.log"
ALERT_FILE="logs/health-alerts.log"
METRICS_FILE="logs/health-metrics.json"

# Colors for output
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Create logs directory if it doesn't exist
mkdir -p logs

# Function to log messages
log_message() {
    local level=$1
    shift
    local message="$@"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message" | tee -a "$LOG_FILE"
}

# Function to check service health via HTTP
check_http_health() {
    local service_name=$1
    local url=$2
    local timeout=${3:-5}

    log_message "DEBUG" "Checking $service_name at $url"

    if timeout $timeout curl -sf "$url" > /dev/null 2>&1; then
        echo "healthy"
    else
        echo "unhealthy"
    fi
}

# Function to check Redis health
check_redis_health() {
    if docker exec helix-redis redis-cli ping 2>&1 | grep -q "PONG"; then
        echo "healthy"
    else
        echo "unhealthy"
    fi
}

# Function to check PostgreSQL health
check_postgres_health() {
    if docker exec helix-postgres pg_isready -U helix -d helix_dev > /dev/null 2>&1; then
        echo "healthy"
    else
        echo "unhealthy"
    fi
}

# Function to check Docker container health
check_container_health() {
    local container=$1

    if docker inspect --format='{{.State.Health.Status}}' "$container" 2>/dev/null; then
        return 0
    else
        echo "unknown"
    fi
}

# Function to display service status
display_status() {
    local service=$1
    local status=$2

    case $status in
        healthy|up)
            echo -e "${GREEN}✓${NC} $service: ${GREEN}HEALTHY${NC}"
            ;;
        degraded)
            echo -e "${YELLOW}⚠${NC} $service: ${YELLOW}DEGRADED${NC}"
            ;;
        unhealthy|down)
            echo -e "${RED}✗${NC} $service: ${RED}UNHEALTHY${NC}"
            ;;
        *)
            echo -e "${BLUE}?${NC} $service: ${BLUE}UNKNOWN${NC}"
            ;;
    esac
}

# Function to send alert
send_alert() {
    local service=$1
    local status=$2
    local message=$3

    local alert_msg="[ALERT] $service is $status: $message"
    log_message "ALERT" "$alert_msg"
    echo "$alert_msg" >> "$ALERT_FILE"

    # Here you could integrate with external alerting systems
    # e.g., send to Slack, PagerDuty, email, etc.
}

# Function to collect metrics
collect_metrics() {
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    cat > "$METRICS_FILE" <<EOF
{
  "timestamp": "$timestamp",
  "services": {
EOF

    local first=true
    for service in "${!SERVICE_CHECKS[@]}"; do
        if [ "$first" = false ]; then
            echo "," >> "$METRICS_FILE"
        fi
        first=false

        local status="${SERVICE_STATUS[$service]:-unknown}"
        local health_score=0

        case $status in
            healthy) health_score=100 ;;
            degraded) health_score=50 ;;
            unhealthy) health_score=0 ;;
            *) health_score=25 ;;
        esac

        cat >> "$METRICS_FILE" <<EOF
    "$service": {
      "status": "$status",
      "healthScore": $health_score,
      "lastCheck": "$timestamp"
    }
EOF
    done

    cat >> "$METRICS_FILE" <<EOF

  }
}
EOF
}

# Main monitoring loop
main() {
    log_message "INFO" "Starting health check monitor"
    echo -e "${BLUE}=== Helix Health Check Monitor ===${NC}\n"

    declare -A SERVICE_CHECKS
    declare -A SERVICE_STATUS
    declare -A SERVICE_FAILURES

    # Define service checks
    SERVICE_CHECKS=(
        ["Nginx"]="http://localhost:8080/health"
        ["Mock API"]="http://localhost:1080/health"
        ["Redis"]="redis"
        ["PostgreSQL"]="postgres"
    )

    while true; do
        clear
        echo -e "${BLUE}=== Health Check Results ===${NC}"
        echo -e "Time: $(date '+%Y-%m-%d %H:%M:%S')\n"

        local unhealthy_count=0

        # Check each service
        for service in "${!SERVICE_CHECKS[@]}"; do
            local check_type="${SERVICE_CHECKS[$service]}"
            local status="unknown"

            case $service in
                "Redis")
                    status=$(check_redis_health)
                    ;;
                "PostgreSQL")
                    status=$(check_postgres_health)
                    ;;
                *)
                    status=$(check_http_health "$service" "$check_type")
                    ;;
            esac

            SERVICE_STATUS[$service]=$status
            display_status "$service" "$status"

            # Track failures and send alerts
            if [ "$status" = "unhealthy" ]; then
                ((unhealthy_count++))
                SERVICE_FAILURES[$service]=$((${SERVICE_FAILURES[$service]:-0} + 1))

                # Alert if service has been unhealthy for 3 consecutive checks
                if [ ${SERVICE_FAILURES[$service]} -ge 3 ]; then
                    send_alert "$service" "unhealthy" "Service has failed ${SERVICE_FAILURES[$service]} consecutive checks"
                fi
            else
                SERVICE_FAILURES[$service]=0
            fi
        done

        # Check Docker container health
        echo -e "\n${BLUE}=== Container Health ===${NC}"
        for container in helix-redis helix-postgres helix-nginx helix-mock-api; do
            if docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
                local health=$(check_container_health "$container")
                display_status "$container" "$health"
            fi
        done

        # Summary
        echo -e "\n${BLUE}=== Summary ===${NC}"
        echo "Total services: ${#SERVICE_CHECKS[@]}"
        echo "Unhealthy: $unhealthy_count"

        if [ $unhealthy_count -gt 0 ]; then
            echo -e "${RED}⚠ System health is degraded${NC}"
        else
            echo -e "${GREEN}✓ All services are healthy${NC}"
        fi

        # Collect metrics
        collect_metrics

        # Wait for next check
        echo -e "\nNext check in ${CHECK_INTERVAL} seconds (Ctrl+C to stop)..."
        sleep $CHECK_INTERVAL
    done
}

# Handle script termination
trap 'log_message "INFO" "Health check monitor stopped"; exit 0' INT TERM

# Run main function
main
