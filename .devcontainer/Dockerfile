# Helix Development Container
# Optimized for VS Code Remote - Containers

FROM ubuntu:22.04

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
    # Development tools
    vim \
    nano \
    htop \
    bash-completion \
    jq \
    tree \
    ca-certificates \
    openssh-client \
    less \
    procps \
    gnupg2 \
    lsb-release \
    sudo \
    && rm -rf /var/lib/apt/lists/*

# Download and install Flutter SDK
RUN git clone --depth 1 --branch ${FLUTTER_VERSION} https://github.com/flutter/flutter.git ${FLUTTER_HOME} \
    && flutter precache --linux --no-android --no-ios --no-web \
    && flutter config --no-analytics \
    && flutter config --enable-linux-desktop \
    && flutter doctor -v

# Create non-root user
ARG USERNAME=developer
ARG USER_UID=1000
ARG USER_GID=$USER_UID

RUN groupadd --gid $USER_GID $USERNAME \
    && useradd --uid $USER_UID --gid $USER_GID -m -s /bin/bash $USERNAME \
    && echo $USERNAME ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/$USERNAME \
    && chmod 0440 /etc/sudoers.d/$USERNAME

# Switch to non-root user
USER $USERNAME

# Set up user environment
RUN mkdir -p /home/$USERNAME/.pub-cache \
    && mkdir -p /home/$USERNAME/.flutter \
    && mkdir -p /home/$USERNAME/.vscode-server

# Configure Flutter for the user
ENV PUB_CACHE=/home/$USERNAME/.pub-cache
ENV FLUTTER_PUB_CACHE=/home/$USERNAME/.pub-cache

# Set up bash aliases and environment
RUN echo 'export PATH="/opt/flutter/bin:/opt/flutter/bin/cache/dart-sdk/bin:$PATH"' >> /home/$USERNAME/.bashrc \
    && echo 'alias fl="flutter"' >> /home/$USERNAME/.bashrc \
    && echo 'alias flr="flutter run"' >> /home/$USERNAME/.bashrc \
    && echo 'alias flt="flutter test"' >> /home/$USERNAME/.bashrc \
    && echo 'alias fla="flutter analyze"' >> /home/$USERNAME/.bashrc \
    && echo 'alias flc="flutter clean"' >> /home/$USERNAME/.bashrc \
    && echo 'alias flpg="flutter pub get"' >> /home/$USERNAME/.bashrc \
    && echo 'alias flbr="flutter packages pub run build_runner build --delete-conflicting-outputs"' >> /home/$USERNAME/.bashrc

# Set working directory
WORKDIR /workspace

# Default command
CMD ["/bin/bash"]
