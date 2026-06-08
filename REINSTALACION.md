# Guía de Reinstalación — Coppola Pavese Inmobiliaria

> **Supuesto**: lo único que tenés guardado es `inmobiliaria.db` (la base de datos con todos los datos reales).
> El código del proyecto lo traés de GitHub (o de un backup del repo).

---

## 🎯 Resumen

| Parte | Qué hace |
|-------|----------|
| **A** | Preparar la PC HOST desde cero (la que comparte la base de datos) |
| **B** | Instalar la app en las otras PCs (no necesitan Flutter) |
| **C** | Qué hacer si la ruta se resetea al reabrir |
| **D** | Checklist final |

---

## A) PC HOST — Desde formato total

### A.1 Instalar herramientas

1. **Git for Windows** → https://git-scm.com/download/win
2. **Flutter SDK** (stable, 3.11+) → https://docs.flutter.dev/get-started/install/windows
   - Descomprimir en `C:\src\flutter`
   - Agregar `C:\src\flutter\bin` al `PATH` del sistema (Variables de entorno)
3. **Visual Studio 2022 Community** → https://visualstudio.microsoft.com/vs/community/
   - Durante la instalación marcar el workload **"Desktop development with C++"**
4. Verificar en una consola nueva:
   ```bat
   flutter doctor
   ```
   Tiene que dar ✅ en: Flutter, Windows (Desktop), Visual Studio.

### A.2 Traer el código

```bat
cd C:\Users\Maxi\Desktop
mkdir dev
cd dev
git clone <url-del-repo-en-GitHub> coppolapavese
cd coppolapavese
flutter pub get
```

### A.3 Restaurar la base de datos

1. Crear la carpeta donde va a vivir la DB. Sugerencia:
   ```
   C:\CoppolaPavese_DB\
   ```
2. Copiar ahí el `inmobiliaria.db` del backup.
3. Compartir la carpeta en red:
   - Click derecho en la carpeta → **Propiedades** → pestaña **Compartir**
   - **Uso compartido avanzado** → ✅ *Compartir esta carpeta*
   - **Permisos** → dar **Lectura y escritura** a los usuarios (o a "Todos" si es red local confiable)
4. Anotar el nombre de red, p.ej.:
   ```
   \\MAXI-PC\CoppolaPavese_DB
   ```

### A.4 Compilar y exportar

Desde la raíz del proyecto:
```bat
exportar_app.bat
```
La primera vez usar:
```bat
exportar_app.bat /clean
```
(hace `flutter clean` + `pub get` + build desde cero)

Esto genera `C:\Users\Maxi\Desktop\CoppolaPavese_App\` con el `coppolapavese.exe` listo para distribuir.

### A.5 Configurar la app en la host

1. Abrir `coppolapavese.exe` (de `build\windows\x64\runner\Release\` o del export).
2. Click en el **engranaje** (arriba a la derecha) → Configuración de red.
3. **Seleccionar carpeta** → apuntar a `C:\CoppolaPavese_DB` (o donde pusiste el `.db`).
4. **Verificar y guardar** → tiene que decir "OK, ruta accesible".
5. Cerrar y abrir la app. Debería abrir con todos los datos del backup.

---

## B) Otras PCs (no host) — Sin Flutter

### B.1 Copiar la app

1. En la PC host corrés `exportar_app.bat`. Se crea `CoppolaPavese_App` en el escritorio.
2. Copiar **toda la carpeta** a la otra PC (USB, red, OneDrive, etc.). Sugerencia:
   ```
   C:\CoppolaPavese\
   ```
3. Click derecho en `coppolapavese.exe` → **Crear acceso directo** → mandarlo al escritorio.

### B.2 Conectar a la carpeta compartida del host

**⚠️ Sin esto la app no ve la base de datos.**

1. Explorador de archivos → en la barra de dirección escribir:
   ```
   \\MAXI-PC\CoppolaPavese_DB
   ```
   (reemplazar `MAXI-PC` por el nombre o IP de la host)
2. Windows pide usuario y contraseña → ✅ marcar **"Recordar mis credenciales"**.
3. **Mapear como unidad de red** (recomendado):
   - Click derecho en *Este equipo* → **Conectar a unidad de red**
   - Letra: `Z:` (o la que prefieras)
   - Carpeta: `\\MAXI-PC\CoppolaPavese_DB`
   - ✅ *Conectar de nuevo al iniciar sesión*
   - ✅ *Conectar con credenciales diferentes* (si hace falta)

### B.3 Configurar la ruta en la app

1. Abrir `coppolapavese.exe`.
2. Click en el **engranaje**.
3. **Seleccionar carpeta** → elegir:
   - Si mapeaste como `Z:` → seleccionar `Z:\`
   - Si no mapeaste → escribir/seleccionar `\\MAXI-PC\CoppolaPavese_DB`
4. **Verificar y guardar** → tiene que decir "OK".
5. Cerrar y abrir la app. La ruta queda guardada en:
   ```
   C:\Users\<usuario>\Documents\CoppolaPavese\db_config.json
   ```

---

## C) Si la ruta se resetea al reabrir (bug conocido en no-host)

Pasos de diagnóstico en orden:

1. **Verificar permisos**: el usuario de Windows debe poder escribir en
   ```
   C:\Users\<usuario>\Documents\CoppolaPavese\
   ```
2. **Verificar el archivo**: abrir con Notepad
   ```
   C:\Users\<usuario>\Documents\CoppolaPavese\db_config.json
   ```
   Debe verse algo así:
   ```json
   {"ruta_bd":"Z:\\","zoom":1.0}
   ```
3. **Si el archivo no existe** al reabrir: el proceso no tiene permisos de escritura → ejecutar la app como Administrador una vez para que lo cree, o moverla a una carpeta sin UAC (`C:\CoppolaPavese\`).
4. **Si el archivo existe pero tiene `"ruta_bd":null`**: borrarlo, reabrir la app y volver a configurar la ruta desde el engranaje.
5. **Si usaste ruta UNC (`\\MAXI-PC\...`)** y se pierde: probar mapeando como unidad de red (`Z:\`) — las rutas mapeadas son más estables entre reinicios.

---

## D) Checklist final

### PC HOST formateada
- [ ] Flutter + Visual Studio + Git instalados
- [ ] `flutter doctor` sin errores
- [ ] Repo clonado de GitHub + `flutter pub get` OK
- [ ] Carpeta `C:\CoppolaPavese_DB` creada y compartida en red con permisos de escritura
- [ ] `inmobiliaria.db` del backup copiado a esa carpeta
- [ ] `exportar_app.bat /clean` corrido sin errores
- [ ] App configurada en el engranaje → apunta a la carpeta local `C:\CoppolaPavese_DB`
- [ ] Los datos históricos aparecen al abrir la app

### Cada PC no host
- [ ] Carpeta `CoppolaPavese_App` copiada desde la host
- [ ] Unidad de red mapeada con "Recordar credenciales"
- [ ] `coppolapavese.exe` abierto al menos una vez
- [ ] Ruta configurada en el engranaje (apuntando al mapeo de red, ej. `Z:\`)
- [ ] `db_config.json` contiene la ruta correcta
- [ ] Al cerrar y reabrir la app, la ruta NO se resetea

---

## 📁 Archivos críticos del proyecto

| Archivo / Carpeta | Qué contiene |
|---|---|
| `inmobiliaria.db` | **LA BASE DE DATOS** — lo único imprescindible de backup |
| `lib/database/db_config.dart` | Lógica de guardado/carga de la ruta de la DB |
| `lib/database/database_helper.dart` | Todas las queries SQL |
| `lib/utils/excel_generator.dart` | Export Excel horizontal + gráfico |
| `lib/utils/pdf_generator.dart` | Generador de recibos PDF |
| `lib/utils/ficha_html_generator.dart` | Fichas HTML de propiedades |
| `exportar_app.bat` | Script para compilar y exportar la app |
| `pubspec.yaml` | Dependencias del proyecto |

---

## 🔑 Datos para reemplazar en esta guía

Cuando reinstales, adaptar según tu setup:

- `MAXI-PC` → nombre real de la PC host en la red
- `C:\CoppolaPavese_DB` → carpeta donde pongas el `.db` en la host
- `<url-del-repo-en-GitHub>` → URL de tu repo privado
- `Z:` → letra que uses para mapear la unidad de red

---

**Última actualización**: Abril 2026 — incluye Excel simplificado con gráfico de barras y print settings para fotocopia.
