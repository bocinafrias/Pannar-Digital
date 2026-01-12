# Script para compilar el ejecutable de release de la aplicación Windows
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Compilando PANNAR Digital (Release)" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Verificar que estamos en el directorio correcto
if (-not (Test-Path "pubspec.yaml")) {
    Write-Host "Error: No se encuentra pubspec.yaml. Ejecuta este script desde la raíz del proyecto." -ForegroundColor Red
    exit 1
}

# Limpiar builds anteriores (opcional, comentar si no quieres limpiar)
$limpiar = Read-Host "¿Deseas limpiar builds anteriores? (S/N)"
if ($limpiar -eq "S" -or $limpiar -eq "s") {
    Write-Host "Limpiando builds anteriores..." -ForegroundColor Yellow
    flutter clean
    Write-Host ""
}

# Obtener dependencias
Write-Host "Obteniendo dependencias..." -ForegroundColor Green
flutter pub get
if ($LASTEXITCODE -ne 0) {
    Write-Host "Error al obtener dependencias" -ForegroundColor Red
    exit 1
}
Write-Host ""

# Compilar en modo release
Write-Host "Compilando en modo RELEASE..." -ForegroundColor Green
Write-Host "Esto puede tardar varios minutos..." -ForegroundColor Yellow
flutter build windows --release

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "¡Compilación exitosa!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    
    $exePath = "build\windows\x64\runner\Release\pannar_digital.exe"
    if (Test-Path $exePath) {
        $fileInfo = Get-Item $exePath
        $sizeMB = [math]::Round($fileInfo.Length / 1MB, 2)
        
        Write-Host "Ejecutable generado:" -ForegroundColor Cyan
        Write-Host "  Ubicación: $exePath" -ForegroundColor White
        Write-Host "  Tamaño: $sizeMB MB" -ForegroundColor White
        Write-Host ""
        Write-Host "Para distribuir la aplicación, copia toda la carpeta:" -ForegroundColor Yellow
        Write-Host "  build\windows\x64\runner\Release\" -ForegroundColor White
        Write-Host ""
        
        $abrir = Read-Host "¿Deseas abrir la carpeta del ejecutable? (S/N)"
        if ($abrir -eq "S" -or $abrir -eq "s") {
            Start-Process "explorer.exe" -ArgumentList (Resolve-Path "build\windows\x64\runner\Release").Path
        }
    } else {
        Write-Host "Advertencia: No se encontró el ejecutable en la ruta esperada" -ForegroundColor Yellow
    }
} else {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Red
    Write-Host "Error en la compilación" -ForegroundColor Red
    Write-Host "========================================" -ForegroundColor Red
    Write-Host "Revisa los mensajes de error anteriores" -ForegroundColor Yellow
    exit 1
}







