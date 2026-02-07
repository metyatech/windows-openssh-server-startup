# Changelog

## 0.4.0 - 2026-02-07
- Refactor private functions into a shared module to eliminate duplication.
- Improve Confirm-AutoFix testability and fix failing unit tests in non-interactive environments.

## 0.3.7 - 2026-01-30
- Suppress summary output when no action is needed.

## 0.3.6 - 2026-01-30
- Suppress summary output when sudo runs in the same terminal.

## 0.3.5 - 2026-01-30
- Default output now shows a concise summary; use -Verbose or -Trace for full details.

## 0.3.4 - 2026-01-30
- Clarify pending elevation results in warnings.

## 0.3.3 - 2026-01-30
- Use encoded PowerShell command for elevation to handle module paths.

## 0.3.2 - 2026-01-30
- Report pending status after elevation requests and improve sudo diagnostics.

## 0.3.1 - 2026-01-30
- Include module private scripts in the published package.

## 0.3.0 - 2026-01-30
- Publish as a single PowerShell module (Start/Stop together).

## 0.2.3 - 2026-01-30
- Add required script descriptions for PowerShell Gallery publishing.

## 0.2.2 - 2026-01-30
- Treat empty confirmation input as yes to match (Y/n) prompts.

## 0.2.1 - 2026-01-30
- Add PowerShell Gallery script metadata for Start/Stop scripts.
- Document PowerShell Gallery installation and publish steps.

## 0.2.0 - 2026-01-30
- Enable automatic remediation by default with an opt-out flag.
- Add Stop-OpenSshServer script for on-demand shutdown.
- Improve elevation flow with sudo support and clearer prompts.
- Write Pester test results into TestResults/.

## 0.1.0 - 2026-01-30
- Initial release with OpenSSH Server startup checks and remediation.
