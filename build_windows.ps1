# Script para limpiar y construir la aplicación Windows
Write-Host "Limpiando procesos y archivos bloqueados..." -ForegroundColor Yellow

# Detener procesos
Get-Process | Where-Object {$_.ProcessName -like "*dart*" -or $_.ProcessName -like "*flutter*" -or $_.ProcessName -like "*msbuild*" -or $_.ProcessName -like "*cmake*"} | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 3

# Deshabilitar hooks de build
$env:DART_PUB_SKIP_HOOKS = "true"
$env:FLUTTER_BUILD_MODE = "debug"

# Limpiar carpeta problemática de hooks completamente
if (Test-Path ".dart_tool\hooks_runner") {
    Write-Host "Eliminando carpeta completa de hooks..." -ForegroundColor Yellow
    takeown /F ".dart_tool\hooks_runner" /R /D Y 2>$null
    icacls ".dart_tool\hooks_runner" /grant "${env:USERNAME}:F" /T 2>$null
    Start-Sleep -Seconds 2
    Remove-Item -Path ".dart_tool\hooks_runner" -Recurse -Force -ErrorAction SilentlyContinue
}

# Limpiar build
if (Test-Path "build") {
    Write-Host "Limpiando carpeta build..." -ForegroundColor Yellow
    Remove-Item -Path "build" -Recurse -Force -ErrorAction SilentlyContinue
}

# Compilar primero
Write-Host "Compilando aplicación..." -ForegroundColor Green
flutter build windows --debug

if ($LASTEXITCODE -eq 0) {
    Write-Host "Compilación exitosa. Ejecutando aplicación..." -ForegroundColor Green
    Start-Process -FilePath "build\windows\x64\runner\Debug\pannar_digital.exe"
} else {
    Write-Host "Error en la compilación. Intentando flutter run..." -ForegroundColor Yellow
    flutter run -d windows
}

