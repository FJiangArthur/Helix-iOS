#!/bin/sh
# Health check script for Nginx service
# Returns 0 if healthy, 1 if unhealthy

set -e

# Check if Nginx is responding to HTTP requests
if wget --quiet --tries=1 --spider http://localhost/health; then
    echo "Nginx is healthy"
    exit 0
else
    echo "Nginx is not responding"
    exit 1
fi
