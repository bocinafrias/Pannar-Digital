# Guía para Instalar PANNAR Digital en Otra Computadora

## 📋 Requisitos del Sistema

La computadora destino debe tener:

- **Windows 10 o superior** (64 bits)
- **Visual C++ Redistributable** (se instala automáticamente si falta, pero es mejor tenerlo)
- **Conexión a Internet** (para la primera autenticación con Google)

## 🔨 Paso 1: Compilar la Aplicación

En tu computadora de desarrollo:

> **⚠️ Importante:** Antes de compilar, debes crear un archivo `.env` en la raíz del proyecto con las credenciales de Supabase. Usa `.env.example` como plantilla:
>
> ```
> SUPABASE_URL=https://tu-proyecto.supabase.co
> SUPABASE_ANON_KEY=tu-anon-key-aqui
> ```
>
> Este archivo está en `.gitignore` y nunca debe subirse al repositorio. Los scripts de compilación leen estas variables vía `--dart-define-from-file=.env`.

> **💡 Nota:** Si tienes problemas ejecutando scripts de PowerShell, usa el archivo `COMPILAR.bat` haciendo doble clic sobre él, o ejecuta el comando con bypass (ver más abajo).

### Opción A: Usar el Script Automatizado (Recomendado)

**Si tienes problemas con la ejecución de scripts de PowerShell, usa el archivo `.bat`:**

1. Abre la carpeta del proyecto en el Explorador de Archivos
2. Haz doble clic en `COMPILAR.bat`
3. Responde las preguntas del script
4. Espera a que termine la compilación (3-10 minutos)

**O desde PowerShell (si está habilitado):**

```powershell
.\build_release.ps1
```

**Si PowerShell da error de ejecución de scripts:**

```powershell
# Ejecutar el script con bypass temporal
powershell -ExecutionPolicy Bypass -File .\build_release.ps1
```

### Opción B: Compilación Manual

```powershell
flutter build windows --release --dart-define-from-file=.env
```

**Ubicación del ejecutable:**

```
build\windows\x64\runner\Release\pannar_digital.exe
```

## 📦 Paso 2: Preparar los Archivos para Distribución

### Verificar que el ejecutable existe:

```powershell
Test-Path "build\windows\x64\runner\Release\pannar_digital.exe"
```

### Ver el contenido de la carpeta Release:

```powershell
Get-ChildItem "build\windows\x64\runner\Release" | Select-Object Name, Length
```

**Archivos esenciales que DEBEN estar presentes:**

- ✅ `pannar_digital.exe` (ejecutable principal)
- ✅ `flutter_windows.dll` (biblioteca Flutter)
- ✅ `data/` (carpeta con assets)
- ✅ Varias DLLs adicionales (msvcp140.dll, vcruntime140.dll, etc.)

## 💾 Paso 3: Copiar los Archivos

### Opción 1: USB o Disco Externo (Recomendado)

1. **Conecta un USB o disco externo**
2. **Copia toda la carpeta `Release`:**

   ```powershell
   Copy-Item -Path "build\windows\x64\runner\Release\*" -Destination "E:\PANNAR_Digital\" -Recurse
   ```

   _(Ajusta la ruta `E:\` según tu USB)_

3. **Verifica que se copiaron todos los archivos:**
   ```powershell
   Get-ChildItem "E:\PANNAR_Digital" -Recurse | Measure-Object -Property Length -Sum
   ```

### Opción 2: Comprimir en ZIP

1. **Navega a la carpeta Release:**

   ```powershell
   cd build\windows\x64\runner\Release
   ```

2. **Comprime todo el contenido:**

   ```powershell
   Compress-Archive -Path "*" -DestinationPath "..\..\..\..\..\PANNAR_Digital_v1.0.0.zip" -Force
   ```

3. **Transfiere el archivo ZIP** por:
   - Email (si es pequeño)
   - Google Drive / OneDrive
   - USB
   - Red local

## 🖥️ Paso 4: Instalar en la Otra Computadora

### Método 1: Instalación Directa (Sin Instalador)

1. **Transfiere los archivos** a la computadora destino (USB, red, etc.)

2. **Crea una carpeta** en la computadora destino:

   - Ejemplo: `C:\Programas\PANNAR_Digital\`
   - O en el Escritorio: `C:\Users\[Usuario]\Desktop\PANNAR_Digital\`

3. **Copia todos los archivos** de la carpeta `Release` a la nueva ubicación

4. **Ejecuta la aplicación:**

   - Navega a la carpeta
   - Haz doble clic en `pannar_digital.exe`

5. **Crear acceso directo (Opcional):**
   - Clic derecho en `pannar_digital.exe`
   - Selecciona "Crear acceso directo"
   - Arrastra el acceso directo al Escritorio o al Menú Inicio

### Método 2: Instalación con Instalador (Profesional)

Si quieres crear un instalador profesional, puedes usar:

#### Usando Inno Setup (Gratuito)

1. **Descargar Inno Setup:**

   - URL: https://jrsoftware.org/isinfo.php
   - Instalar en tu computadora de desarrollo

2. **Crear el instalador:**

   - Abre Inno Setup Compiler
   - Usa el asistente (File > New)
   - Configura:
     - **Application name:** PANNAR Digital
     - **Application version:** 1.0.0
     - **Application publisher:** (Tu nombre/organización)
     - **Application website:** (Opcional)
     - **Application destination base folder:** `{pf}\PANNAR_Digital`
     - **Application folder name:** PANNAR_Digital
     - **Allow user to change the application folder:** Sí
     - **Application files:** Selecciona toda la carpeta `Release`
     - **Application icon:** `pannar_digital.exe` (si tiene icono)
     - **Allow user to start the application after Setup:** Sí
     - **Create an uninstaller:** Sí

3. **Compilar el instalador:**

   - Build > Compile
   - El instalador se generará en `Output\`

4. **Distribuir el instalador:**
   - Transfiere el archivo `.exe` del instalador
   - En la computadora destino, ejecuta el instalador
   - Sigue las instrucciones del asistente

## ✅ Paso 5: Verificar la Instalación

En la computadora destino:

1. **Ejecuta la aplicación:**

   - Navega a la carpeta donde copiaste los archivos
   - Haz doble clic en `pannar_digital.exe`

2. **Verifica que:**
   - ✅ La aplicación se abre correctamente
   - ✅ Muestra la pantalla de inicio de sesión
   - ✅ Puedes iniciar sesión con Google
   - ✅ No aparecen errores sobre DLLs faltantes

## 🔧 Solución de Problemas

### Error: "No se puede iniciar la aplicación"

**Causa:** Faltan DLLs o Visual C++ Redistributable

**Solución:**

1. Descarga e instala **Visual C++ Redistributable**:

   - https://aka.ms/vs/17/release/vc_redist.x64.exe
   - O busca "Microsoft Visual C++ Redistributable 2015-2022"

2. Verifica que todos los archivos de la carpeta `Release` estén presentes

### Error: "La aplicación no responde"

**Causa:** Puede ser un problema de permisos o archivos bloqueados

**Solución:**

1. Ejecuta como Administrador (clic derecho > Ejecutar como administrador)
2. Verifica que el antivirus no esté bloqueando la aplicación
3. Agrega una excepción en el antivirus para la carpeta de la aplicación

### Error: "No se puede conectar a Internet"

**Causa:** La aplicación necesita internet para la primera autenticación

**Solución:**

1. Verifica la conexión a internet
2. Asegúrate de que el firewall no esté bloqueando la aplicación
3. Si usas proxy, configura la aplicación para usarlo

### La aplicación no guarda datos

**Causa:** Problemas de permisos de escritura

**Solución:**

1. No instales en `C:\Program Files\` (requiere permisos de administrador)
2. Usa una carpeta en `C:\Users\[Usuario]\` o `C:\Programas\`
3. Asegúrate de que la carpeta tenga permisos de escritura

## 📝 Notas Importantes

### Primera Ejecución

- La primera vez que se ejecuta, la aplicación creará la base de datos local
- Se requiere conexión a internet para la primera autenticación con Google
- Después de la primera autenticación, se puede usar offline con PIN

### Actualizaciones

Para actualizar la aplicación en otra computadora:

1. Compila la nueva versión en tu computadora de desarrollo
2. Copia nuevamente todos los archivos de la carpeta `Release`
3. Reemplaza los archivos en la computadora destino
4. La base de datos local se mantendrá (los datos no se perderán)

### Datos de la Aplicación

Los datos se guardan localmente en:

```
C:\Users\[Usuario]\Documents\Seminario\.dart_tool\sqflite_common_ffi\databases\pannar_digital.db
```

**Para hacer backup:**

- Copia este archivo antes de actualizar
- Restáuralo después de actualizar si es necesario

## 🚀 Resumen Rápido

**Para instalar en otra computadora:**

1. ✅ Compila: `.\build_release.ps1`
2. ✅ Copia toda la carpeta: `build\windows\x64\runner\Release\`
3. ✅ Transfiere a la otra computadora (USB, red, etc.)
4. ✅ Copia los archivos a una carpeta (ej: `C:\Programas\PANNAR_Digital\`)
5. ✅ Ejecuta `pannar_digital.exe`
6. ✅ Crea un acceso directo si lo deseas

**¡Listo! La aplicación está instalada y funcionando.** 🎉
