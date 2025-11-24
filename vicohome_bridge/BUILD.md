# Building Vicohome Bridge Add-on

## Building for AMD64 Architecture

### Option 1: Using Docker Buildx (Recommended)

Build for AMD64:

```bash
docker buildx build \
  --platform linux/amd64 \
  --build-arg TARGETARCH=amd64 \
  --build-arg HA_ARCH=amd64 \
  -t vicohome-bridge:amd64 \
  -f Dockerfile \
  .
```

### Option 2: Using the Build Script

If you're on Linux or macOS:

```bash
./build.sh amd64
```

Or let it auto-detect your architecture:

```bash
./build.sh
```

### Option 3: Using Home Assistant Supervisor

If you're installing this as a Home Assistant add-on, the Supervisor will automatically build for the correct architecture based on your system. Just ensure `config.yaml` includes both `amd64` and `aarch64` in the `arch` array (which it now does).

## Architecture Support

The add-on now supports:
- **amd64** (x86_64) - Intel/AMD 64-bit processors
- **aarch64** (ARM64) - ARM 64-bit processors (e.g., Raspberry Pi 4, Apple Silicon)

## Manual Build Notes

When building manually with Docker:
- For **AMD64**: Use `--build-arg HA_ARCH=amd64`
- For **ARM64/AArch64**: Use `--build-arg HA_ARCH=aarch64` (note: Docker uses "arm64" but Home Assistant uses "aarch64")

The `TARGETARCH` build argument should match Docker's architecture naming:
- `amd64` for x86_64
- `arm64` for ARM64

