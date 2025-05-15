# =============================================================================
# OpenTelemetry Collector Contrib - Windows Install Script
# =============================================================================
# Installs the OpenTelemetry Collector Contrib distribution on Windows.
#
# Usage:
#   .\install-collector.ps1 [-Version "0.96.0"] [-Mode "agent"] [-GatewayEndpoint "gateway:4317"]
#   .\install-collector.ps1 -Mode "gateway" -BackendEndpoint "tempo:4317"
#
# Requirements:
#   - Run as Administrator
#   - PowerShell 5.1 or later
# =============================================================================

#Requires -RunAsAdministrator

[CmdletBinding()]
param(
    [Parameter(HelpMessage = "Collector version to install")]
    [string]$Version = "0.96.0",

    [Parameter(HelpMessage = "Install mode: agent or gateway")]
    [ValidateSet("agent", "gateway")]
    [string]$Mode = "agent",

    [Parameter(HelpMessage = "Gateway OTLP endpoint (for agent mode)")]
    [string]$GatewayEndpoint = "gateway.internal:4317",

    [Parameter(HelpMessage = "Backend OTLP endpoint (for gateway mode)")]
    [string]$BackendEndpoint = "backend.internal:4317",

    [Parameter(HelpMessage = "Deployment environment name")]
    [string]$Environment = "production",

    [Parameter(HelpMessage = "Team name")]
    [string]$Team = "platform",

    [Parameter(HelpMessage = "Path to custom config file")]
    [string]$ConfigPath = "",

    [Parameter(HelpMessage = "Skip checksum verification")]
    [switch]$SkipChecksum
)

# ---- Configuration ----
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$InstallDir = "C:\Program Files\otel-collector"
$ConfigDir = "C:\ProgramData\otel-collector\config"
$LogDir = "C:\ProgramData\otel-collector\logs"
$StorageDir = "C:\ProgramData\otel-collector\storage"
$ServiceName = "otel-collector-$Mode"
$ServiceDisplayName = "OpenTelemetry Collector ($Mode)"
$BaseUrl = "https://github.com/open-telemetry/opentelemetry-collector-releases/releases/download"

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

function Test-Administrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# ---- Pre-flight Checks ----

Write-Host ""
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host "  OpenTelemetry Collector Installer (Windows)"
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Administrator)) {
    Write-Err "This script must be run as Administrator."
    exit 1
}

Write-Success "Mode: $Mode"
Write-Success "Version: $Version"
Write-Host ""

# ---- Create Directories ----

Write-Step "Creating directories..."

$dirs = @($InstallDir, $ConfigDir, $LogDir, $StorageDir)
foreach ($dir in $dirs) {
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        Write-Success "Created: $dir"
    } else {
        Write-Success "Exists:  $dir"
    }
}

# ---- Download Collector ----

Write-Step "Downloading OpenTelemetry Collector Contrib v${Version}..."

$arch = if ([System.Environment]::Is64BitOperatingSystem) { "amd64" } else { "386" }
$zipName = "otelcol-contrib_${Version}_windows_${arch}.tar.gz"
$downloadUrl = "${BaseUrl}/v${Version}/${zipName}"
$checksumsUrl = "${BaseUrl}/v${Version}/otelcol-contrib_${Version}_checksums.txt"
$tempDir = Join-Path $env:TEMP "otel-install-$(Get-Random)"
$downloadPath = Join-Path $tempDir $zipName
$checksumsPath = Join-Path $tempDir "checksums.txt"

New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

try {
    # Download checksums
    if (-not $SkipChecksum) {
        Write-Step "Downloading checksums..."
        try {
            Invoke-WebRequest -Uri $checksumsUrl -OutFile $checksumsPath -UseBasicParsing
            Write-Success "Checksums downloaded."
        } catch {
            Write-Warn "Could not download checksums. Continuing without verification."
            $SkipChecksum = $true
        }
    }

    # Download collector
    Write-Step "Downloading collector binary..."
    Invoke-WebRequest -Uri $downloadUrl -OutFile $downloadPath -UseBasicParsing
    Write-Success "Download complete: $zipName"

    # Verify checksum
    if (-not $SkipChecksum) {
        Write-Step "Verifying checksum..."
        $expectedLine = Get-Content $checksumsPath | Where-Object { $_ -match $zipName }
        if ($expectedLine) {
            $expectedHash = ($expectedLine -split '\s+')[0]
            $actualHash = (Get-FileHash -Path $downloadPath -Algorithm SHA256).Hash.ToLower()

            if ($expectedHash -eq $actualHash) {
                Write-Success "Checksum verified: $actualHash"
            } else {
                Write-Err "Checksum mismatch!"
                Write-Err "  Expected: $expectedHash"
                Write-Err "  Actual:   $actualHash"
                exit 1
            }
        } else {
            Write-Warn "Checksum entry not found for $zipName. Skipping."
        }
    }

    # Extract
    Write-Step "Extracting collector..."
    # Use tar to extract .tar.gz on Windows 10+
    & tar -xzf $downloadPath -C $tempDir 2>$null
    if ($LASTEXITCODE -ne 0) {
        # Fallback: try using 7-Zip if available
        $sevenZip = "C:\Program Files\7-Zip\7z.exe"
        if (Test-Path $sevenZip) {
            & $sevenZip x $downloadPath -o"$tempDir" -y | Out-Null
            $tarFile = Join-Path $tempDir ($zipName -replace '\.gz$', '')
            & $sevenZip x $tarFile -o"$tempDir" -y | Out-Null
        } else {
            Write-Err "Failed to extract archive. Please install tar or 7-Zip."
            exit 1
        }
    }

    # Copy binary
    $binarySource = Join-Path $tempDir "otelcol-contrib.exe"
    $binaryDest = Join-Path $InstallDir "otelcol-contrib.exe"

    if (Test-Path $binarySource) {
        Copy-Item -Path $binarySource -Destination $binaryDest -Force
        Write-Success "Binary installed: $binaryDest"
    } else {
        Write-Err "Binary not found in extracted archive."
        exit 1
    }

} finally {
    # Cleanup temp files
    Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
}

# ---- Install Configuration ----

Write-Step "Installing configuration..."

$configDest = Join-Path $ConfigDir "config.yaml"

if ($ConfigPath -and (Test-Path $ConfigPath)) {
    Copy-Item -Path $ConfigPath -Destination $configDest -Force
    Write-Success "Copied config from: $ConfigPath"
} else {
    # Look for bundled config
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    $bundledConfig = Join-Path $scriptDir "otel-agent.yaml"

    if (Test-Path $bundledConfig) {
        Copy-Item -Path $bundledConfig -Destination $configDest -Force
        Write-Success "Copied bundled config."
    } else {
        Write-Warn "No config file found. Please place a config at: $configDest"
    }
}

# Create environment variables file
$envFile = Join-Path $ConfigDir "env.ps1"
if (-not (Test-Path $envFile)) {
    $envContent = @"
# OpenTelemetry Collector Environment Variables
`$env:ENVIRONMENT = "$Environment"
`$env:TEAM = "$Team"
`$env:NODE_NAME = "$env:COMPUTERNAME"
`$env:OTLP_INSECURE = "true"
`$env:MEMORY_LIMIT_MIB = "400"
`$env:MEMORY_SPIKE_MIB = "100"
`$env:OTLP_GRPC_PORT = "4317"
`$env:OTLP_HTTP_PORT = "4318"
"@

    if ($Mode -eq "agent") {
        $envContent += "`n`$env:GATEWAY_ENDPOINT = `"$GatewayEndpoint`""
    } else {
        $envContent += "`n`$env:BACKEND_OTLP_ENDPOINT = `"$BackendEndpoint`""
        $envContent += "`n`$env:SAMPLING_RATE = `"10`""
        $envContent += "`n`$env:BATCH_TIMEOUT = `"10s`""
        $envContent += "`n`$env:BATCH_SIZE = `"16384`""
    }

    Set-Content -Path $envFile -Value $envContent
    Write-Success "Environment file created: $envFile"
}

# ---- Set System Environment Variables ----

Write-Step "Setting system environment variables..."

[System.Environment]::SetEnvironmentVariable("ENVIRONMENT", $Environment, "Machine")
[System.Environment]::SetEnvironmentVariable("TEAM", $Team, "Machine")
[System.Environment]::SetEnvironmentVariable("NODE_NAME", $env:COMPUTERNAME, "Machine")
[System.Environment]::SetEnvironmentVariable("OTLP_INSECURE", "true", "Machine")
[System.Environment]::SetEnvironmentVariable("MEMORY_LIMIT_MIB", "400", "Machine")
[System.Environment]::SetEnvironmentVariable("MEMORY_SPIKE_MIB", "100", "Machine")

if ($Mode -eq "agent") {
    [System.Environment]::SetEnvironmentVariable("GATEWAY_ENDPOINT", $GatewayEndpoint, "Machine")
} else {
    [System.Environment]::SetEnvironmentVariable("BACKEND_OTLP_ENDPOINT", $BackendEndpoint, "Machine")
    [System.Environment]::SetEnvironmentVariable("SAMPLING_RATE", "10", "Machine")
}

Write-Success "System environment variables set."

# ---- Install Windows Service ----

Write-Step "Installing Windows service: $ServiceName..."

# Stop existing service if running
$existingService = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
if ($existingService) {
    Write-Warn "Service already exists. Stopping and removing..."
    if ($existingService.Status -eq "Running") {
        Stop-Service -Name $ServiceName -Force
        Start-Sleep -Seconds 3
    }
    & sc.exe delete $ServiceName 2>$null
    Start-Sleep -Seconds 2
}

# Create the service using sc.exe
$binaryPath = "`"$binaryDest`" --config=`"$configDest`""
& sc.exe create $ServiceName `
    binPath= $binaryPath `
    DisplayName= $ServiceDisplayName `
    start= auto `
    obj= "LocalSystem"

if ($LASTEXITCODE -ne 0) {
    Write-Err "Failed to create Windows service."
    exit 1
}

# Set service description
& sc.exe description $ServiceName "OpenTelemetry Collector Contrib - $Mode mode"

# Configure service recovery (restart on failure)
& sc.exe failure $ServiceName `
    reset= 86400 `
    actions= restart/5000/restart/10000/restart/30000

# Configure delayed auto-start
& sc.exe config $ServiceName start= delayed-auto

Write-Success "Service created: $ServiceName"

# ---- Start Service ----

Write-Step "Starting service..."

Start-Service -Name $ServiceName
Start-Sleep -Seconds 3

$service = Get-Service -Name $ServiceName
if ($service.Status -eq "Running") {
    Write-Success "Service is running."
} else {
    Write-Warn "Service status: $($service.Status). Check Event Viewer for details."
}

# ---- Configure Firewall ----

Write-Step "Configuring Windows Firewall rules..."

$firewallRules = @(
    @{ Name = "OTel Collector OTLP gRPC"; Port = 4317; Protocol = "TCP" },
    @{ Name = "OTel Collector OTLP HTTP"; Port = 4318; Protocol = "TCP" },
    @{ Name = "OTel Collector Health Check"; Port = 13133; Protocol = "TCP" }
)

foreach ($rule in $firewallRules) {
    $existingRule = Get-NetFirewallRule -DisplayName $rule.Name -ErrorAction SilentlyContinue
    if (-not $existingRule) {
        New-NetFirewallRule `
            -DisplayName $rule.Name `
            -Direction Inbound `
            -Protocol $rule.Protocol `
            -LocalPort $rule.Port `
            -Action Allow `
            -Profile Domain,Private | Out-Null
        Write-Success "Firewall rule created: $($rule.Name)"
    } else {
        Write-Success "Firewall rule exists: $($rule.Name)"
    }
}

# ---- Summary ----

Write-Host ""
Write-Host "======================================================" -ForegroundColor Cyan
Write-Success "Installation complete!"
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Binary:  $binaryDest"
Write-Host "  Config:  $configDest"
Write-Host "  Logs:    $LogDir"
Write-Host "  Service: $ServiceName"
Write-Host ""
Write-Host "  Useful commands:"
Write-Host "    Get-Service $ServiceName"
Write-Host "    Restart-Service $ServiceName"
Write-Host "    Get-EventLog -LogName Application -Source $ServiceName -Newest 20"
Write-Host ""
