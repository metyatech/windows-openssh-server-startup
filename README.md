# Windows OpenSSH Server Startup

## Overview
This repository provides a PowerShell script to validate and start the Windows OpenSSH Server service. It checks common failure points (installation, service configuration, host keys, firewall, port availability) and can optionally apply automatic remediation with confirmation. The script does not change the sshd startup type, so you can start it on demand each time.

## Setup
- Windows PowerShell 5.1+ or PowerShell 7+
- OpenSSH Server installed (the script can install it when `-AutoFix` is approved)

## Usage
Run the script from the repository root:

```powershell
.\Start-OpenSshServer.ps1
```

Stop the OpenSSH Server service on demand:

```powershell
.\Stop-OpenSshServer.ps1
```

Common options:

```powershell
# Show help
.\Start-OpenSshServer.ps1 -Help

# Run with automatic remediation (prompts per fix)
.\Start-OpenSshServer.ps1 -AutoFix

# Run with automatic remediation without prompts
.\Start-OpenSshServer.ps1 -AutoFix -Yes

# Preview changes without applying them
.\Start-OpenSshServer.ps1 -AutoFix -DryRun

# Use a custom port and firewall rule name
.\Start-OpenSshServer.ps1 -Port 2222 -FirewallRuleName 'OpenSSH-Server-In-TCP-2222'

# Machine-readable output
.\Start-OpenSshServer.ps1 -Json

# Force stop and verify sshd is no longer listening
.\Stop-OpenSshServer.ps1 -Force -Port 22
```

## Development commands

```powershell
# Lint
.\scripts\lint.ps1

# Tests (unit + E2E)
.\scripts\test.ps1

# Build (smoke checks)
.\scripts\build.ps1
```

### Git hooks
Set up the pre-commit hook so lint/test/build run before each commit:

```powershell
.\scripts\setup-hooks.ps1
```

## Environment variables
None.

## Release steps
- Update `CHANGELOG.md` with the new version and notes.
- Ensure lint, tests, and build pass.
- Tag the release (for example, `vX.Y.Z`) and push the tag.
- Create a GitHub Release with notes from the changelog.

## Error handling
The script emits explicit errors for:
- OpenSSH Server binaries or service missing
- Missing `sshd_config`
- Missing host keys
- Firewall module/service issues
- Firewall rule not permitting the SSH port
- Port conflicts
- Service start failures
- `sshd` not listening after startup
- Stop failures or lingering listeners when stopping `sshd`

When `-AutoFix` is enabled, the script asks for confirmation before applying a fix, and it retries the failed check after remediation.
