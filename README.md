# HAProxy QUIC RPM (with AWS-LC)

[![Build HAProxy QUIC RPM](https://github.com/derFrisson/haproxy-quic-awslc-rpm/actions/workflows/build.yml/badge.svg)](https://github.com/derFrisson/haproxy-quic-awslc-rpm/actions/workflows/build.yml)
[![Check Releases](https://github.com/derFrisson/haproxy-quic-awslc-rpm/actions/workflows/check-releases.yml/badge.svg)](https://github.com/derFrisson/haproxy-quic-awslc-rpm/actions/workflows/check-releases.yml)

Automated builds of HAProxy with native QUIC/HTTP3 support using **AWS-LC** instead of OpenSSL.

## Why AWS-LC?

Based on [HAProxy's comprehensive SSL stack analysis](https://www.haproxy.com/blog/state-of-ssl-stacks), AWS-LC provides significant performance advantages:

| Metric | AWS-LC | OpenSSL 1.1.1 | OpenSSL 3.x |
|--------|--------|---------------|-------------|
| TLS Resumption (64 threads) | 183,000 conn/s | 124,000 conn/s | 8,000-28,000 conn/s |
| Full Handshake (64 threads) | 63,000 conn/s | 48,000 conn/s | 21,000-42,500 conn/s |
| Multi-threaded Scaling | Linear | Degrades at 40+ threads | Collapses at 2-16 threads |
| QUIC Support | Native (BoringSSL API) | Requires QuicTLS patches | Incompatible API |

**Key Benefits:**
- **~50% faster** than OpenSSL 1.1.1 for TLS resumption
- **6-9x faster** than OpenSSL 3.x in multi-threaded scenarios
- **Linear scalability** across all CPU cores (no lock contention)
- **Native QUIC support** via BoringSSL-compatible API
- **FIPS-capable** (separate FIPS branches available from AWS)

## Quick Start

### Installation

```bash
# Download latest release (check releases page for current version)
curl -LO https://github.com/derFrisson/haproxy-quic-awslc-rpm/releases/latest/download/haproxy-quic-3.3.2-1.el9.x86_64.rpm

# Or browse all releases
# https://github.com/derFrisson/haproxy-quic-awslc-rpm/releases

# Install
sudo dnf localinstall -y haproxy-quic-*.rpm

# Verify QUIC support
haproxy -vv | grep -E "(QUIC|AWS-LC)"

# Enable and start
sudo systemctl enable --now haproxy
```

### Firewall Configuration (for QUIC/HTTP3)

```bash
# QUIC uses UDP port 443
sudo firewall-cmd --permanent --add-port=443/udp
sudo firewall-cmd --reload
```

## Features

- **Native QUIC/HTTP3** - Full protocol support without patches
- **AWS-LC crypto** - High-performance cryptographic library
- **C11 atomics** - Built with `CMAKE_C_STANDARD=11` for optimal performance
- **Prometheus metrics** - Built-in `/metrics` endpoint
- **Lua scripting** - Full Lua 5.4 support
- **PCRE2 regex** - Modern regex engine
- **systemd integration** - Native service management

## Example HAProxy Configuration (HTTP/3)

Create `/etc/haproxy/haproxy.cfg`:

```haproxy
global
    log stdout format raw local0
    maxconn 50000

defaults
    mode http
    log global
    timeout connect 5s
    timeout client 30s
    timeout server 30s

frontend https
    bind :443 ssl crt /etc/haproxy/certs/site.pem alpn h2,http/1.1
    bind quic4@:443 ssl crt /etc/haproxy/certs/site.pem alpn h3

    # Advertise HTTP/3 support
    http-response add-header alt-svc 'h3=":443"; ma=86400'

    default_backend servers

backend servers
    server web1 127.0.0.1:8080 check
```

## Automatic Updates

This repository automatically checks for new HAProxy and AWS-LC releases every Sunday and triggers a new build if updates are available.

| Component | Current | Check Source |
|-----------|---------|--------------|
| HAProxy | See [versions.json](versions.json) | [haproxy.org](https://www.haproxy.org/download/) (dynamic branch discovery) |
| AWS-LC | See [versions.json](versions.json) | [GitHub Releases](https://github.com/aws/aws-lc/releases) |

### Update Script

For existing installations, use the update script:

```bash
curl -LO https://raw.githubusercontent.com/derFrisson/haproxy-quic-awslc-rpm/main/scripts/update-haproxy.sh
chmod +x update-haproxy.sh
./update-haproxy.sh
```

## Manual Build Trigger

1. Go to **Actions** → **Build HAProxy QUIC RPM**
2. Click **Run workflow**
3. Enter desired HAProxy and AWS-LC versions
4. Click **Run workflow**

## Build Details

### Dependencies Built

- **AWS-LC** - Compiled with:
  - `CMAKE_C_STANDARD=11` (critical for atomic ops instead of locks)
  - `BUILD_SHARED_LIBS=ON`
  - `CMAKE_BUILD_TYPE=Release`
  - Installed to `/opt/haproxy-ssl`

- **HAProxy** - Compiled with:
  - `USE_QUIC=1` - QUIC protocol support
  - `USE_OPENSSL_AWSLC=1` - AWS-LC compatibility
  - `USE_PROMEX=1` - Prometheus exporter
  - `USE_LUA=1` - Lua scripting
  - `USE_PCRE2=1` - PCRE2 regex
  - `USE_SYSTEMD=1` - systemd integration

### Target Platform

- Rocky Linux 9 / RHEL 9 / AlmaLinux 9
- x86_64 architecture

## Performance Notes

This build uses AWS-LC compiled with `CMAKE_C_STANDARD=11`, which is critical for optimal performance. Without this flag, AWS-LC falls back to using pthread locks instead of atomic operations for reference counting, which can cause severe performance degradation under load.

See: [aws/aws-lc#1723](https://github.com/aws/aws-lc/issues/1723)

## References

- [HAProxy: The State of SSL Stacks](https://www.haproxy.com/blog/state-of-ssl-stacks) - Comprehensive analysis
- [AWS-LC GitHub](https://github.com/aws/aws-lc) - Cryptographic library
- [HAProxy SSL Libraries Support Status](https://github.com/haproxy/wiki/wiki/SSL-Libraries-Support-Status)
- [HAProxy QUIC Documentation](https://www.haproxy.com/documentation/haproxy-configuration-manual/latest/#9.4)

## License

- HAProxy: GPLv2+
- AWS-LC: Apache 2.0 + ISC
- This build configuration: MIT
