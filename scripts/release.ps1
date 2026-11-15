# Script de release para Flumi.
# Uso: .\scripts\release.ps1 [-SkipBuild]
# Hace: bump (manual), flutter build apk (arm64 + universal), genera version.json,
# crea tag git. La subida al servidor/GitHub Releases y la actualizacion de la
# config remota en Supabase la haces tu (ver instrucciones al final).

param([switch]$SkipBuild)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

$pubspec = Get-Content pubspec.yaml
$versionLine = ($pubspec | Select-String '^version:').Line
$version = ($versionLine -split ':\s*')[1].Trim()
$ver = ($version -split '\+')[0]
$build = ($version -split '\+')[1]
Write-Host "Version: $version"

if (-not $SkipBuild) {
  Write-Host "Compilando APK arm64..."
  flutter build apk --release --target-platform android-arm64
  Write-Host "Compilando APK universal..."
  flutter build apk --release
}

$apkDir = "build\app\outputs\flutter-apk"
$arm64 = "$apkDir\app-arm64-v8a-release.apk"
$universal = "$apkDir\app-release.apk"
Write-Host "APK arm64: $arm64"
Write-Host "APK universal: $universal"

# Generar version.json listo para subir.
$versionJson = @{
  version = $ver
  build = [int]$build
  apk_url = "https://TU_SERVIDOR/flumi_$version.apk"
  changelog = "Nueva version $version"
  obligatoria = $false
} | ConvertTo-Json -Depth 3
$versionJson | Out-File -Encoding utf8 "build\version.json"
Write-Host "Generado build\version.json"

# Tag git.
$tag = "v$version"
git tag -a $tag -m "Release $version" 2>$null
Write-Host "Tag creado: $tag (si no existia)"

Write-Host ""
Write-Host "=== PASOS MANUALES RESTANTES ==="
Write-Host "1. Sube el APK a tu servidor/GitHub Releases."
Write-Host "2. Actualiza build\version.json con la URL real y subelo (o actualiza config remota en Supabase)."
Write-Host "3. En Supabase config remota:"
Write-Host "   - version_minima_build = $build"
Write-Host "   - actualizar_url = URL del APK"
Write-Host "4. git push origin $tag"
Write-Host "5. (Opcional Shorebird) shorebird patch android"
