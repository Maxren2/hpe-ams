# hpe-amsd

Docker image for running HPE AMS on TrueNAS Scale.

Based on an Ubuntu 24.04 (LTS) container. The Dockerfile installs AMSD and other
HPE services through APT from https://downloads.linux.hpe.com/SDR.

The GitHub Action automatically builds a new container and pushes it to GHCR.

To use container, run the following command:

```
docker pull ghcr.io/endrebjorsvik/hpe-amsd:main
```

## systemd services in image

- ahslog.service
  - Name: Active Health Service Logger
  - Exec: /sbin/ahslog -f $OPTIONS
  - Env: /etc/sysconfig/ahslog (non-existing)

- amsd.service
  - Name: Agentless Management Service daemon
  - Exec: /sbin/amsd -f $OPTIONS
  - Env: /etc/sysconfig/amsd (non-existing)
  - Requires: smad.service

- amsd_rev.service:
  - Name: Agentless Management Service (Reverse Mode)
  - Exec: /sbin/amsd_rev -f $OPTIONS
  - Env: /etc/sysconfig/amsd_rev (non-existing)
  - After: snmpd.service

- cpqFca.service
  - Name: cpqFca MIB handler
  - Exec: /sbin/cpqFca -f $OPTIONS
  - Env: /etc/sysconfig/cpqFca (non-existing)
  - After: amsd.service

- cpqIde.service:
  - Name: cpqIde MIB handler
  - Exec: /sbin/cpqIde -f $OPTIONS
  - Env: /etc/sysconfig/cpqIde (non-existing)
  - Requires: amsd.service
  - ConditionPathExists: /sys/module/ahci
  - NOTE: We HAVE /sys/module/ahci

- cpqScsi.service:
  - Name: cpqScsi MIB handler
  - Exec: /sbin/cpqScsi -f $OPTIONS
  - Env: /etc/sysconfig/cpqScsi (non-existing)
  - Requires: amsd.service
  - ConditionPathExists: /dev/mpt2ctl
  - NOTE: We do not have /dev/mpt2ctl

- cpqiScsi.service:
  - Name: cpqiScsi MIB handler
  - Exec: /sbin/cpqiScsi -f $OPTIONS
  - Env: /etc/sysconfig/cpqiScsi (non-existing)
  - Requires: amsd.service

- mr_cpqScsi.service:
  - Name: cpqScsi MIB handler for Smart Aray 824i-p MR Gen10 Controller
  - Exec: /sbin/mr_cpqScsi -f $OPTIONS
  - Env: /etc/sysconfig/mr_cpqScsi (non-existing)
  - Requires: amsd.service
  - ConditionPathExists: /sys/module/megaraid_sas
  - Note: We do not have /sys/module/megaraid_sas

- smad.service:
  - Name: System Management Assistant daemon
  - Exec: /sbin/smad $OPTIONS
  - Env: /etc/sysconfig/smad (non-existing)

- smad_rev.service
  - Name: System Management Assistant Reverse Proxy Service
  - Exec: /sbin/smad_rev $OPTIONS
  - Env: /etc/sysconfig/smad_rev (non-existing)
  - After: snmpd.service

## Enabled services

`ls -l system/multi-user.target.wants/`

- ahslog.service -> /lib/systemd/system/ahslog.service
- smad.service -> /lib/systemd/system/smad.service
  - amsd.service -> /lib/systemd/system/amsd.service
    - cpqIde.service -> /lib/systemd/system/cpqIde.service
    - NO: cpqScsi.service -> /lib/systemd/system/cpqScsi.service
    - cpqiScsi.service -> /lib/systemd/system/cpqiScsi.service
    - NO: mr_cpqScsi.service -> /lib/systemd/system/mr_cpqScsi.service
