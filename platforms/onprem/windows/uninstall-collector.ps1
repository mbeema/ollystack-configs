# =============================================================================
# OpenTelemetry Collector Contrib - Windows Uninstall Script
# =============================================================================
# Removes the OpenTelemetry Collector installation from Windows.
#
# Usage:
#   .\uninstall-collector.ps1
#   .\uninstall-collector.ps1 -KeepConfig
#   .\uninstall-collector.ps1 -Mode gateway
#
# Requirements:
#   - Run as Administrator
# =============================================================================

#Requires -RunAsAdministrator

[CmdletBinding()]
param(
    [Parameter(HelpMessage = "Uninstall mode: agent, gateway, or all")]
    [ValidateSet("agent", "gateway", "all")]
    [string]$Mode = "all",

    [Parameter(HelpMessage = "Keep configuration files")]
    [switch]$KeepConfig,

    [Parameter(HelpMessage = "Keep log files")]
    [switch]$KeepLogs,

    [Parameter(HelpMessage = "Skip confirmation prompts")]
    [switch]$Force
)

# ---- Configuration ----
$ErrorActionPreference = "Stop"

$InstallDir = "C:\Program Files\otel-collector"
$ConfigDir = "C:\ProgramData\otel-collector\config"
$LogDir = "C:\ProgramData\otel-collector\logs"
$StorageDir = "C:\ProgramData\otel-collector\storage"
$DataRoot = "C:\ProgramData\otel-collector"

# ---- Helper Functions ----

function Write-Step {
    param([string]$Message)
    Write-Host "[STEP] " -ForegroundColor Blue -NoNewline
    Write-Host $Message
}

function Write-Success {
    param([string]$Message)
    Write-Host "[OK]   " -ForegroundColor Green -NoNewline
    Write-Host $Message
}

function Write-Warn {
    param([string]$Message)
    Write-Host "[WARN] " -ForegroundColor Yellow -NoNewline
    Write-Host $Message
}

function Write-Err {
    param([string]$Message)
    Write-Host "[ERROR] " -ForegroundColor Red -NoNewline
    Write-Host $Message
}

# ---- Confirmation ----

Write-Host ""
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host "  OpenTelemetry Collector Uninstaller (Windows)"
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host ""

if (-not $Force) {
    $confirmation = Read-Host "This will remove the OpenTelemetry Collector. Continue? (y/N)"
    if ($confirmation -ne 'y' -and $confirmation -ne 'Y') {
        Write-Host "Uninstall cancelled."
        exit 0
    }
}

# ---- Determine services to remove ----

$serviceNames = @()
if ($Mode -eq "all") {
    $serviceNames = @("otel-collector-agent", "otel-collector-gateway", "otel-collector")
} else {
    $serviceNames = @("otel-collector-$Mode")
}

# ---- Stop and Remove Services ----

foreach ($serviceName in $serviceNames) {
    Write-Step "Processing service: $serviceName"

    $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
    if ($service) {
        # Stop the service if running
        if ($service.Status -eq "Running") {
            Write-Step "Stopping service: $serviceName..."
            try {
                Stop-Service -Name $serviceName -Force -NoWait
                $service.WaitForStatus("Stopped", [TimeSpan]::FromSeconds(30))
                Write-Success "Service stopped."
            } catch {
                Write-Warn "Timed out stopping service. Forcing termination..."
                $process = Get-WmiObject Win32_Service | Where-Object { $_.Name -eq $serviceName }
                if ($process -and $process.ProcessId) {
                    Stop-Process -Id $process.ProcessId -Force -ErrorAction SilentlyContinue
                    Start-Sleep -Seconds 3
                }
            }
        }

        # Remove the service
        Write-Step "Removing service: $serviceName..."
        try {
            & sc.exe delete $serviceName 2>$null
            Start-Sleep -Seconds 2
            Write-Success "Service removed: $serviceName"
        } catch {
            Write-Err "Failed to remove service: $_"
        }
    } else {
        Write-Success "Service not found (already removed): $serviceName"
    }
}

# ---- Remove WinSW Service ----

$winswExe = Join-Path $InstallDir "otel-collector-service.exe"
if (Test-Path $winswExe) {
    Write-Step "Removing WinSW service..."
    try {
        & $winswExe stop 2>$null
        Start-Sleep -Seconds 3
        & $winswExe uninstall 2>$null
        Write-Success "WinSW service removed."
    } catch {
        Write-Warn "WinSW removal encountered issues: $_"
    }
}

# ---- Remove Firewall Rules ----

Write-Step "Removing firewall rules..."

$firewallRuleNames = @(
    "OTel Collector OTLP gRPC",
    "OTel Collector OTLP HTTP",
    "OTel Collector Health Check"
)

foreach ($ruleName in $firewallRuleNames) {
    $rule = Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue
    if ($rule) {
        Remove-NetFirewallRule -DisplayName $ruleName
        Write-Success "Firewall rule removed: $ruleName"
    }
}

# ---- Remove Installation Directory ----

Write-Step "Removing installation directory..."

if (Test-Path $InstallDir) {
    try {
        Remove-Item -Path $InstallDir -Recurse -Force
        Write-Success "Removed: $InstallDir"
    } catch {
        Write-Err "Failed to remove $InstallDir. Files may be in use."
        Write-Warn "Try removing manually after reboot: $InstallDir"
    }
} else {
    Write-Success "Already removed: $InstallDir"
}

# ---- Remove Storage Directory ----

Write-Step "Removing storage directory..."

if (Test-Path $StorageDir) {
    try {
        Remove-Item -Path $StorageDir -Recurse -Force
        Write-Success "Removed: $StorageDir"
    } catch {
        Write-Warn "Failed to remove storage: $_"
    }
}

# ---- Remove Config (unless --KeepConfig) ----

if (-not $KeepConfig) {
    Write-Step "Removing configuration..."

    if (Test-Path $ConfigDir) {
        try {
            Remove-Item -Path $ConfigDir -Recurse -Force
            Write-Success "Removed: $ConfigDir"
        } catch {
            Write-Warn "Failed to remove config: $_"
        }
    }
} else {
    Write-Success "Configuration preserved at: $ConfigDir"
}

# ---- Remove Logs (unless --KeepLogs) ----

if (-not $KeepLogs) {
    Write-Step "Removing logs..."

    if (Test-Path $LogDir) {
        try {
            Remove-Item -Path $LogDir -Recurse -Force
            Write-Success "Removed: $LogDir"
        } catch {
            Write-Warn "Failed to remove logs: $_"
        }
    }
} else {
    Write-Success "Logs preserved at: $LogDir"
}

# ---- Clean up empty data root ----

if (Test-Path $DataRoot) {
    $remaining = Get-ChildItem -Path $DataRoot -Recurse -ErrorAction SilentlyContinue
    if (-not $remaining) {
        Remove-Item -Path $DataRoot -Force -ErrorAction SilentlyContinue
        Write-Success "Removed empty data directory: $DataRoot"
    }
}

# ---- Remove Environment Variables ----

Write-Step "Removing system environment variables..."

$envVarsToRemove = @(
    "GATEWAY_ENDPOINT",
    "BACKEND_OTLP_ENDPOINT",
    "SAMPLING_RATE"
)

foreach ($varName in $envVarsToRemove) {
    $existingValue = [System.Environment]::GetEnvironmentVariable($varName, "Machine")
    if ($existingValue) {
        [System.Environment]::SetEnvironmentVariable($varName, $null, "Machine")
        Write-Success "Removed env var: $varName"
    }
}

# Note: We intentionally do not remove ENVIRONMENT, TEAM, NODE_NAME
# as they may be used by other services
Write-Warn "Preserved shared env vars: ENVIRONMENT, TEAM, NODE_NAME (remove manually if needed)"

# ---- Summary ----

Write-Host ""
Write-Host "======================================================" -ForegroundColor Cyan
Write-Success "Uninstallation complete!"
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host ""

if ($KeepConfig) {
    Write-Host "  Config preserved: $ConfigDir"
}
if ($KeepLogs) {
    Write-Host "  Logs preserved:   $LogDir"
}
Write-Host ""
