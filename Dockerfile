# ------------------------------------------------------------
# HPE AMS container for Gen9 / iLO4
# ------------------------------------------------------------
FROM ubuntu:16.04

LABEL org.opencontainers.image.source="https://github.com/Maxren2/hpe-ams"
LABEL org.opencontainers.image.description="HPE Agentless Management (hp-ams) for Gen9 servers"
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
# 2. Import *all* HPE/HP repository keys into the trusted key-ring
#    (Xenial’s APT ignores per-repo keyrings)
# ──────────────────────────────────────────────────────────────
RUN for k in \
      hpPublicKey2048_key1.pub \
      hpPublicKey2048_key2.pub \
      hpePublicKey2048_key1.pub \
      hpePublicKey2048_key2.pub ; do \
        curl -fsSL https://downloads.linux.hpe.com/SDR/$k | apt-key add - ; \
    done

# ──────────────────────────────────────────────────────────────
# 3. Add the MCP Gen9 repository (classic deb format)
# ──────────────────────────────────────────────────────────────
RUN echo "deb https://downloads.linux.hpe.com/SDR/repo/mcp xenial/current-gen9 non-free" \
      > /etc/apt/sources.list.d/hpe-mcp.list

# ──────────────────────────────────────────────────────────────
# 4. Install Gen9 utilities + Python
# ──────────────────────────────────────────────────────────────
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        hp-ams hp-health hponcfg hp-snmp-agents \
        hpsmh hp-smh-templates \
        ssacli ssaducli ssa \
        python3 && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# ──────────────────────────────────────────────────────────────
# 5. systemctl replacement (for PID 1 inside the container)
# ──────────────────────────────────────────────────────────────
RUN curl -fsSL -o /tmp/systemctl.tar.gz \
      https://github.com/gdraheim/docker-systemctl-replacement/archive/refs/tags/v1.5.9063.tar.gz && \
    tar -xzf /tmp/systemctl.tar.gz -C /tmp && \
    cp /tmp/docker-systemctl-replacement-*/files/docker/* /usr/bin/ && \
    ln -s /usr/bin/systemctl3.py /usr/bin/systemctl && \
    chmod +x /usr/bin/systemctl3.py /usr/bin/journalctl3.py && \
    rm -rf /tmp/systemctl.tar.gz /tmp/docker-systemctl-replacement-*

# ──────────────────────────────────────────────────────────────
# 6. Service tweaks (Gen9 set — no amsd/Gen10 entries)
# ──────────────────────────────────────────────────────────────
RUN mkdir -p /etc/sysconfig && \
    for svc in hp-ams cpqFca cpqIde cpqScsi cpqiScsi smad_rev; do \
        echo "OPTIONS=-L" > /etc/sysconfig/$svc ; \
    done && \
    rm -f \
      /etc/systemd/system/multi-user.target.wants/ahslog.service \
      /etc/systemd/system/multi-user.target.wants/mr_cpqScsi.service

CMD ["/usr/bin/systemctl", "--init", "-vv"]
