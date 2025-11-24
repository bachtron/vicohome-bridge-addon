# syntax=docker/dockerfile:1

# Builder stage: compile vico-cli for Linux
ARG BUILDPLATFORM
ARG TARGETPLATFORM
ARG TARGETARCH

FROM --platform=${BUILDPLATFORM} golang:1.23-alpine AS builder

WORKDIR /src

# Copy go module files and download deps
COPY vico-cli-main/go.mod vico-cli-main/go.sum ./
RUN go mod download

# Copy the rest of the source
COPY vico-cli-main/ ./

# Build the vico-cli binary for target architecture
ARG TARGETARCH
RUN CGO_ENABLED=0 GOOS=linux GOARCH=${TARGETARCH} go build -o /out/vico-cli main.go

# -------------------------------------------------------------------
# Runtime image: Home Assistant base image (multi-architecture)
# -------------------------------------------------------------------
ARG TARGETPLATFORM
ARG TARGETARCH

# HA_ARCH: Home Assistant architecture name (REQUIRED for Supervisor builds)
# Docker uses "arm64" but Home Assistant uses "aarch64"
# 
# The Home Assistant Supervisor should automatically pass this: --build-arg HA_ARCH=aarch64 (for ARM64) or --build-arg HA_ARCH=amd64
# 
# IMPORTANT: If you see build errors about "ghcr.io/home-assistant/-base:3.19", it means Supervisor
# is not passing HA_ARCH. The Supervisor should automatically determine your system architecture
# and pass the correct value. If it doesn't, this may be a Supervisor bug or configuration issue.
#
# Default is set to amd64 as a fallback, but Supervisor should override this.
ARG HA_ARCH=amd64

# Select the appropriate base image
FROM --platform=${TARGETPLATFORM} \
  ghcr.io/home-assistant/${HA_ARCH}-base:3.19

# Install MQTT client and jq for JSON handling
RUN apk add --no-cache mosquitto-clients jq

# Run as root for simplicity
USER root

WORKDIR /app

# Copy compiled binary from builder
COPY --from=builder /out/vico-cli /usr/local/bin/vico-cli

# Copy run script
COPY run.sh /run.sh
RUN chmod a+x /run.sh

CMD ["/run.sh"]
