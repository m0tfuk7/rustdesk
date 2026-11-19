param(
    [Parameter(Mandatory = $true)]
    [string]$RustDeskDirectory,

    [string]$DownloadCache = (Join-Path $env:TEMP "rustdesk-interception")
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$releaseUri = "https://github.com/oblitum/Interception/releases/download/v1.0.1/Interception.zip"
$releaseSha256 = "ad038963d6413055765128b0b931f6e765147c9916dba79e65d872b261f9af10"

$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = [Security.Principal.WindowsPrincipal]::new($identity)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw "Run this script from PowerShell as Administrator."
}

if (-not [Environment]::Is64BitOperatingSystem) {
    throw "This setup supports only 64-bit Windows."
}

$rustDeskPath = [IO.Path]::GetFullPath($RustDeskDirectory)
$rustDeskExecutable = Join-Path $rustDeskPath "rustdesk.exe"
if (-not (Test-Path -LiteralPath $rustDeskExecutable -PathType Leaf)) {
    throw "rustdesk.exe was not found in $rustDeskPath"
}

New-Item -ItemType Directory -Path $DownloadCache -Force | Out-Null
$archivePath = Join-Path $DownloadCache "Interception-v1.0.1.zip"

if (-not (Test-Path -LiteralPath $archivePath -PathType Leaf)) {
    Invoke-WebRequest -Uri $releaseUri -OutFile $archivePath
}

$actualSha256 = (Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash.ToLowerInvariant()
if ($actualSha256 -ne $releaseSha256) {
    Remove-Item -LiteralPath $archivePath -Force
    throw "Interception archive SHA-256 mismatch; the invalid download was removed."
}

$extractPath = Join-Path $DownloadCache ("extract-" + [Guid]::NewGuid().ToString("N"))
try {
    Expand-Archive -LiteralPath $archivePath -DestinationPath $extractPath

    $packagePath = Join-Path $extractPath "Interception"
    $libraryPath = Join-Path $packagePath "library\x64\interception.dll"
    $installerPath = Join-Path $packagePath "command line installer\install-interception.exe"
    if (-not (Test-Path -LiteralPath $libraryPath -PathType Leaf)) {
        throw "The verified archive does not contain the x64 Interception DLL."
    }
    if (-not (Test-Path -LiteralPath $installerPath -PathType Leaf)) {
        throw "The verified archive does not contain the Interception installer."
    }

    $installer = Start-Process -FilePath $installerPath -ArgumentList "/install" -Wait -PassThru
    if ($installer.ExitCode -ne 0) {
        throw "Interception driver installation failed with exit code $($installer.ExitCode)."
    }

    Copy-Item -LiteralPath $libraryPath -Destination (Join-Path $rustDeskPath "interception.dll") -Force
}
finally {
    if (Test-Path -LiteralPath $extractPath) {
        Remove-Item -LiteralPath $extractPath -Recurse -Force
    }
}

Write-Host "Interception is installed and interception.dll is beside rustdesk.exe."
Write-Host "Restart Windows before testing RustDesk Map Mode."
