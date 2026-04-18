@echo off
echo ========================================
echo Compilando PANNAR Digital (Release)
echo ========================================
echo.

REM Verificar que estamos en el directorio correcto
if not exist "pubspec.yaml" (
    echo Error: No se encuentra pubspec.yaml. Ejecuta este script desde la raiz del proyecto.
    pause
    exit /b 1
)

REM Verificar que existe el archivo .env con las credenciales de Supabase
if not exist ".env" (
    echo Error: No se encuentra el archivo .env con las credenciales de Supabase.
    echo Copia .env.example a .env y completalo con tus credenciales.
    pause
    exit /b 1
)

REM Limpiar builds anteriores (opcional)
set /p limpiar="Deseas limpiar builds anteriores? (S/N): "
if /i "%limpiar%"=="S" (
    echo Limpiando builds anteriores...
    flutter clean
    echo.
)

REM Obtener dependencias
echo Obteniendo dependencias...
flutter pub get
if errorlevel 1 (
    echo Error al obtener dependencias
    pause
    exit /b 1
)
echo.

REM Compilar en modo release
echo Compilando en modo RELEASE...
echo Esto puede tardar varios minutos...
flutter build windows --release --dart-define-from-file=.env

if errorlevel 1 (
    echo.
    echo ========================================
    echo Error en la compilacion
    echo ========================================
    echo Revisa los mensajes de error anteriores
    pause
    exit /b 1
)

echo.
echo ========================================
echo Compilacion exitosa!
echo ========================================
echo.

if exist "build\windows\x64\runner\Release\pannar_digital.exe" (
    echo Ejecutable generado en:
    echo   build\windows\x64\runner\Release\pannar_digital.exe
    echo.
    echo Para distribuir la aplicacion, copia toda la carpeta:
    echo   build\windows\x64\runner\Release\
    echo.
    set /p abrir="Deseas abrir la carpeta del ejecutable? (S/N): "
    if /i "%abrir%"=="S" (
        start explorer.exe "build\windows\x64\runner\Release"
    )
) else (
    echo Advertencia: No se encontro el ejecutable en la ruta esperada
)

pause

