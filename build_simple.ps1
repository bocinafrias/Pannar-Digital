# Compilación simple sin hooks
Write-Host "=== Compilación sin hooks ===" -ForegroundColor Cyan

# Detener procesos
Get-Process | Where-Object {$_.ProcessName -like "*dart*" -or $_.ProcessName -like "*flutter*"} | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2

# Deshabilitar hooks completamente
$env:DART_PUB_SKIP_HOOKS = "true"
$env:FLUTTER_BUILD_MODE = "debug"

# Limpiar hooks_runner
if (Test-Path ".dart_tool\hooks_runner") {
    Remove-Item -Path ".dart_tool\hooks_runner" -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host "Compilando con hooks deshabilitados..." -ForegroundColor Green

# Intentar compilar directamente sin pasar por pub get
flutter build windows --debug --no-pub

if ($LASTEXITCODE -ne 0) {
    Write-Host "Falló con --no-pub, intentando normal..." -ForegroundColor Yellow
    flutter build windows --debug
}

if ($LASTEXITCODE -eq 0) {
    Write-Host "`n=== Compilación exitosa ===" -ForegroundColor Green
    Start-Process -FilePath "build\windows\x64\runner\Debug\pannar_digital.exe"
}






