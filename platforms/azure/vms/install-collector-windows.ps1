# install-collector-windows.ps1
# Installs the OpenTelemetry Collector on Azure Windows VMs.
# Downloads the collector binary, installs it as a Windows service,
# and configures it for Azure Managed Identity.
#
# Usage:
#   .\install-collector-windows.ps1 `
#     -OtlpEndpoint "https://gateway.example.com:4317" `
#     -Environment "production" `
#     -Version "0.96.0"

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$OtlpEndpoint,

    [Parameter(Mandatory = $false)]
    [string]$Environment = "production",

    [Parameter(Mandatory = $false)]
    [string]$Version = "0.96.0",

    [Parameter(Mandatory = $false)]
    [string]$ServiceName = "windows-vm-agent",

    [Parameter(Mandatory = $false)]
    [string]$InstallDir = "C:\Program Files\OpenTelemetry Collector",

    [Parameter(Mandatory = $false)]
    [string]$ConfigDir = "C:\ProgramData\otelcol",

    [Parameter(Mandatory = $false)]
    [string]$LogLevel = "info"
)

# -------------------------------------------------------------------
# Configuration
# -------------------------------------------------------------------
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$ServiceDisplayName = "OpenTelemetry Collector Contrib"
$WindowsServiceName = "otelcol-contrib"

Write-Host "============================================" -ForegroundColor Cyan
Write-Host " OpenTelemetry Collector Installer" -ForegroundColor Cyan
Write-Host " Azure Windows VM" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host " Version:     $Version"
Write-Host " Endpoint:    $OtlpEndpoint"
Write-Host " Environment: $Environment"
Write-Host " Install Dir: $InstallDir"
Write-Host "============================================" -ForegroundColor Cyan

# -------------------------------------------------------------------
# Step 1: Check prerequisites
# -------------------------------------------------------------------
Write-Host "`n[1/7] Checking prerequisites..." -ForegroundColor Yellow

if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Error "This script must be run as Administrator."
    exit 1
}

# -------------------------------------------------------------------
# Step 2: Create directories
# -------------------------------------------------------------------
Write-Host "[2/7] Creating directories..." -ForegroundColor Yellow

$directories = @($InstallDir, $ConfigDir, "$ConfigDir\storage")
foreach ($dir in $directories) {
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        Write-Host "  Created: $dir"
    }
}

# -------------------------------------------------------------------
# Step 3: Stop existing service if running
# -------------------------------------------------------------------
Write-Host "[3/7] Checking for existing installation..." -ForegroundColor Yellow

$existingService = Get-Service -Name $WindowsServiceName -ErrorAction SilentlyContinue
if ($existingService) {
    Write-Host "  Stopping existing service..."
    Stop-Service -Name $WindowsServiceName -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 3

    # Remove existing service
    Write-Host "  Removing existing service..."
    sc.exe delete $WindowsServiceName | Out-Null
    Start-Sleep -Seconds 2
}

# -------------------------------------------------------------------
# Step 4: Download and install the collector
# -------------------------------------------------------------------
Write-Host "[4/7] Downloading OpenTelemetry Collector Contrib v$Version..." -ForegroundColor Yellow

$downloadUrl = "https://github.com/open-telemetry/opentelemetry-collector-releases/releases/download/v${Version}/otelcol-contrib_${Version}_windows_amd64.tar.gz"
$tempDir = Join-Path $env:TEMP "otelcol-install"
$archivePath = Join-Path $tempDir "otelcol-contrib.tar.gz"

if (Test-Path $tempDir) {
    Remove-Item -Path $tempDir -Recurse -Force
}
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -Uri $downloadUrl -OutFile $archivePath -UseBasicParsing
    Write-Host "  Downloaded successfully."
}
catch {
    Write-Error "Failed to download collector: $_"
    exit 1
}

# Extract archive
Write-Host "  Extracting archive..."
try {
    tar -xzf $archivePath -C $tempDir
    Copy-Item -Path (Join-Path $tempDir "otelcol-contrib.exe") -Destination (Join-Path $InstallDir "otelcol-contrib.exe") -Force
}
catch {
    Write-Error "Failed to extract collector: $_"
    exit 1
}

# Cleanup temp files
Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue

Write-Host "  Installed to: $InstallDir\otelcol-contrib.exe"

# -------------------------------------------------------------------
# Step 5: Validate Azure Managed Identity
# -------------------------------------------------------------------
Write-Host "[5/7] Validating Azure Managed Identity..." -ForegroundColor Yellow

try {
    $imdsResponse = Invoke-RestMethod -Uri "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https://management.azure.com/" `
        -Headers @{Metadata = "true"} `
        -TimeoutSec 5 `
        -ErrorAction SilentlyContinue

    if ($imdsResponse.access_token) {
        Write-Host "  Managed Identity: Available"
    }
}
catch {
    Write-Host "  WARNING: Managed Identity not available. Ensure VM has a managed identity assigned." -ForegroundColor DarkYellow
}

# Retrieve VM metadata
try {
    $vmMetadata = Invoke-RestMethod -Uri "http://169.254.169.254/metadata/instance?api-version=2021-02-01" `
        -Headers @{Metadata = "true"} `
        -TimeoutSec 5 `
        -ErrorAction SilentlyContinue

    $vmName = $vmMetadata.compute.name
    $vmRegion = $vmMetadata.compute.location
    $vmRg = $vmMetadata.compute.resourceGroupName
    $vmSub = $vmMetadata.compute.subscriptionId

    Write-Host "  VM Name:      $vmName"
    Write-Host "  Region:       $vmRegion"
    Write-Host "  RG:           $vmRg"
    Write-Host "  Subscription: $vmSub"
}
catch {
    Write-Host "  WARNING: Could not retrieve VM metadata." -ForegroundColor DarkYellow
}

# -------------------------------------------------------------------
# Step 6: Deploy configuration
# -------------------------------------------------------------------
Write-Host "[6/7] Deploying collector configuration..." -ForegroundColor Yellow

$configSource = Join-Path $PSScriptRoot "otel-agent-windows.yaml"

if (Test-Path $configSource) {
    Copy-Item -Path $configSource -Destination (Join-Path $ConfigDir "config.yaml") -Force
    Write-Host "  Config deployed to: $ConfigDir\config.yaml"
}
else {
    Write-Host "  WARNING: $configSource not found." -ForegroundColor DarkYellow
    Write-Host "  Please copy otel-agent-windows.yaml to $ConfigDir\config.yaml"
}

# Create environment variables file for reference
$envContent = @"
# OpenTelemetry Collector Environment Configuration
# Auto-generated by install-collector-windows.ps1

OTLP_ENDPOINT=$OtlpEndpoint
OTLP_TLS_INSECURE=false
ENVIRONMENT=$Environment
SERVICE_NAME=$ServiceName
SERVICE_NAMESPACE=azure-vm
HOST_METRICS_INTERVAL=15s
BATCH_SIZE=512
BATCH_TIMEOUT=5s
MEMORY_LIMIT_MIB=512
MEMORY_SPIKE_LIMIT_MIB=128
OTEL_LOG_LEVEL=$LogLevel
APP_LOG_PATH=C:\app\logs\*.log
"@

Set-Content -Path (Join-Path $ConfigDir "otelcol.env") -Value $envContent
Write-Host "  Environment file: $ConfigDir\otelcol.env"

# Set environment variables at machine level
[System.Environment]::SetEnvironmentVariable("OTLP_ENDPOINT", $OtlpEndpoint, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable("OTLP_TLS_INSECURE", "false", [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable("ENVIRONMENT", $Environment, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable("SERVICE_NAME", $ServiceName, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable("SERVICE_NAMESPACE", "azure-vm", [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable("OTEL_LOG_LEVEL", $LogLevel, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable("HOST_METRICS_INTERVAL", "15s", [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable("BATCH_SIZE", "512", [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable("BATCH_TIMEOUT", "5s", [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable("MEMORY_LIMIT_MIB", "512", [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable("MEMORY_SPIKE_LIMIT_MIB", "128", [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable("APP_LOG_PATH", "C:\app\logs\*.log", [System.EnvironmentVariableTarget]::Machine)

Write-Host "  Machine-level environment variables set."

# -------------------------------------------------------------------
# Step 7: Install and start Windows service
# -------------------------------------------------------------------
Write-Host "[7/7] Installing and starting Windows service..." -ForegroundColor Yellow

$binaryPath = "`"$InstallDir\otelcol-contrib.exe`" --config=`"$ConfigDir\config.yaml`""

# Create the Windows service
New-Service -Name $WindowsServiceName `
    -DisplayName $ServiceDisplayName `
    -Description "OpenTelemetry Collector Contrib - Collects traces, metrics, and logs from Azure VMs" `
    -BinaryPathName $binaryPath `
    -StartupType Automatic | Out-Null

# Configure service recovery options: restart on failure
sc.exe failure $WindowsServiceName reset= 86400 actions= restart/10000/restart/30000/restart/60000 | Out-Null

# Start the service
Start-Service -Name $WindowsServiceName
Start-Sleep -Seconds 5

# Verify service is running
$service = Get-Service -Name $WindowsServiceName
if ($service.Status -eq "Running") {
    Write-Host ""
    Write-Host "============================================" -ForegroundColor Green
    Write-Host " Installation Complete!" -ForegroundColor Green
    Write-Host "============================================" -ForegroundColor Green
    Write-Host " Service Status: RUNNING"
    Write-Host " Config:         $ConfigDir\config.yaml"
    Write-Host " Env File:       $ConfigDir\otelcol.env"
    Write-Host " Logs:           Event Viewer > Application Log"
    Write-Host " Health Check:   Invoke-WebRequest http://localhost:13133"
    Write-Host " Manage:         Get-Service $WindowsServiceName"
    Write-Host "============================================" -ForegroundColor Green
}
else {
    Write-Host ""
    Write-Host "============================================" -ForegroundColor Red
    Write-Host " WARNING: Service failed to start!" -ForegroundColor Red
    Write-Host "============================================" -ForegroundColor Red
    Write-Host " Check Event Viewer for errors."
    Write-Host " Config: $ConfigDir\config.yaml"
    Write-Host "============================================" -ForegroundColor Red
    exit 1
}
