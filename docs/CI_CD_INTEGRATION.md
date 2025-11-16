# CI/CD Integration Guide

This guide explains how to integrate the linting and formatting tools into your CI/CD pipeline.

## Overview

The project includes a comprehensive validation script (`./scripts/validate.sh`) that runs all quality checks in a single command. This is designed specifically for CI/CD pipelines.

## GitHub Actions

### Basic Setup

Add this to your workflow file (e.g., `.github/workflows/ci.yml`):

```yaml
name: CI

on:
  pull_request:
    branches: [ main, develop ]
  push:
    branches: [ main, develop ]

jobs:
  quality:
    name: Code Quality Checks
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.35.0'
          channel: 'stable'
          cache: true

      - name: Install dependencies
        run: flutter pub get

      - name: Run validation suite
        run: ./scripts/validate.sh
```

### Individual Checks

For more granular control, run checks separately:

```yaml
jobs:
  format:
    name: Check Formatting
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.35.0'
      - run: flutter pub get
      - name: Check formatting
        run: ./scripts/format.sh --check

  lint:
    name: Static Analysis
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.35.0'
      - run: flutter pub get
      - name: Run analyzer
        run: ./scripts/lint.sh --strict

  test:
    name: Run Tests
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.35.0'
      - run: flutter pub get
      - name: Run tests
        run: flutter test --coverage
      - name: Upload coverage
        uses: codecov/codecov-action@v3
        with:
          files: ./coverage/lcov.info
```

### Complete Example

```yaml
name: Comprehensive CI

on:
  pull_request:
  push:
    branches: [ main ]

jobs:
  quality-checks:
    name: Quality Checks
    runs-on: ubuntu-latest
    timeout-minutes: 15

    steps:
      - name: Checkout code
        uses: actions/checkout@v4
        with:
          fetch-depth: 0  # Full history for better analysis

      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.35.0'
          channel: 'stable'
          cache: true

      - name: Cache pub dependencies
        uses: actions/cache@v3
        with:
          path: |
            ~/.pub-cache
            .dart_tool
          key: ${{ runner.os }}-pub-${{ hashFiles('**/pubspec.lock') }}
          restore-keys: |
            ${{ runner.os }}-pub-

      - name: Install dependencies
        run: flutter pub get

      - name: Verify dependencies
        run: flutter pub outdated --exit-if-newer || true

      - name: Check formatting
        run: ./scripts/format.sh --check

      - name: Run analyzer (strict mode)
        run: ./scripts/lint.sh --strict

      - name: Run tests with coverage
        run: flutter test --coverage

      - name: Upload coverage to Codecov
        uses: codecov/codecov-action@v3
        with:
          files: ./coverage/lcov.info
          fail_ci_if_error: true

      - name: Check for TODOs
        run: |
          if grep -r "TODO\|FIXME" lib/ --include="*.dart"; then
            echo "::warning::Found TODO/FIXME comments"
          fi
        continue-on-error: true

  build:
    name: Build
    runs-on: ubuntu-latest
    needs: quality-checks
    strategy:
      matrix:
        platform: [android, ios, web]

    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.35.0'
      - run: flutter pub get
      - name: Build ${{ matrix.platform }}
        run: |
          case ${{ matrix.platform }} in
            android)
              flutter build apk --debug
              ;;
            ios)
              flutter build ios --debug --no-codesign
              ;;
            web)
              flutter build web
              ;;
          esac
```

## GitLab CI

### Basic Setup

`.gitlab-ci.yml`:

```yaml
image: ghcr.io/cirruslabs/flutter:3.35.0

stages:
  - quality
  - test
  - build

before_script:
  - flutter pub get

quality:formatting:
  stage: quality
  script:
    - ./scripts/format.sh --check
  only:
    - merge_requests
    - main

quality:linting:
  stage: quality
  script:
    - ./scripts/lint.sh --strict
  only:
    - merge_requests
    - main

test:unit:
  stage: test
  script:
    - flutter test --coverage
  coverage: '/lines.*: \d+\.\d+\%/'
  artifacts:
    reports:
      coverage_report:
        coverage_format: cobertura
        path: coverage/cobertura.xml
  only:
    - merge_requests
    - main

build:all:
  stage: build
  script:
    - flutter build apk --debug
    - flutter build web
  artifacts:
    paths:
      - build/app/outputs/flutter-apk/
      - build/web/
  only:
    - main
```

### Complete Example

```yaml
image: ghcr.io/cirruslabs/flutter:3.35.0

variables:
  FLUTTER_VERSION: "3.35.0"
  PUB_CACHE: ${CI_PROJECT_DIR}/.pub-cache

cache:
  key: ${CI_COMMIT_REF_SLUG}
  paths:
    - .pub-cache/
    - .dart_tool/

stages:
  - prepare
  - quality
  - test
  - build
  - deploy

prepare:dependencies:
  stage: prepare
  script:
    - flutter pub get
    - flutter pub outdated || true
  artifacts:
    paths:
      - .dart_tool/
      - .pub-cache/
    expire_in: 1 hour

quality:validation:
  stage: quality
  dependencies:
    - prepare:dependencies
  script:
    - ./scripts/validate.sh
  only:
    - merge_requests
    - main
    - develop

test:unit:
  stage: test
  dependencies:
    - prepare:dependencies
  script:
    - flutter test --coverage --reporter=json > test-results.json
  coverage: '/lines.*: \d+\.\d+\%/'
  artifacts:
    reports:
      junit: test-results.json
      coverage_report:
        coverage_format: cobertura
        path: coverage/cobertura.xml
    paths:
      - coverage/
  only:
    - merge_requests
    - main

build:android:
  stage: build
  dependencies:
    - prepare:dependencies
  script:
    - flutter build apk --release
  artifacts:
    paths:
      - build/app/outputs/flutter-apk/app-release.apk
  only:
    - main
    - tags

build:ios:
  stage: build
  dependencies:
    - prepare:dependencies
  script:
    - flutter build ios --release --no-codesign
  artifacts:
    paths:
      - build/ios/iphoneos/
  only:
    - main
    - tags
```

## Azure Pipelines

### Basic Setup

`azure-pipelines.yml`:

```yaml
trigger:
  - main
  - develop

pr:
  - main
  - develop

pool:
  vmImage: 'ubuntu-latest'

variables:
  FLUTTER_VERSION: '3.35.0'

steps:
  - task: FlutterInstall@0
    inputs:
      channel: 'stable'
      version: $(FLUTTER_VERSION)

  - script: flutter pub get
    displayName: 'Install dependencies'

  - script: ./scripts/validate.sh
    displayName: 'Run validation suite'

  - script: flutter test --coverage
    displayName: 'Run tests with coverage'

  - task: PublishCodeCoverageResults@1
    inputs:
      codeCoverageTool: 'cobertura'
      summaryFileLocation: '$(System.DefaultWorkingDirectory)/coverage/cobertura.xml'
```

## Jenkins

### Jenkinsfile

```groovy
pipeline {
    agent {
        docker {
            image 'ghcr.io/cirruslabs/flutter:3.35.0'
            args '-v /var/run/docker.sock:/var/run/docker.sock'
        }
    }

    environment {
        FLUTTER_HOME = '/sdks/flutter'
        PATH = "$FLUTTER_HOME/bin:$PATH"
    }

    stages {
        stage('Prepare') {
            steps {
                sh 'flutter pub get'
            }
        }

        stage('Quality Checks') {
            parallel {
                stage('Format') {
                    steps {
                        sh './scripts/format.sh --check'
                    }
                }
                stage('Lint') {
                    steps {
                        sh './scripts/lint.sh --strict'
                    }
                }
            }
        }

        stage('Test') {
            steps {
                sh 'flutter test --coverage'
            }
            post {
                always {
                    publishHTML([
                        reportDir: 'coverage',
                        reportFiles: 'index.html',
                        reportName: 'Coverage Report'
                    ])
                }
            }
        }

        stage('Build') {
            when {
                branch 'main'
            }
            steps {
                sh 'flutter build apk --release'
            }
            post {
                success {
                    archiveArtifacts artifacts: 'build/app/outputs/flutter-apk/*.apk'
                }
            }
        }
    }

    post {
        always {
            cleanWs()
        }
        failure {
            emailext(
                subject: "Build Failed: ${env.JOB_NAME} - ${env.BUILD_NUMBER}",
                body: "Check console output at ${env.BUILD_URL}",
                to: 'team@example.com'
            )
        }
    }
}
```

## CircleCI

### .circleci/config.yml

```yaml
version: 2.1

orbs:
  flutter: circleci/flutter@2.0.0

jobs:
  quality:
    executor:
      name: flutter/default
      flutter-version: "3.35.0"
    steps:
      - checkout
      - flutter/install_sdk_and_pub
      - run:
          name: Run validation suite
          command: ./scripts/validate.sh

  test:
    executor:
      name: flutter/default
      flutter-version: "3.35.0"
    steps:
      - checkout
      - flutter/install_sdk_and_pub
      - run:
          name: Run tests
          command: flutter test --coverage
      - store_test_results:
          path: test-results
      - store_artifacts:
          path: coverage

workflows:
  build_and_test:
    jobs:
      - quality
      - test:
          requires:
            - quality
```

## Docker Integration

### Dockerfile for CI

```dockerfile
FROM ghcr.io/cirruslabs/flutter:3.35.0

WORKDIR /app

# Copy dependency files
COPY pubspec.yaml pubspec.lock ./

# Install dependencies
RUN flutter pub get

# Copy project files
COPY . .

# Run validation
RUN ./scripts/validate.sh

# Build
RUN flutter build web
```

### Docker Compose for CI

```yaml
version: '3.8'

services:
  ci:
    build: .
    volumes:
      - .:/app
      - pub-cache:/root/.pub-cache
    command: ./scripts/validate.sh

volumes:
  pub-cache:
```

## Pre-commit Hooks in CI

Install and run pre-commit hooks:

```yaml
- name: Install pre-commit
  run: pip install pre-commit

- name: Run pre-commit hooks
  run: pre-commit run --all-files
```

## Quality Gates

### Example Quality Gates

```yaml
quality-gates:
  rules:
    - name: "Code Coverage"
      threshold: 80%
      metric: line-coverage

    - name: "No Linting Errors"
      threshold: 0
      metric: linting-errors

    - name: "No Formatting Issues"
      threshold: 0
      metric: formatting-issues

    - name: "All Tests Pass"
      threshold: 100%
      metric: test-pass-rate
```

## Branch Protection Rules

### GitHub

Recommended branch protection rules for `main`:

- Require pull request reviews (1+ approvers)
- Require status checks to pass:
  - Code formatting check
  - Static analysis
  - All tests pass
- Require branches to be up to date
- Require signed commits (optional)
- Include administrators (optional)

### GitLab

```yaml
# .gitlab-ci.yml
workflow:
  rules:
    - if: $CI_MERGE_REQUEST_IID
    - if: $CI_COMMIT_BRANCH == "main"

# Protected branches settings (in GitLab UI):
# - main:
#   - Allowed to merge: Developers + Maintainers
#   - Allowed to push: No one
#   - Require approval: 1+
#   - Pipelines must succeed
```

## Notifications

### Slack Integration (GitHub Actions)

```yaml
- name: Notify Slack on failure
  if: failure()
  uses: slackapi/slack-github-action@v1.24.0
  with:
    payload: |
      {
        "text": "CI Failed: ${{ github.repository }}",
        "blocks": [
          {
            "type": "section",
            "text": {
              "type": "mrkdwn",
              "text": "❌ CI Pipeline Failed\n*Repository:* ${{ github.repository }}\n*Branch:* ${{ github.ref }}\n*Commit:* ${{ github.sha }}"
            }
          }
        ]
      }
  env:
    SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK }}
```

## Best Practices

1. **Cache dependencies** to speed up builds
2. **Run checks in parallel** when possible
3. **Fail fast** - run quick checks first
4. **Use matrix builds** for multi-platform testing
5. **Set appropriate timeouts** to prevent hanging jobs
6. **Archive artifacts** for debugging
7. **Generate coverage reports** for visibility
8. **Use quality gates** to enforce standards
9. **Send notifications** on failures
10. **Keep CI config DRY** - use templates/includes

## Troubleshooting

### CI fails but local passes

1. Ensure same Flutter version
2. Clear pub cache: `flutter pub cache repair`
3. Check for platform-specific issues
4. Verify environment variables

### Slow CI builds

1. Enable caching for `.pub-cache` and `.dart_tool`
2. Use matrix builds for parallel execution
3. Consider using a faster runner
4. Optimize test suite

### Flaky tests

1. Add retries for flaky tests
2. Use `testWidgets` with appropriate `pumpAndSettle`
3. Mock external dependencies
4. Increase timeouts for async operations

## Resources

- [GitHub Actions - Flutter](https://github.com/marketplace/actions/flutter-action)
- [GitLab CI - Flutter](https://docs.gitlab.com/ee/ci/examples/flutter.html)
- [Azure Pipelines - Flutter](https://marketplace.visualstudio.com/items?itemName=aloisdeniel.flutter)
- [CircleCI - Flutter Orb](https://circleci.com/developer/orbs/orb/circleci/flutter)
