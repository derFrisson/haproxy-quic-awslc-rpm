# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This repository builds HAProxy RPM packages with native QUIC/HTTP3 support using AWS-LC instead of OpenSSL. AWS-LC provides significantly better multi-threaded performance (6-9x faster than OpenSSL 3.x) and native QUIC support via its BoringSSL-compatible API.

## Repository Structure

```
├── .github/workflows/
│   ├── build.yml           # Main build workflow (Rocky Linux 10 container)
│   └── check-releases.yml  # Weekly check for new HAProxy/AWS-LC releases
├── SOURCES/
│   └── haproxy.service     # systemd unit file included in RPM
├── SPECS/
│   └── haproxy.spec        # RPM spec file (binary packaging)
├── scripts/
│   └── update-haproxy.sh   # Client-side update script
└── versions.json           # Tracks current HAProxy and AWS-LC versions
```

## Build Architecture

The build workflow (`build.yml`) performs these steps in a Rocky Linux 10 container:

1. **Download and verify sources** - Downloads with retry logic, verifies SHA256 checksums when available
2. **Build AWS-LC** with `CMAKE_C_STANDARD=11` (critical for atomic ops - see aws/aws-lc#1723)
3. **Build HAProxy** against AWS-LC with QUIC, Prometheus exporter, Lua, PCRE2, and systemd support
4. **Verify build** - Fails if QUIC or Prometheus support is missing
5. **Package RPM** with AWS-LC bundled at `/opt/haproxy-ssl`
6. **Create GitHub Release** and update `versions.json`

## Key Build Flags

**AWS-LC** (installed to `/opt/haproxy-ssl`):
- `CMAKE_C_STANDARD=11` - Enables atomic operations instead of pthread locks
- `BUILD_SHARED_LIBS=ON`

**HAProxy**:
- `USE_QUIC=1` + `USE_OPENSSL_AWSLC=1` - QUIC with AWS-LC
- `USE_PROMEX=1` - Prometheus metrics at `/metrics`
- `USE_LUA=1`, `USE_PCRE2=1`, `USE_SYSTEMD=1`
- `LDFLAGS="-Wl,-rpath,/opt/haproxy-ssl/lib64"` - Runtime library path

## Triggering Builds

- **Manual**: Actions → Build HAProxy QUIC RPM → Run workflow (versions required, no defaults)
- **Automatic**: `check-releases.yml` runs every Sunday, dynamically discovers HAProxy branches

## Version Management

`versions.json` tracks the currently built versions and includes `last_updated` timestamp. The `check-releases.yml` workflow:
- **HAProxy**: Dynamically discovers branches from `haproxy.org/download/`, finds latest stable
- **AWS-LC**: Uses authenticated GitHub API to check latest release

## Security Features

- All GitHub Actions pinned to full SHA (not version tags)
- Source downloads verified with SHA256 checksums when available
- Explicit secret passing (no `secrets: inherit`)
- Build fails if QUIC support is not present in final binary

## Target Platform

Rocky Linux 10 / RHEL 10 / AlmaLinux 10 (x86_64)
