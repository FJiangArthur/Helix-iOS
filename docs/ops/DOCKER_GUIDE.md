# Helix Docker Development Guide

Complete guide for using the containerized development environment for Helix.

## Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Docker Services](#docker-services)
- [Development Workflows](#development-workflows)
- [VS Code Dev Containers](#vs-code-dev-containers)
- [Troubleshooting](#troubleshooting)
- [Advanced Usage](#advanced-usage)

## Overview

The Helix project provides a comprehensive containerized development environment that includes:

- **Flutter Development Container**: Complete Flutter SDK with all dependencies
- **Mock API Server**: MockServer for testing AI integrations
- **Redis**: For caching AI responses
- **PostgreSQL**: For conversation history storage
- **Nginx**: Reverse proxy and load balancer
- **Documentation Server**: Live documentation with mkdocs

### Benefits

- **Consistent Environment**: Same development environment for all team members
- **No Local Installation**: No need to install Flutter, Dart, or other dependencies locally
- **Isolated Dependencies**: Project dependencies don't conflict with other projects
- **Easy Onboarding**: New developers can start in minutes
- **Production Parity**: Development environment mirrors production setup

## Prerequisites

### Required

- **Docker**: Version 20.10 or higher
  - Install from: https://docs.docker.com/get-docker/
- **Docker Compose**: Version 2.0 or higher
  - Usually included with Docker Desktop

### Verify Installation

```bash
docker --version
# Docker version 20.10.x or higher

docker compose version
# Docker Compose version v2.x.x or higher
```

### Optional

- **VS Code**: For Dev Containers support
- **Git**: For version control

## Quick Start

### 1. Start the Development Environment

```bash
# Using the helper script
./scripts/docker-dev.sh start

# Or using docker-compose directly
docker compose up -d
```

This will:
- Build the Flutter development container (first time only)
- Start all supporting services (Redis, PostgreSQL, etc.)
- Download and cache Flutter dependencies

### 2. Open a Shell in the Development Container

```bash
./scripts/docker-dev.sh shell
```

You're now inside the container with a complete Flutter development environment!

### 3. Run Your First Flutter Command

```bash
# Inside the container
flutter doctor -v
flutter pub get
flutter run
```

### 4. Stop the Environment

```bash
./scripts/docker-dev.sh stop
```

## Docker Services

### Flutter Development Container (`flutter-dev`)

The main development container with:
- **Flutter SDK**: Version 3.35.0
- **Dart SDK**: Included with Flutter
- **Linux Desktop Support**: Enabled
- **Audio Libraries**: For flutter_sound
- **Development Tools**: vim, git, jq, tree, etc.

**Ports:**
- `9100`: Flutter DevTools
- `9101`: Observatory (Dart VM debugger)
- `9102`: Hot reload server

**Volumes:**
- Project directory mounted at `/workspace`
- Persistent pub cache for fast dependency installation

### Mock API Server (`mock-api`)

MockServer for testing AI integrations without hitting real APIs.

**Port:** `1080`
**Configuration:** `docker/mock-api/expectations.json`

**Usage:**
```bash
# Test the mock API
curl http://localhost:1080/health
```

### Redis (`redis`)

In-memory cache for AI responses and session data.

**Port:** `6379`
**Volume:** `redis-data` (persistent)

### PostgreSQL (`postgres`)

Database for conversation history and analytics.

**Port:** `5432`
**Credentials:**
- Database: `helix_dev`
- Username: `helix`
- Password: `helix_dev_password`

**Connect:**
```bash
psql -h localhost -U helix -d helix_dev
```

### Nginx (`nginx`)

Reverse proxy for API endpoints.

**Port:** `8080`
**Configuration:** `docker/nginx/`

### Documentation Server (`docs`)

Live documentation server with auto-reload.

**Port:** `8000`
**Access:** http://localhost:8000

## Development Workflows

### Using the Helper Script

The `docker-dev.sh` script provides convenient commands:

```bash
# Start/stop environment
./scripts/docker-dev.sh start
./scripts/docker-dev.sh stop
./scripts/docker-dev.sh restart

# Build containers
./scripts/docker-dev.sh build      # Incremental build
./scripts/docker-dev.sh rebuild    # Full rebuild (no cache)

# Development commands
./scripts/docker-dev.sh shell      # Open bash shell
./scripts/docker-dev.sh logs       # Show all logs
./scripts/docker-dev.sh logs flutter-dev  # Show specific service logs
./scripts/docker-dev.sh status     # Show container status

# Flutter commands
./scripts/docker-dev.sh flutter run
./scripts/docker-dev.sh flutter pub get
./scripts/docker-dev.sh test
./scripts/docker-dev.sh analyze
./scripts/docker-dev.sh code-gen
./scripts/docker-dev.sh doctor

# Clean up
./scripts/docker-dev.sh clean      # Remove all containers and volumes
```

### Running Tests

```bash
# Run all tests
./scripts/docker-test.sh all

# Run specific test types
./scripts/docker-test.sh unit
./scripts/docker-test.sh widget
./scripts/docker-test.sh integration

# Generate coverage report
./scripts/docker-test.sh coverage

# Run specific tests
./scripts/docker-test.sh all --name=ai_service
```

### Code Generation

```bash
# Run build_runner for code generation
./scripts/docker-dev.sh code-gen

# Or inside the container
flutter packages pub run build_runner build --delete-conflicting-outputs
```

### Accessing Services

From your host machine:

```bash
# Flutter DevTools
open http://localhost:9100

# Mock API
curl http://localhost:1080/health

# Nginx proxy
curl http://localhost:8080/health

# PostgreSQL
psql -h localhost -p 5432 -U helix -d helix_dev

# Redis
redis-cli -h localhost -p 6379

# Documentation
open http://localhost:8000
```

## VS Code Dev Containers

### Setup

1. **Install Extension**: Install the "Dev Containers" extension in VS Code
2. **Open Project**: Open the Helix-iOS folder in VS Code
3. **Reopen in Container**: Press `F1` and select "Dev Containers: Reopen in Container"

VS Code will:
- Build the development container
- Install recommended extensions
- Configure settings for Flutter development
- Mount your project files

### Features

- **IntelliSense**: Full Dart and Flutter code completion
- **Debugging**: Built-in debugger support
- **Hot Reload**: Automatic hot reload on save
- **Extensions**: Pre-installed Flutter and development extensions
- **Terminal**: Integrated terminal inside the container

### Recommended Extensions (Auto-installed)

- Dart Code (Dart-Code.dart-code)
- Flutter (Dart-Code.flutter)
- GitLens (eamodio.gitlens)
- Docker (ms-azuretools.vscode-docker)
- YAML Support (redhat.vscode-yaml)
- Markdown All in One (yzhang.markdown-all-in-one)

### Customization

Edit `.devcontainer/devcontainer.json` to customize:
- VS Code settings
- Extensions to install
- Port forwarding
- Environment variables
- Container features

## Troubleshooting

### Container Won't Start

**Issue**: Container fails to start or exits immediately

**Solutions:**
```bash
# Check logs
docker compose logs flutter-dev

# Rebuild container
./scripts/docker-dev.sh rebuild

# Check Docker daemon
docker info
```

### Port Already in Use

**Issue**: Port 9100, 5432, or other ports are already allocated

**Solutions:**
```bash
# Find process using the port
lsof -i :9100

# Kill the process
kill -9 <PID>

# Or change port in docker-compose.yml
# Change "9100:9100" to "9101:9100"
```

### Slow Build Times

**Issue**: Initial build takes too long

**Solutions:**
```bash
# Use BuildKit for faster builds
export DOCKER_BUILDKIT=1
docker compose build

# Increase Docker resources in Docker Desktop
# Settings > Resources > Increase CPU and Memory
```

### Permission Issues

**Issue**: Permission denied when accessing files

**Solutions:**
```bash
# Fix ownership (from host)
sudo chown -R $USER:$USER .

# Or rebuild with correct UID/GID
docker compose build --build-arg USER_UID=$(id -u) --build-arg USER_GID=$(id -g)
```

### Flutter Doctor Issues

**Issue**: `flutter doctor` shows warnings

**Solutions:**
```bash
# Accept Android licenses (if needed)
./scripts/docker-dev.sh shell
flutter doctor --android-licenses

# Enable platforms
flutter config --enable-linux-desktop
```

### Out of Space

**Issue**: Docker runs out of disk space

**Solutions:**
```bash
# Remove unused containers and images
docker system prune -a

# Remove volumes (WARNING: deletes data)
docker volume prune

# Check disk usage
docker system df
```

## Advanced Usage

### Custom Environment Variables

Set API keys and environment variables:

```bash
# Create .env file
cat > .env << EOF
OPENAI_API_KEY=sk-your-key
ANTHROPIC_API_KEY=sk-ant-your-key
EOF

# They'll be automatically loaded by docker-compose
```

### Running Multiple Instances

```bash
# Start with custom project name
docker compose -p helix-dev1 up -d
docker compose -p helix-dev2 up -d

# Access specific instance
docker compose -p helix-dev1 exec flutter-dev /bin/bash
```

### Building for Production

```bash
# Build production container
docker build --target production -t helix-app:latest .

# Run production container
docker run -d helix-app:latest
```

### Debugging

```bash
# Attach to running container
docker attach helix-flutter-dev

# Execute commands in running container
docker exec -it helix-flutter-dev flutter pub get

# View real-time logs
docker compose logs -f flutter-dev
```

### Backup and Restore

```bash
# Backup volumes
docker run --rm -v helix-postgres-data:/data -v $(pwd):/backup \
  ubuntu tar czf /backup/postgres-backup.tar.gz /data

# Restore volumes
docker run --rm -v helix-postgres-data:/data -v $(pwd):/backup \
  ubuntu tar xzf /backup/postgres-backup.tar.gz -C /
```

### Network Troubleshooting

```bash
# Inspect network
docker network inspect helix-network

# Check connectivity between services
docker compose exec flutter-dev ping redis
docker compose exec flutter-dev curl http://mock-api:1080/health
```

### Custom Nginx Configuration

Edit `docker/nginx/conf.d/default.conf` and reload:

```bash
docker compose exec nginx nginx -s reload
```

### Database Migrations

```bash
# Connect to PostgreSQL
docker compose exec postgres psql -U helix -d helix_dev

# Run migrations
\i /path/to/migration.sql

# Backup database
docker compose exec postgres pg_dump -U helix helix_dev > backup.sql
```

## Performance Optimization

### Docker Desktop Settings

- **CPU**: Allocate at least 4 cores
- **Memory**: Allocate at least 8GB RAM
- **Disk**: Allocate at least 64GB

### Volume Performance

For better I/O performance on macOS:

```yaml
# Add to docker-compose.yml volumes
volumes:
  - .:/workspace:delegated  # Instead of :cached
```

### Layer Caching

The Dockerfile uses multi-stage builds to optimize layer caching:
- Base Flutter SDK is cached
- Dependencies are cached separately
- Code changes don't invalidate all layers

## CI/CD Integration

### GitHub Actions Example

```yaml
name: Docker Build
on: [push]
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Build and test
        run: |
          docker compose build flutter-dev
          docker compose run flutter-dev flutter test
```

### Building Without Cache

```bash
# For CI/CD environments
docker compose build --no-cache --pull
```

## Best Practices

1. **Keep Containers Running**: Leave containers running during development for faster iteration
2. **Use Helper Scripts**: Use `docker-dev.sh` for common operations
3. **Regular Cleanup**: Run `docker system prune` monthly to free disk space
4. **Version Control**: Commit changes to Docker files with meaningful messages
5. **Environment Variables**: Never commit API keys; use `.env` files
6. **Update Regularly**: Pull latest images and rebuild periodically

## Additional Resources

- [Docker Documentation](https://docs.docker.com/)
- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [VS Code Dev Containers](https://code.visualstudio.com/docs/devcontainers/containers)
- [Flutter Docker](https://docs.flutter.dev/deployment/docker)

## Support

For issues or questions:
1. Check the [Troubleshooting](#troubleshooting) section
2. Review Docker logs: `./scripts/docker-dev.sh logs`
3. Create an issue on GitHub
4. Contact the development team

---

**Last Updated**: November 2025
**Maintainer**: Helix Development Team
