# Helix iOS - Flutter Development Environment
# Multi-stage Dockerfile for development and building

# Stage 1: Base Flutter SDK
FROM ubuntu:24.04 AS flutter-base

# Avoid prompts from apt
ENV DEBIAN_FRONTEND=noninteractive

# Set environment variables
ENV FLUTTER_HOME=/opt/flutter
ENV FLUTTER_VERSION=3.35.0
ENV DART_SDK=${FLUTTER_HOME}/bin/cache/dart-sdk
ENV PATH=${FLUTTER_HOME}/bin:${DART_SDK}/bin:${PATH}

# Install system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    git \
    unzip \
    xz-utils \
    zip \
    libglu1-mesa \
    openjdk-11-jdk \
    wget \
    software-properties-common \
    clang \
    cmake \
    ninja-build \
    pkg-config \
    libgtk-3-dev \
    liblzma-dev \
    libstdc++-12-dev \
    # Audio processing dependencies
    libasound2-dev \
    pulseaudio \
    # Build tools
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Download and install Flutter SDK
RUN git clone --depth 1 --branch ${FLUTTER_VERSION} https://github.com/flutter/flutter.git ${FLUTTER_HOME}

# Pre-download Flutter artifacts
RUN flutter precache --linux --no-android --no-ios --no-web
RUN flutter doctor -v

# Stage 2: Development Environment
FROM flutter-base AS development

# Set working directory
WORKDIR /workspace

# Install additional development tools
RUN apt-get update && apt-get install -y \
    vim \
    nano \
    htop \
    bash-completion \
    jq \
    tree \
    # For VS Code server
    ca-certificates \
    wget \
    && rm -rf /var/lib/apt/lists/*

# Configure git to trust the workspace directory
RUN git config --global --add safe.directory /workspace

# Set up non-root user for development
ARG USERNAME=developer
ARG USER_UID=1000
ARG USER_GID=$USER_UID

RUN groupadd --gid $USER_GID $USERNAME \
    && useradd --uid $USER_UID --gid $USER_GID -m $USERNAME \
    && apt-get update \
    && apt-get install -y sudo \
    && echo $USERNAME ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/$USERNAME \
    && chmod 0440 /etc/sudoers.d/$USERNAME \
    && rm -rf /var/lib/apt/lists/*

# Switch to non-root user
USER $USERNAME

# Configure Flutter for the user
RUN flutter config --no-analytics
RUN flutter config --enable-linux-desktop

# Create workspace directory with proper permissions
RUN mkdir -p /home/$USERNAME/.pub-cache
ENV PUB_CACHE=/home/$USERNAME/.pub-cache

# Copy pub cache configuration
ENV FLUTTER_PUB_CACHE=/home/$USERNAME/.pub-cache

# Expose ports for debugging and hot reload
EXPOSE 9100
EXPOSE 9101
EXPOSE 9102

# Set up bash aliases for convenience
RUN echo 'alias fl="flutter"' >> /home/$USERNAME/.bashrc \
    && echo 'alias flr="flutter run"' >> /home/$USERNAME/.bashrc \
    && echo 'alias flt="flutter test"' >> /home/$USERNAME/.bashrc \
    && echo 'alias fla="flutter analyze"' >> /home/$USERNAME/.bashrc \
    && echo 'alias flc="flutter clean"' >> /home/$USERNAME/.bashrc \
    && echo 'alias flpg="flutter pub get"' >> /home/$USERNAME/.bashrc

# Default command
CMD ["/bin/bash"]

# Stage 3: Builder (for CI/CD)
FROM flutter-base AS builder

WORKDIR /app

# Copy pubspec files first for better caching
COPY pubspec.yaml pubspec.lock ./

# Get dependencies
RUN flutter pub get

# Copy the rest of the application
COPY . .

# Generate code
RUN flutter packages pub run build_runner build --delete-conflicting-outputs

# Run tests
RUN flutter test

# Build for Linux (default)
RUN flutter build linux --release

# Stage 4: Production (minimal runtime)
FROM ubuntu:24.04 AS production

# Install runtime dependencies only
RUN apt-get update && apt-get install -y \
    libgtk-3-0 \
    libglu1-mesa \
    libasound2 \
    && rm -rf /var/lib/apt/lists/*

# Copy built application
COPY --from=builder /app/build/linux/x64/release/bundle /app

WORKDIR /app

# Run the application
CMD ["./flutter_helix"]
