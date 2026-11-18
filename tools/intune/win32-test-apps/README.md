# Win32 test apps for Azure Virtual Desktop personal desktops

A small, safe set of apps to prove Intune Win32 delivery to Microsoft Entra joined personal desktops, including the Teams media optimisation components. Replace or extend `apps.json` with your own developer toolchain for real testing.

| Id | App | Source | Depends on |
|---|---|---|---|
| `vcredist-x64` | Microsoft Visual C++ v14 Redistributable (x64) | `aka.ms/vc14/vc_redist.x64.exe` | none |
| `webrtc-redirector` | Remote Desktop WebRTC Redirector Service | `aka.ms/msrdcwebrtcsvc/msi` | `vcredist-x64` |
| `teams-vdi` | New Teams, machine-wide, with `IsWVDEnvironment = 1` and the Outlook meeting add-in | Teams bootstrapper and x64 MSIX (Microsoft fwlinks) | `vcredist-x64`, `webrtc-redirector` |
| `git` | Git for Windows (x64) | latest GitHub release | none |
| `vscode` | Visual Studio Code, system installer | `update.code.visualstudio.com` | none |
| `azure-cli` | Azure CLI (x64) | `aka.ms/installazurecliwindowsx64` | none |
| `powershell-7` | PowerShell 7 (x64), updated through Microsoft Update | latest GitHub release | none |

Teams on Azure Virtual Desktop needs the latest Visual C++ runtime and the `HKLM\SOFTWARE\Microsoft\Teams` value `IsWVDEnvironment = 1`. Learn recommends installing the WebRTC Redirector Service with new Teams, so users can fall back to WebRTC from devices that don't support SlimCore ([Learn](https://learn.microsoft.com/azure/virtual-desktop/teams-on-avd)). The Teams package sets the registry value before it provisions Teams with `teamsbootstrapper.exe -p -o <msix> --installTMA` ([Learn](https://learn.microsoft.com/microsoftteams/teams-client-vdi-requirements-deploy)). Microsoft 365 Apps in `../personal-desktops` excludes Teams, so this is the only Teams on the host.

## Build the packages

Run on any Windows 10 or 11 machine with internet access: an admin workstation, a packaging VM, or a test session host, which avoids copying files around. Windows PowerShell 5.1 or PowerShell 7.

```powershell
.\New-Win32TestAppPackages.ps1
.\New-Win32TestAppPackages.ps1 -Apps vcredist-x64, webrtc-redirector, teams-vdi
.\New-Win32TestAppPackages.ps1 -SourceFolder D:\Installers -IntuneWinAppUtilPath C:\Tools\IntuneWinAppUtil.exe
```

It downloads each installer, unless the same file name is in `-SourceFolder`. It then checks that the Authenticode signature is Valid and from the expected signer, and stops if not. Finally it builds `packages\<id>.intunewin` with the Microsoft Win32 Content Prep Tool. If `-IntuneWinAppUtilPath` isn't given, the tool comes from [microsoft/Microsoft-Win32-Content-Prep-Tool](https://github.com/microsoft/Microsoft-Win32-Content-Prep-Tool), and its signature is checked before it's run.

Output in `win32-test-apps-out`:
- `packages\*.intunewin`;
- `detection\Detect-<id>.ps1`;
- `intune-entries.md` and `.csv`, with every value to type into the admin center.

Each package holds `AppInstaller.ps1`, the app's `app.json` and the installer. `AppInstaller.ps1` runs as SYSTEM and logs to `C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\Win32TestApp-<id>-<action>.log`. It returns the installer's exit code, so 3010 becomes a soft reboot.

## Add each app in Intune

Apps > Windows > Add > Windows app (Win32), then:

1. **App package file:** `packages\<id>.intunewin`.
2. **App information:** name and publisher from `intune-entries.md`.
3. **Program:**
   - Install command `powershell.exe -ExecutionPolicy Bypass -NoProfile -File .\AppInstaller.ps1 -Action Install`.
   - Uninstall command the same with `-Action Uninstall`.
   - Install behavior System.
   - Return codes as listed.
4. **Requirements:** 64-bit, and your minimum Windows 11 version.
5. **Detection rules:** use a custom detection script, `detection\Detect-<id>.ps1`. Set run as 32-bit = No and signature check = No.
6. **Dependencies:** for `teams-vdi`, add `vcredist-x64` and `webrtc-redirector` with automatic install. For `webrtc-redirector`, add `vcredist-x64`.
7. **Assignments:** Required, to the personal desktop device group.

Add them in dependency order: VC++, then WebRTC, then Teams. Adding dependencies and supersedence needs the Intune permission Mobile apps > Relate, which the Application Manager role has. When you package a newer version later, add it as a new app and use supersedence to replace the old one ([Learn](https://learn.microsoft.com/intune/app-management/deployment/configure-win32-supersedence)).

## Check it worked

- On the host, in Teams, select Settings > About Teams. It should show **AVD SlimCore Media Optimized** or **AVD Media Optimized** ([Learn](https://learn.microsoft.com/azure/virtual-desktop/teams-on-avd#verify-media-optimizations-loaded)).
- Or run `deploy/personal/Test-PersonalDesktopHosts.ps1` from Cloud Shell. It reports the VC++ runtime, WebRTC Redirector, Teams provisioning, the `IsWVDEnvironment` value and the developer tools on every running host.

## Known limits

- Classic Teams on VDI reached end of support on 1 October 2026, and becomes unavailable on 1 April 2027. Use new Teams.
- WebRTC optimisation from Windows endpoints is deprecated. SlimCore becomes the default ([Learn](https://learn.microsoft.com/microsoftteams/teams-client-vdi-requirements-deploy)).
- Learn lists a known issue: WebRTC-optimised users don't see incoming video on Windows 11 24H2 hosts with User Account Control turned off. Keep UAC on.
- VS Code's system installer updates only when an administrator runs it. Manage updates through new packages.
