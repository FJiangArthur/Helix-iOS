#!/bin/bash
# Helix Docker Development Environment Manager
# This script provides convenient commands for managing the containerized development environment

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Project root directory
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Functions
print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_header() {
    echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
}

show_usage() {
    cat << EOF
Helix Docker Development Environment Manager

Usage: $0 [command] [options]

Commands:
    start           Start all development containers
    stop            Stop all development containers
    restart         Restart all development containers
    build           Build or rebuild containers
    rebuild         Force rebuild all containers from scratch
    shell           Open a bash shell in the Flutter development container
    logs            Show logs from all containers
    clean           Remove all containers and volumes (WARNING: destroys data)
    status          Show status of all containers
    flutter         Run Flutter commands in the container
    test            Run tests in the container
    analyze         Run Flutter analyze in the container
    pub-get         Run flutter pub get in the container
    code-gen        Run build_runner code generation
    doctor          Run flutter doctor in the container
    help            Show this help message

Examples:
    $0 start                    # Start the development environment
    $0 shell                    # Open shell in dev container
    $0 flutter run              # Run the Flutter app
    $0 test                     # Run all tests
    $0 flutter pub get          # Get dependencies
    $0 logs flutter-dev         # Show logs for specific service

Environment Variables:
    OPENAI_API_KEY              OpenAI API key (optional)
    ANTHROPIC_API_KEY           Anthropic API key (optional)

EOF
}

check_docker() {
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed. Please install Docker first."
        exit 1
    fi

    if ! docker info &> /dev/null; then
        print_error "Docker daemon is not running. Please start Docker."
        exit 1
    fi
}

check_docker_compose() {
    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        print_error "Docker Compose is not installed. Please install Docker Compose."
        exit 1
    fi

    # Use 'docker compose' if available, otherwise 'docker-compose'
    if docker compose version &> /dev/null; then
        DOCKER_COMPOSE="docker compose"
    else
        DOCKER_COMPOSE="docker-compose"
    fi
}

cmd_start() {
    print_header "Starting Helix Development Environment"
    cd "$PROJECT_ROOT"

    print_info "Starting containers..."
    $DOCKER_COMPOSE up -d

    print_success "Development environment started!"
    print_info "Run '$0 shell' to open a shell in the development container"
    print_info "Run '$0 logs' to view container logs"
}

cmd_stop() {
    print_header "Stopping Helix Development Environment"
    cd "$PROJECT_ROOT"

    print_info "Stopping containers..."
    $DOCKER_COMPOSE down

    print_success "Development environment stopped!"
}

cmd_restart() {
    print_header "Restarting Helix Development Environment"
    cmd_stop
    cmd_start
}

cmd_build() {
    print_header "Building Helix Development Containers"
    cd "$PROJECT_ROOT"

    print_info "Building containers..."
    $DOCKER_COMPOSE build

    print_success "Containers built successfully!"
}

cmd_rebuild() {
    print_header "Rebuilding Helix Development Containers"
    cd "$PROJECT_ROOT"

    print_warning "This will rebuild all containers from scratch..."
    $DOCKER_COMPOSE build --no-cache

    print_success "Containers rebuilt successfully!"
}

cmd_shell() {
    print_header "Opening Shell in Flutter Development Container"
    cd "$PROJECT_ROOT"

    print_info "Opening bash shell..."
    $DOCKER_COMPOSE exec flutter-dev /bin/bash
}

cmd_logs() {
    cd "$PROJECT_ROOT"

    if [ -z "$1" ]; then
        print_info "Showing logs from all containers (Ctrl+C to exit)..."
        $DOCKER_COMPOSE logs -f
    else
        print_info "Showing logs from $1 (Ctrl+C to exit)..."
        $DOCKER_COMPOSE logs -f "$1"
    fi
}

cmd_clean() {
    print_header "Cleaning Helix Development Environment"
    cd "$PROJECT_ROOT"

    print_warning "This will remove all containers and volumes!"
    read -p "Are you sure? (yes/no): " -r
    echo

    if [[ $REPLY =~ ^[Yy]es$ ]]; then
        print_info "Stopping and removing containers..."
        $DOCKER_COMPOSE down -v

        print_info "Removing project-specific volumes..."
        docker volume rm helix-pub-cache helix-flutter-cache helix-redis-data helix-postgres-data 2>/dev/null || true

        print_success "Environment cleaned!"
    else
        print_info "Clean cancelled."
    fi
}

cmd_status() {
    print_header "Helix Development Environment Status"
    cd "$PROJECT_ROOT"

    print_info "Container status:"
    $DOCKER_COMPOSE ps

    echo ""
    print_info "Volume usage:"
    docker volume ls --filter name=helix
}

cmd_flutter() {
    cd "$PROJECT_ROOT"

    if [ -z "$1" ]; then
        print_error "Please provide a Flutter command"
        echo "Example: $0 flutter run"
        exit 1
    fi

    print_info "Running: flutter $*"
    $DOCKER_COMPOSE exec flutter-dev flutter "$@"
}

cmd_test() {
    print_header "Running Tests in Container"
    cd "$PROJECT_ROOT"

    print_info "Running Flutter tests..."
    $DOCKER_COMPOSE exec flutter-dev flutter test "$@"
}

cmd_analyze() {
    print_header "Running Flutter Analyze"
    cd "$PROJECT_ROOT"

    print_info "Analyzing code..."
    $DOCKER_COMPOSE exec flutter-dev flutter analyze
}

cmd_pub_get() {
    print_header "Getting Flutter Dependencies"
    cd "$PROJECT_ROOT"

    print_info "Running flutter pub get..."
    $DOCKER_COMPOSE exec flutter-dev flutter pub get
}

cmd_code_gen() {
    print_header "Running Code Generation"
    cd "$PROJECT_ROOT"

    print_info "Running build_runner..."
    $DOCKER_COMPOSE exec flutter-dev flutter packages pub run build_runner build --delete-conflicting-outputs
}

cmd_doctor() {
    print_header "Running Flutter Doctor"
    cd "$PROJECT_ROOT"

    print_info "Running flutter doctor..."
    $DOCKER_COMPOSE exec flutter-dev flutter doctor -v
}

# Main script logic
check_docker
check_docker_compose

# Parse command
COMMAND="${1:-help}"
shift || true

case "$COMMAND" in
    start)
        cmd_start
        ;;
    stop)
        cmd_stop
        ;;
    restart)
        cmd_restart
        ;;
    build)
        cmd_build
        ;;
    rebuild)
        cmd_rebuild
        ;;
    shell)
        cmd_shell
        ;;
    logs)
        cmd_logs "$@"
        ;;
    clean)
        cmd_clean
        ;;
    status)
        cmd_status
        ;;
    flutter)
        cmd_flutter "$@"
        ;;
    test)
        cmd_test "$@"
        ;;
    analyze)
        cmd_analyze
        ;;
    pub-get)
        cmd_pub_get
        ;;
    code-gen)
        cmd_code_gen
        ;;
    doctor)
        cmd_doctor
        ;;
    help|--help|-h)
        show_usage
        ;;
    *)
        print_error "Unknown command: $COMMAND"
        echo ""
        show_usage
        exit 1
        ;;
esac
