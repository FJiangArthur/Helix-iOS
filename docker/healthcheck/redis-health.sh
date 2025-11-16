#!/bin/sh
# Health check script for Redis service
# Returns 0 if healthy, 1 if unhealthy

set -e

# Check if Redis is responding to PING
if redis-cli ping | grep -q "PONG"; then
    echo "Redis is healthy"
    exit 0
else
    echo "Redis is not responding"
    exit 1
fi
