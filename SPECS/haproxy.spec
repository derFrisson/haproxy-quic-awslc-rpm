%{!?haproxy_version: %global haproxy_version 3.3.1}
%{!?awslc_version: %global awslc_version 1.66.0}
%{!?build_date: %global build_date %(date "+%a %b %d %Y")}

Name:           haproxy-quic
Version:        %{haproxy_version}
Release:        1.awslc%{awslc_version}%{?dist}
Summary:        HAProxy with native QUIC/HTTP3 support (AWS-LC %{awslc_version})

License:        GPLv2+ and ISC
URL:            https://www.haproxy.org/
Vendor:         Custom Build

# Disable automatic dependency detection for bundled AWS-LC libraries only
# This prevents RPM from requiring system OpenSSL while still detecting other deps
AutoReq:        no
AutoProv:       no

# Explicit runtime dependencies
Requires:       systemd
Requires:       lua-libs
Requires:       pcre2
Requires:       zlib
Requires:       glibc

Provides:       haproxy = %{haproxy_version}
Conflicts:      haproxy

%description
HAProxy %{haproxy_version} compiled with AWS-LC %{awslc_version} for native
QUIC/HTTP3 support. This package includes a bundled AWS-LC installation at
/opt/haproxy-ssl to avoid conflicts with system OpenSSL.

AWS-LC provides significantly better performance than OpenSSL 3.x:
- ~50%% faster than OpenSSL 1.1.1 for TLS resumption
- 6-9x faster than OpenSSL 3.x in multi-threaded scenarios
- Linear scalability across all CPU cores (no lock contention)
- Optimized for maximum multi-threaded performance

Features:
- Native QUIC/HTTP3 support
- Prometheus metrics exporter
- Lua scripting support
- PCRE2 regex support
- zlib compression
- systemd integration

%prep
# Nothing to do - using pre-built binaries

%build
# Nothing to do - already built externally

%install
# Copy pre-built files from staging directory to buildroot
cp -a /tmp/haproxy-staging/* %{buildroot}/

%pre
# Create haproxy user/group if they don't exist
getent group haproxy >/dev/null || groupadd -r haproxy
getent passwd haproxy >/dev/null || \
    useradd -r -g haproxy -d /var/lib/haproxy -s /sbin/nologin \
    -c "HAProxy Load Balancer" haproxy
exit 0

%post
%systemd_post haproxy.service

# Update library cache for bundled AWS-LC
if [ -d /opt/haproxy-ssl/lib64 ]; then
    echo "/opt/haproxy-ssl/lib64" > /etc/ld.so.conf.d/haproxy-awslc.conf
elif [ -d /opt/haproxy-ssl/lib ]; then
    echo "/opt/haproxy-ssl/lib" > /etc/ld.so.conf.d/haproxy-awslc.conf
fi
ldconfig

echo ""
echo "============================================"
echo " HAProxy %{haproxy_version} with QUIC installed!"
echo " (using AWS-LC %{awslc_version})"
echo "============================================"
echo ""
echo "Verify QUIC support:"
echo "  haproxy -vv | grep QUIC"
echo ""
echo "Don't forget to open UDP 443 for QUIC:"
echo "  firewall-cmd --permanent --add-port=443/udp"
echo "  firewall-cmd --reload"
echo ""
echo "Create your configuration at:"
echo "  /etc/haproxy/haproxy.cfg"
echo ""

%preun
%systemd_preun haproxy.service

%postun
%systemd_postun_with_restart haproxy.service

# Remove library cache entry on uninstall
if [ $1 -eq 0 ]; then
    rm -f /etc/ld.so.conf.d/haproxy-awslc.conf
    ldconfig
fi

%files
# Bundled AWS-LC
/opt/haproxy-ssl

# HAProxy binaries
%{_sbindir}/haproxy
%{_sbindir}/haproxy-dump-certs
%{_sbindir}/haproxy-reload

# Documentation
%doc /usr/doc/haproxy

# Man pages
%{_mandir}/man1/haproxy.1*

# Systemd service
%{_unitdir}/haproxy.service

# Configuration directories
%dir %{_sysconfdir}/haproxy
%dir %{_sysconfdir}/haproxy/conf.d

# State directory
%dir %attr(750,haproxy,haproxy) %{_localstatedir}/lib/haproxy

%changelog
* %{build_date} Automated Build <noreply@github.com> - %{haproxy_version}-1
- HAProxy %{haproxy_version} with AWS-LC %{awslc_version}
- Native QUIC/HTTP3 support
- Optimized for maximum multi-threaded performance
- Prometheus exporter enabled
- Lua scripting enabled
