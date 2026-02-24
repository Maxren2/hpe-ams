FROM ubuntu:16.04

LABEL org.opencontainers.image.source="https://github.com/Maxren2/hpe-ams"
LABEL org.opencontainers.image.description="Small container for running HPE AMS software in a privileged container on TrueNAS Scale."
LABEL org.opencontainers.image.licenses="MIT"

# ──────────────────────────────────────────────────────────────
# 1. Base utilities + HTTPS transport for APT (required on 16.04)
# ──────────────────────────────────────────────────────────────
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        curl gnupg apt-utils iproute2 \
        apt-transport-https ca-certificates && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# ──────────────────────────────────────────────────────────────
# 2. Import HPE repo signing key
# ──────────────────────────────────────────────────────────────
RUN install -d -m0755 /etc/apt/keyrings && \
    curl -fsSL https://downloads.linux.hpe.com/SDR/hpePublicKey2048_key2.pub \
      | gpg --dearmor -o /etc/apt/keyrings/hpePublicKey2048_key2.gpg && \
    chmod 644 /etc/apt/keyrings/*

# Optional: show the key (handy for debugging)
RUN apt-key list --keyring /etc/apt/keyrings/hpePublicKey2048_key2.gpg

# ──────────────────────────────────────────────────────────────
# 3. Add HPE MCP repository (deb822 format)
# ──────────────────────────────────────────────────────────────
ADD mcp.sources /etc/apt/sources.list.d/

# ──────────────────────────────────────────────────────────────
# 4. Install HPE utilities + Python
# ──────────────────────────────────────────────────────────────
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        hp-ams hp-health hponcfg hp-snmp-agents hpsmh hp-smh-templates \
        ssacli ssaducli ssa storcli \
        python3 && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# ──────────────────────────────────────────────────────────────
# 5. Systemd-replacement for containers
# ──────────────────────────────────────────────────────────────
RUN curl -fsSL -o /tmp/systemctl.tar.gz \
      https://github.com/gdraheim/docker-systemctl-replacement/archive/refs/tags/v1.5.9063.tar.gz && \
    tar -xzf /tmp/systemctl.tar.gz -C /tmp && \
    cp /tmp/docker-systemctl-replacement-*/files/docker/* /usr/bin/ && \
    ln -s /usr/bin/systemctl3.py /usr/bin/systemctl && \
    chmod +x /usr/bin/systemctl3.py /usr/bin/journalctl3.py && \
    rm -rf /tmp/systemctl.tar.gz /tmp/docker-systemctl-replacement-*

# ──────────────────────────────────────────────────────────────
# 6. Service tweaks
# ──────────────────────────────────────────────────────────────
RUN mkdir -p /etc/sysconfig && \
    for f in amsd amsd_rev cpqFca cpqIde cpqScsi cpqiScsi smad_rev; do \
        echo "OPTIONS=-L" > /etc/sysconfig/$f ; \
    done && \
    rm -f /etc/systemd/system/multi-user.target.wants/ahslog.service \
          /etc/systemd/system/multi-user.target.wants/mr_cpqScsi.service

CMD ["/usr/bin/systemctl", "--init", "-vv"]
