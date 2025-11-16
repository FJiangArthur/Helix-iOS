#!/bin/sh
# Health check script for PostgreSQL service
# Returns 0 if healthy, 1 if unhealthy

set -e

# Check if PostgreSQL is ready to accept connections
if pg_isready -U helix -d helix_dev; then
    echo "PostgreSQL is healthy"
    exit 0
else
    echo "PostgreSQL is not ready"
    exit 1
fi
