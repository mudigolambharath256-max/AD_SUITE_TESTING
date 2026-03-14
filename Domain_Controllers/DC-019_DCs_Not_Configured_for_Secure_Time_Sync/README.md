# DC-043: DCs Not Configured for Secure Time Sync

## Description

Identifies Domain Controllers that are not properly configured for secure time synchronization. Proper time sync is critical for Kerberos authentication, which requires time differences between clients and DCs to be within 5 minutes (default).

## Severity

**MEDIUM**

## Category

Domain Controllers

## What This Check Does

This check examines each Domain Controller for:
1. W32Time service status (must be running)
2. NTP configuration (should use secure time sources)
3. Time source type (PDC should use external NTP, others sync from domain hierarchy)
4. NTP server configuration on PDC emulator

## Risk

**Time Synchronization Issues**:
- Kerberos authentication failures (time skew > 5 minutes)
- Certificate validation failures
- Event log correlation problems
- Replication issues
- Application authentication failures

**Insecure Time Sources**:
- Time manipulation attacks
- Authentication bypass attempts
- Replay attack facilitation

## Remediation

### Configure PDC Emulator for External NTP

```powershell
# On PDC Emulator
w32tm /config /manualpeerlist:"time.windows.com,0x9" /syncfromflags:manual /reliable:YES /update
net stop w32time
net start w32time
w32tm /resync /rediscover
```

### Configure Other DCs for Domain Hierarchy

```powershell
# On non-PDC DCs
w32tm /config /syncfromflags:domhier /update
net stop w32time
net start w32time
w32tm /resync
```

### Verify Configuration

```powershell
# Check time source
w32tm /query /source

# Check configuration
w32tm /query /configuration

# Check status
w32tm /query /status
```

## Best Practices

1. **PDC Emulator**: Configure to sync with external, reliable NTP sources
2. **Other DCs**: Configure to sync from domain hierarchy
3. **NTP Sources**: Use multiple reliable sources (pool.ntp.org, time.windows.com)
4. **Monitoring**: Monitor time drift regularly
5. **Firewall**: Allow NTP (UDP 123) outbound from PDC

## References

- [Microsoft: How the Windows Time Service Works](https://learn.microsoft.com/en-us/windows-server/networking/windows-time-service/how-the-windows-time-service-works)
- [Configure Windows Time Service](https://learn.microsoft.com/en-us/windows-server/networking/windows-time-service/windows-time-service-tools-and-settings)

## MITRE ATT&CK

Not directly mapped, but time manipulation can facilitate various attack techniques.

## Output

Returns Domain Controllers with time sync issues:
- DC Name
- DNS Hostname
- W32Time Service Status
- Time Source Type
- NTP Server (if configured)
- Current Time Source
- Issue Description
