# Windows OpenSSH Server Startup

## Overview
This repository provides a PowerShell script to validate and start the Windows OpenSSH Server service. It checks common failure points (installation, service configuration, host keys, firewall, port availability) and can optionally apply automatic remediation with confirmation. The script does not change the sshd startup type, so you can start it on demand each time.

## Setup
- Windows PowerShell 5.1+ or PowerShell 7+
- OpenSSH Server installed (the script can install it when `-AutoFix` is approved)

## Installation (PowerShell Gallery)
Install the module from the PowerShell Gallery:

```powershell
Install-Module -Name WindowsOpenSshServerStartup -Repository PSGallery
```

Import the module and run the commands:

```powershell
Import-Module WindowsOpenSshServerStartup
Start-OpenSshServer
Stop-OpenSshServer
```

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

# Automatic remediation is enabled by default (prompts per fix)
.\Start-OpenSshServer.ps1

# Disable automatic remediation
.\Start-OpenSshServer.ps1 -NoAutoFix

# Run with automatic remediation without prompts
.\Start-OpenSshServer.ps1 -AutoFix -Yes

# Stop the OpenSSH Server with elevation prompts suppressed
.\Stop-OpenSshServer.ps1 -Yes

# Preview changes without applying them
.\Start-OpenSshServer.ps1 -AutoFix -DryRun

# Use a custom port and firewall rule name
.\Start-OpenSshServer.ps1 -Port 2222 -FirewallRuleName 'OpenSSH-Server-In-TCP-2222'

# Machine-readable output
.\Start-OpenSshServer.ps1 -Json

# Full result details
.\Start-OpenSshServer.ps1 -Verbose

# Force stop and verify sshd is no longer listening
.\Stop-OpenSshServer.ps1 -Force -Port 22
```

## Output
By default, the scripts return a concise summary (version, status, started/stopped, and a short message).
When no action is required (already running/stopped), the summary is suppressed.
When elevation is performed via `sudo` in the same terminal, the summary is suppressed because the elevated run prints its own output inline.
Use `-Verbose` or `-Trace` to output full diagnostic details, or `-Json` for machine-readable output.

## Development commands

```powershell
# Verify (Lint + Test)
.\scripts\verify.ps1

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
- Publish the module to the PowerShell Gallery (see below).
- Tag the release (for example, `vX.Y.Z`) and push the tag.
- Create a GitHub Release with notes from the changelog.

## Publish (PowerShell Gallery)
Set the PowerShell Gallery API key in `PSGALLERY_API_KEY` and run:

```powershell
.\scripts\publish.ps1
```

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

Automatic remediation is enabled by default. The script asks for confirmation before applying a fix, and it retries the failed check after remediation. Use `-NoAutoFix` to disable remediation.
When elevation is required, the script offers to relaunch as Administrator. The elevated window stays open after completion so you can review the output. Use `-Yes` to skip the relaunch prompt.
If the Windows `sudo` command is available, the script uses it for elevation (which can run inline when configured); otherwise it falls back to opening a new elevated window.
