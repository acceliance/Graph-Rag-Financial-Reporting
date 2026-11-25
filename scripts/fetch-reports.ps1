<#
.SYNOPSIS
    Downloads the public annual reports listed in samples\real-reports\manifest.csv.

.DESCRIPTION
    Each report is fetched from the address in the manifest (the issuer's or the regulator's
    own site), checked to be a PDF, and compared with the manifest's SHA-256 checksum.
    Files land in samples\real-reports\downloads, which is git-ignored: the reports are
    third-party documents and are never committed. Upload them afterwards on the Documents
    screen of the application.

    A file already present with the right checksum is not downloaded again.
    A line without checksum is downloaded and its checksum is printed, to paste into the manifest.

.PARAMETER Manifest
    Path of the manifest. Default: samples\real-reports\manifest.csv.

.PARAMETER OutDir
    Download folder. Default: samples\real-reports\downloads.

.PARAMETER UserAgent
    User-Agent header sent with each request. Some sites (sec.gov among them) ask automated
    clients to identify themselves with a contact address: pass yours here.

.PARAMETER DelaySeconds
    Pause between two downloads. Default: 1.

.EXAMPLE
    .\scripts\fetch-reports.ps1

.EXAMPLE
    .\scripts\fetch-reports.ps1 -UserAgent "My Company name@example.com"
#>
[CmdletBinding()]
param(
    [string]$Manifest,
    [string]$OutDir,
    [string]$UserAgent = 'graph-rag-fetch-reports/1.0',
    [int]$DelaySeconds = 1
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

$root = Split-Path -Parent $PSScriptRoot
if (-not $Manifest) { $Manifest = Join-Path $root 'samples\real-reports\manifest.csv' }
if (-not $OutDir) { $OutDir = Join-Path $root 'samples\real-reports\downloads' }

if (-not (Test-Path -LiteralPath $Manifest)) {
    Write-Host "Manifest not found: $Manifest" -ForegroundColor Red
    exit 1
}

function Get-Sha256([string]$Path) {
    (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Test-PdfHeader([string]$Path) {
    $stream = [IO.File]::OpenRead($Path)
    try {
        $buffer = New-Object byte[] 5
        $read = $stream.Read($buffer, 0, 5)
        return ($read -eq 5) -and ([Text.Encoding]::ASCII.GetString($buffer) -eq '%PDF-')
    }
    finally { $stream.Dispose() }
}

$lines = Get-Content -LiteralPath $Manifest -Encoding UTF8 |
    Where-Object { $_.Trim() -and -not $_.TrimStart().StartsWith('#') }
$rows = @($lines | ConvertFrom-Csv)

if ($rows.Count -eq 0) {
    Write-Host "The manifest lists no report yet. Add lines to $Manifest (see samples\real-reports\README.md)."
    exit 0
}

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

$ok = 0; $unverified = 0; $failed = 0; $first = $true

foreach ($row in $rows) {
    $file = "$($row.file)".Trim()
    $url = "$($row.url)".Trim()
    $expected = "$($row.sha256)".Trim().ToLowerInvariant()
    $label = "$($row.company) $($row.fiscal_year)".Trim()

    if ($file -notmatch '^[A-Za-z0-9._-]+\.pdf$') {
        Write-Host "FAILED  '$file': the file name must use letters, digits, dot, dash, underscore and end in .pdf" -ForegroundColor Red
        $failed++; continue
    }
    if ($url -notmatch '^https://') {
        Write-Host "FAILED  $file : the url must start with https://" -ForegroundColor Red
        $failed++; continue
    }
    if ($expected -and $expected -notmatch '^[0-9a-f]{64}$') {
        Write-Host "FAILED  $file : sha256 must be 64 hexadecimal characters, or empty" -ForegroundColor Red
        $failed++; continue
    }

    $target = Join-Path $OutDir $file
    $part = "$target.part"

    if (Test-Path -LiteralPath $target) {
        $actual = Get-Sha256 $target
        if ($expected -and $actual -eq $expected) {
            Write-Host "OK      $file (already downloaded)"
            $ok++; continue
        }
        if (-not $expected) {
            Write-Host "KEPT    $file (already downloaded, no checksum in the manifest)" -ForegroundColor Yellow
            Write-Host "        sha256 to paste: $actual"
            $unverified++; continue
        }
        Write-Host "        $file is present with another checksum: downloading again"
    }

    if (-not $first -and $DelaySeconds -gt 0) { Start-Sleep -Seconds $DelaySeconds }
    $first = $false

    Write-Host "GET     $file  ($label)"
    try {
        Invoke-WebRequest -Uri $url -OutFile $part -UserAgent $UserAgent -UseBasicParsing -MaximumRedirection 5
    }
    catch {
        Remove-Item -LiteralPath $part -Force -ErrorAction SilentlyContinue
        Write-Host "FAILED  $file : $($_.Exception.Message)" -ForegroundColor Red
        $failed++; continue
    }

    if (-not (Test-PdfHeader $part)) {
        Remove-Item -LiteralPath $part -Force
        Write-Host "FAILED  $file : the address did not return a PDF (a web page or a refusal, most likely)" -ForegroundColor Red
        $failed++; continue
    }

    $actual = Get-Sha256 $part
    if ($expected -and $actual -ne $expected) {
        Remove-Item -LiteralPath $part -Force
        Write-Host "FAILED  $file : checksum differs from the manifest; the publisher may have replaced the file" -ForegroundColor Red
        Write-Host "        expected $expected"
        Write-Host "        received $actual"
        $failed++; continue
    }

    Move-Item -LiteralPath $part -Destination $target -Force
    if ($expected) {
        Write-Host "OK      $file"
        $ok++
    }
    else {
        Write-Host "KEPT    $file (no checksum in the manifest)" -ForegroundColor Yellow
        Write-Host "        sha256 to paste: $actual"
        $unverified++
    }
}

Write-Host ""
Write-Host "$ok verified, $unverified without checksum, $failed failed. Folder: $OutDir"
if ($failed -gt 0) { exit 1 }
