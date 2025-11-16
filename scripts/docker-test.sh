#!/bin/bash
# Helix Docker Test Runner
# Specialized script for running tests in containerized environment

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Detect docker compose command
if docker compose version &> /dev/null; then
    DOCKER_COMPOSE="docker compose"
else
    DOCKER_COMPOSE="docker-compose"
fi

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
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
Helix Docker Test Runner

Usage: $0 [test-type] [options]

Test Types:
    all             Run all tests (default)
    unit            Run unit tests only
    widget          Run widget tests only
    integration     Run integration tests only
    coverage        Run tests with coverage report

Options:
    --name=PATTERN  Run tests matching the pattern
    --watch         Watch for changes and re-run tests
    --verbose       Show verbose output

Examples:
    $0 all                          # Run all tests
    $0 unit                         # Run unit tests
    $0 coverage                     # Generate coverage report
    $0 all --name=ai_service        # Run specific test
    $0 unit --watch                 # Watch mode

EOF
}

run_all_tests() {
    print_header "Running All Tests"
    cd "$PROJECT_ROOT"

    print_info "Executing test suite..."
    $DOCKER_COMPOSE exec flutter-dev flutter test "$@"

    if [ $? -eq 0 ]; then
        print_success "All tests passed!"
    else
        print_error "Some tests failed!"
        exit 1
    fi
}

run_unit_tests() {
    print_header "Running Unit Tests"
    cd "$PROJECT_ROOT"

    print_info "Executing unit tests..."
    $DOCKER_COMPOSE exec flutter-dev flutter test test/unit/ "$@"

    if [ $? -eq 0 ]; then
        print_success "Unit tests passed!"
    else
        print_error "Unit tests failed!"
        exit 1
    fi
}

run_widget_tests() {
    print_header "Running Widget Tests"
    cd "$PROJECT_ROOT"

    print_info "Executing widget tests..."
    $DOCKER_COMPOSE exec flutter-dev flutter test test/widget_test.dart "$@"

    if [ $? -eq 0 ]; then
        print_success "Widget tests passed!"
    else
        print_error "Widget tests failed!"
        exit 1
    fi
}

run_integration_tests() {
    print_header "Running Integration Tests"
    cd "$PROJECT_ROOT"

    print_info "Executing integration tests..."
    $DOCKER_COMPOSE exec flutter-dev flutter test test/integration/ "$@"

    if [ $? -eq 0 ]; then
        print_success "Integration tests passed!"
    else
        print_error "Integration tests failed!"
        exit 1
    fi
}

run_coverage() {
    print_header "Running Tests with Coverage"
    cd "$PROJECT_ROOT"

    print_info "Generating coverage report..."
    $DOCKER_COMPOSE exec flutter-dev flutter test --coverage "$@"

    if [ $? -eq 0 ]; then
        print_success "Coverage report generated!"
        print_info "Coverage data saved to coverage/lcov.info"

        # Check if lcov is available to generate HTML report
        if command -v lcov &> /dev/null && command -v genhtml &> /dev/null; then
            print_info "Generating HTML coverage report..."
            lcov --list coverage/lcov.info
            genhtml coverage/lcov.info -o coverage/html
            print_success "HTML coverage report generated in coverage/html/"
        fi
    else
        print_error "Test coverage generation failed!"
        exit 1
    fi
}

# Main logic
cd "$PROJECT_ROOT"

# Check if containers are running
if ! $DOCKER_COMPOSE ps | grep -q "flutter-dev.*Up"; then
    print_error "Development container is not running!"
    print_info "Start it with: ./scripts/docker-dev.sh start"
    exit 1
fi

# Parse command
TEST_TYPE="${1:-all}"
shift || true

case "$TEST_TYPE" in
    all)
        run_all_tests "$@"
        ;;
    unit)
        run_unit_tests "$@"
        ;;
    widget)
        run_widget_tests "$@"
        ;;
    integration)
        run_integration_tests "$@"
        ;;
    coverage)
        run_coverage "$@"
        ;;
    help|--help|-h)
        show_usage
        ;;
    *)
        print_error "Unknown test type: $TEST_TYPE"
        echo ""
        show_usage
        exit 1
        ;;
esac
