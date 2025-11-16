# Helix Docker Quick Reference

Quick reference for the Helix containerized development environment.

## Quick Start

```bash
# Start development environment
./scripts/docker-dev.sh start

# Open shell in container
./scripts/docker-dev.sh shell

# Run Flutter app
./scripts/docker-dev.sh flutter run

# Run tests
./scripts/docker-test.sh all

# Stop environment
./scripts/docker-dev.sh stop
```

## Essential Commands

### Environment Management

| Command | Description |
|---------|-------------|
| `./scripts/docker-dev.sh start` | Start all containers |
| `./scripts/docker-dev.sh stop` | Stop all containers |
| `./scripts/docker-dev.sh restart` | Restart all containers |
| `./scripts/docker-dev.sh status` | Show container status |
| `./scripts/docker-dev.sh logs` | View all logs |
| `./scripts/docker-dev.sh clean` | Remove all containers and volumes |

### Development

| Command | Description |
|---------|-------------|
| `./scripts/docker-dev.sh shell` | Open bash shell in dev container |
| `./scripts/docker-dev.sh flutter <cmd>` | Run Flutter commands |
| `./scripts/docker-dev.sh pub-get` | Get Flutter dependencies |
| `./scripts/docker-dev.sh code-gen` | Run code generation |
| `./scripts/docker-dev.sh analyze` | Run Flutter analyze |
| `./scripts/docker-dev.sh doctor` | Run Flutter doctor |

### Testing

| Command | Description |
|---------|-------------|
| `./scripts/docker-test.sh all` | Run all tests |
| `./scripts/docker-test.sh unit` | Run unit tests |
| `./scripts/docker-test.sh widget` | Run widget tests |
| `./scripts/docker-test.sh integration` | Run integration tests |
| `./scripts/docker-test.sh coverage` | Generate coverage report |

### Container Management

| Command | Description |
|---------|-------------|
| `./scripts/docker-dev.sh build` | Build containers |
| `./scripts/docker-dev.sh rebuild` | Rebuild from scratch |
| `docker compose ps` | List running containers |
| `docker compose logs -f <service>` | Follow logs for service |

## Services and Ports

| Service | Port | Description |
|---------|------|-------------|
| Flutter Dev | - | Main development container |
| DevTools | 9100 | Flutter DevTools |
| Observatory | 9101 | Dart VM debugger |
| Hot Reload | 9102 | Flutter hot reload |
| Mock API | 1080 | MockServer for testing |
| PostgreSQL | 5432 | Database |
| Redis | 6379 | Cache |
| Nginx | 8080 | Reverse proxy |
| Docs | 8000 | Documentation server |

## VS Code Dev Containers

1. Install "Dev Containers" extension
2. Open project in VS Code
3. Press `F1` → "Dev Containers: Reopen in Container"
4. Wait for container to build
5. Start developing!

## Common Tasks

### Install Dependencies

```bash
./scripts/docker-dev.sh pub-get
```

### Generate Code (Freezed/JSON)

```bash
./scripts/docker-dev.sh code-gen
```

### Run App on Linux

```bash
./scripts/docker-dev.sh flutter run -d linux
```

### Run Tests with Coverage

```bash
./scripts/docker-test.sh coverage
```

### Access PostgreSQL

```bash
# From host
psql -h localhost -p 5432 -U helix -d helix_dev

# Password: helix_dev_password
```

### Access Redis

```bash
# From host
redis-cli -h localhost -p 6379
```

### View Logs

```bash
# All services
./scripts/docker-dev.sh logs

# Specific service
./scripts/docker-dev.sh logs flutter-dev
./scripts/docker-dev.sh logs postgres
```

## Environment Variables

Create a `.env` file in the project root:

```bash
# .env
OPENAI_API_KEY=sk-your-openai-key
ANTHROPIC_API_KEY=sk-ant-your-anthropic-key
```

These will be automatically loaded by docker-compose.

## Troubleshooting

### Container won't start

```bash
./scripts/docker-dev.sh rebuild
```

### Port already in use

```bash
# Find process
lsof -i :9100

# Kill process
kill -9 <PID>
```

### Permission errors

```bash
# Fix ownership
sudo chown -R $USER:$USER .
```

### Out of disk space

```bash
# Clean up Docker
docker system prune -a
docker volume prune
```

## File Structure

```
Helix-iOS/
├── .devcontainer/           # VS Code dev container config
│   ├── devcontainer.json
│   └── Dockerfile
├── docker/                  # Docker service configs
│   ├── mock-api/
│   ├── nginx/
│   └── postgres/
├── scripts/                 # Helper scripts
│   ├── docker-dev.sh
│   └── docker-test.sh
├── docs/                    # Documentation
│   └── DOCKER_GUIDE.md
├── Dockerfile               # Main Dockerfile
├── docker-compose.yml       # Service orchestration
├── .dockerignore           # Docker ignore rules
└── DOCKER_README.md        # This file
```

## Next Steps

1. **Read Full Guide**: See [docs/DOCKER_GUIDE.md](docs/DOCKER_GUIDE.md) for detailed documentation
2. **Start Development**: Run `./scripts/docker-dev.sh start`
3. **Open in VS Code**: Use Dev Containers for best experience
4. **Run Tests**: Ensure everything works with `./scripts/docker-test.sh all`

## Support

- **Full Documentation**: [docs/DOCKER_GUIDE.md](docs/DOCKER_GUIDE.md)
- **Main README**: [README.md](README.md)
- **Issues**: GitHub Issues
- **Team**: Contact Helix development team

---

For detailed documentation, troubleshooting, and advanced usage, see [docs/DOCKER_GUIDE.md](docs/DOCKER_GUIDE.md).
