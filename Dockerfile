# ------------------------------------------------------------------
#  HPE Agentless Management (hp-ams) + SNMP + SMH for Gen9 / iLO4
# ------------------------------------------------------------------
FROM ubuntu:16.04

LABEL org.opencontainers.image.source="https://github.com/Maxren2/hpe-ams"
LABEL org.opencontainers.image.description="HPE AMS container with SNMP agents and System Management Homepage for Gen9 servers"
LABEL org.opencontainers.image.licenses="MIT"

# ──────────────────────────────────────────────────────────────
# 1. Base utilities + HTTPS transport (needed on Ubuntu 16.04)
# ──────────────────────────────────────────────────────────────
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        curl gnupg apt-utils iproute2 \
        apt-transport-https ca-certificates && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# ──────────────────────────────────────────────────────────────
# 2. Import ALL HPE/HP repository keys into the global key-ring
#    (16.04 APT ignores per-repo Signed-By keyrings)
# ──────────────────────────────────────────────────────────────
RUN for key in \
        hpPublicKey2048_key1.pub \
        hpPublicKey2048_key2.pub \
        hpePublicKey2048_key1.pub \
        hpePublicKey2048_key2.pub ; do \
        curl -fsSL https://downloads.linux.hpe.com/SDR/${key} | apt-key add - ; \
    done

# ──────────────────────────────────────────────────────────────
# 3. Add HPE MCP Gen9 repository (classic deb line)
# ──────────────────────────────────────────────────────────────
RUN echo "deb https://downloads.linux.hpe.com/SDR/repo/mcp xenial/current-gen9 non-free" \
        > /etc/apt/sources.list.d/hpe-mcp.list

# ──────────────────────────────────────────────────────────────
# 4. Install HPE utilities *and* runtime prerequisites
# ──────────────────────────────────────────────────────────────
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        # HPE packages
        hp-ams hp-health hponcfg hp-snmp-agents hpsmh hp-smh-templates \
        ssacli ssaducli ssa \
        # runtime helpers expected by the init-scripts
        kmod procps psmisc apache2-bin snmpd \
        # python3 for convenience / scripting
        python3 && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# ──────────────────────────────────────────────────────────────
# 5. Lightweight “systemctl” replacement (PID 1 shim)
# ──────────────────────────────────────────────────────────────
RUN curl -fsSL -o /tmp/systemctl.tgz \
        https://github.com/gdraheim/docker-systemctl-replacement/archive/refs/tags/v1.5.9063.tar.gz && \
    tar -xzf /tmp/systemctl.tgz -C /tmp && \
    cp /tmp/docker-systemctl-replacement-*/files/docker/* /usr/bin/ && \
    ln -s /usr/bin/systemctl3.py /usr/bin/systemctl && \
    chmod +x /usr/bin/systemctl3.py /usr/bin/journalctl3.py && \
    rm -rf /tmp/systemctl.tgz /tmp/docker-systemctl-replacement-*

# ──────────────────────────────────────────────────────────────
# 6. Service tweaks
#    • Force daemons to log to STDOUT (OPTIONS=-L)
#    • Disable two verbose helper services
# ──────────────────────────────────────────────────────────────
RUN mkdir -p /etc/sysconfig && \
    for svc in hp-ams cpqFca cpqIde cpqScsi cpqiScsi smad_rev ; do \
        echo "OPTIONS=-L" > /etc/sysconfig/$svc ; \
    done && \
    rm -f \
        /etc/systemd/system/multi-user.target.wants/ahslog.service \
        /etc/systemd/system/multi-user.target.wants/mr_cpqScsi.service

# ------------------------------------------------------------------
CMD ["/usr/bin/systemctl", "--init", "-vv"]
