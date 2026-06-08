# 🏢 Coppola Pavese — Setup de red compartida

Guía paso a paso para instalar la app en la **PC host** (la que tiene la base de datos)
y en las **PCs no-host** (las que acceden a la base por red).

> **Punto de partida:** llegás con un pendrive que contiene la app empaquetada
> en `.rar` (la versión actualizada compilada con `flutter build windows --release`).
> Ninguna PC tiene la app instalada todavía.

---

## 📋 Glosario rápido

| Término | Significado |
|---------|-------------|
| **PC host** | La única PC donde vive físicamente el archivo `inmobiliaria.db`. Se comparte por red. |
| **PC no-host** | Cualquier otra PC de la oficina que usa la app. Accede a la base por red. |
| **Share name** | El nombre público del recurso compartido. Distinto de la ruta local de la carpeta. |
| **UNC** | Formato de ruta de red tipo `\\PC\Recurso`. Es lo que entiende Windows en la LAN. |
| **IP fija** | La dirección 192.168.x.x de la PC host reservada para que no cambie. |

---

# 🟦 PARTE A — PC HOST

Esto se hace **una sola vez** en la PC donde va a vivir la base de datos.

## A1. Preparar la carpeta y poner la base de datos

1. Abrir el Explorador de archivos → ir a `C:\Users\Inmobiliaria\Documents`.
2. Crear una carpeta llamada **`CoppolaPavese`** (clic derecho → Nuevo → Carpeta).
3. Copiar el archivo **`inmobiliaria.db`** (desde tu backup) dentro de esa carpeta.
   - Si todavía no tenés `inmobiliaria.db` porque es instalación nueva, dejá la
     carpeta vacía. La app la creará automáticamente al primer uso.

**Ruta final de la base en la PC host:**
```
C:\Users\Inmobiliaria\Documents\CoppolaPavese\inmobiliaria.db
```

## A2. Instalar la app en la PC host

1. Enchufar el pendrive.
2. Copiar el `.rar` con la app a `C:\Users\Inmobiliaria\Desktop\` (o donde quieras).
3. Clic derecho al `.rar` → **Extraer aquí** (con WinRAR o 7-Zip).
4. Renombrar la carpeta extraída a **`CoppolaPavese-App`** (para no confundir con
   la carpeta de la base).
5. Dentro de esa carpeta, hacer clic derecho al ejecutable `coppolapavese.exe` →
   **Enviar a** → **Escritorio (crear acceso directo)**.

> 📌 **IMPORTANTE:** La carpeta de la APP (`CoppolaPavese-App`) y la carpeta de la
> BASE (`CoppolaPavese`) son **distintas**. La app va en Desktop o donde quieras;
> la base va en `Documents\CoppolaPavese` porque ESA es la que vamos a compartir.

## A3. Configurar IP fija (recomendado)

Para que las PCs no-host siempre encuentren a la host con la misma dirección:

1. Clic derecho en el ícono de red (esquina inferior derecha) → **Configuración
   de red e Internet**.
2. **Cambiar propiedades de conexión** → tomar nota de la IP actual
   (algo como `192.168.1.23` o `192.168.100.68`).
3. Opción más fácil: entrar al router (normalmente `192.168.1.1` o `192.168.0.1`
   en el navegador) → sección **DHCP** → **Reserva de IP** → asignar esa IP a la
   MAC address de la PC host.
4. Si no podés meterte al router, configurarla fija directamente en Windows:
   - Panel de control → Red e Internet → Centro de redes y recursos compartidos →
     **Cambiar configuración del adaptador**.
   - Clic derecho en la conexión (Ethernet o Wi-Fi) → Propiedades → doble clic en
     **Protocolo de Internet versión 4 (TCP/IPv4)**.
   - Marcar **Usar la siguiente dirección IP** y poner:
     - IP: la misma que tiene ahora (ej. `192.168.1.23`)
     - Máscara: `255.255.255.0`
     - Puerta de enlace: la IP del router (ej. `192.168.1.1`)
     - DNS preferido: `8.8.8.8`  |  DNS alternativo: `8.8.4.4`

## A4. Verificar el nombre del equipo

1. Win + Pausa (o clic derecho en "Este equipo" → Propiedades).
2. Anotar el **Nombre del equipo**. Debería ser algo como `DESKTOP-HQIB8B4`.
3. Te va a hacer falta más adelante para las PCs no-host.

## A5. Configurar la red como "Privada"

1. Configuración → Red e Internet → Estado → Propiedades de la conexión activa.
2. En **Perfil de red** elegir **Privada** (NO Pública).
   - Sin esto, Windows bloquea el uso compartido de archivos.

## A6. Activar uso compartido de archivos

1. Panel de control → Red e Internet → Centro de redes y recursos compartidos →
   **Cambiar configuración de uso compartido avanzado**.
2. En el perfil **Privado** (expandido):
   - ✅ Activar la detección de redes.
   - ✅ Activar el uso compartido de archivos e impresoras.
3. En **Todas las redes** (expandido):
   - ✅ Activar uso compartido para que cualquiera con acceso de red pueda leer
     y escribir archivos en las carpetas públicas.
   - **Uso compartido con protección por contraseña:**
     - Si **SÍ** querés contraseña (más seguro): dejalo activado → las PCs no-host
       van a pedir usuario/contraseña de Windows de la host la primera vez
       (marcar "Recordar credenciales").
     - Si **NO** querés contraseña (más práctico en una oficina): desactivalo.
4. Guardar cambios.

## A7. Compartir la carpeta de la base de datos

1. Ir a `C:\Users\Inmobiliaria\Documents\`.
2. Clic derecho en la carpeta **`CoppolaPavese`** → **Propiedades**.
3. Pestaña **Compartir** → botón **Uso compartido avanzado...**
4. ✅ Tildar **Compartir esta carpeta**.
5. **Nombre del recurso compartido:** dejar `CoppolaPavese` (importante: este es
   el nombre que van a usar las PCs no-host).
6. Click en **Permisos** → seleccionar **Todos** → tildar **Control total**
   (lectura y escritura). Aceptar.
7. Volver a la pestaña **Seguridad** de la carpeta → botón **Editar** → **Agregar**
   → escribir `Todos` → Aceptar → darle **Control total**. Aceptar.
8. En la misma pestaña **Compartir** de Propiedades, anotar la **Ruta de red** que
   te muestra Windows. Debería ser algo como:
   ```
   \\DESKTOP-HQIB8B4\CoppolaPavese
   ```
   Esa es **la ruta que van a usar las PCs no-host**.

## A8. Abrir el firewall para SMB (si hace falta)

Si después de todo esto las PCs no-host no pueden acceder:

1. Configuración → Privacidad y seguridad → Seguridad de Windows → **Firewall y
   protección de red** → **Permitir una aplicación a través del firewall**.
2. Buscar **Uso compartido de archivos e impresoras** → tildar **Privada**.
3. Aceptar.

## A9. Abrir la app y apuntar a la base local

1. Abrir la app (`coppolapavese.exe`).
2. Clic en el **engranaje** (configuración).
3. En la ruta de la base poner exactamente:
   ```
   C:\Users\Inmobiliaria\Documents\CoppolaPavese
   ```
   (ruta local, sin `\\`, porque la host accede a su propio disco).
4. Guardar. La app debería cargar los datos y funcionar normalmente.

## A10. Checklist final de la PC host

- [ ] Archivo `inmobiliaria.db` en `C:\Users\Inmobiliaria\Documents\CoppolaPavese\`.
- [ ] App extraída del `.rar` y funcionando desde el acceso directo del escritorio.
- [ ] Carpeta compartida con nombre **`CoppolaPavese`** y Control total para Todos.
- [ ] Red marcada como **Privada**.
- [ ] Uso compartido de archivos activado.
- [ ] Firewall permite SMB.
- [ ] IP fija reservada en el router (o configurada manualmente).
- [ ] Ruta UNC anotada: `\\NOMBRE-PC\CoppolaPavese`.
- [ ] App funciona y muestra los datos.

---

# 🟩 PARTE B — PC NO-HOST

Esto se hace en **cada una** de las otras PCs de la oficina.
Antes de empezar, asegurate de que **la PC host ya esté encendida y en la red**.

## B1. Test previo de conectividad

Antes de instalar nada, verificar que la PC no-host llega a la host:

1. Win + R → escribir `cmd` → Enter.
2. Ejecutar:
   ```
   ping DESKTOP-HQIB8B4
   ```
   (reemplazar por el nombre real de la PC host).
3. Si responde, genial. Si no responde, probar con la IP:
   ```
   ping 192.168.1.23
   ```
4. Si tampoco responde con IP, el problema es de red (cable, Wi-Fi, firewall) —
   resolverlo antes de seguir.

## B2. Probar el acceso a la carpeta compartida

1. Explorador de archivos → barra de direcciones → pegar:
   ```
   \\DESKTOP-HQIB8B4\CoppolaPavese
   ```
   (usar el nombre real de la PC host).
2. Presionar Enter.
3. Posibles resultados:
   - **Ves el archivo `inmobiliaria.db` dentro** → ✅ funciona, seguí a B3.
   - **Pide usuario y contraseña** → poner las credenciales de Windows de la PC
     host, tildar **Recordar mis credenciales**, Aceptar.
   - **Error "No se encontró la ruta"** → probar con IP:
     ```
     \\192.168.1.23\CoppolaPavese
     ```
   - **Con IP tampoco funciona** → volver a la PC host y revisar los pasos A5, A6,
     A7 y A8.

## B3. Instalar la app en la PC no-host

1. Enchufar el pendrive con el `.rar`.
2. Copiar el `.rar` al escritorio (o a `C:\Program Files\`).
3. Clic derecho → **Extraer aquí**.
4. Renombrar la carpeta a **`CoppolaPavese-App`**.
5. Crear acceso directo de `coppolapavese.exe` al escritorio.

> ⚠️ En la PC no-host **NO se crea** ninguna carpeta `CoppolaPavese` en Documents.
> La base vive sólo en la host. Acá la app sólo consume la base por red.

## B4. Primera apertura y configuración de la ruta

1. Abrir la app desde el acceso directo.
2. Clic en el **engranaje** (configuración).
3. En el campo de la ruta de la base poner **la ruta UNC**:
   ```
   \\DESKTOP-HQIB8B4\CoppolaPavese
   ```
   (reemplazando por el nombre real de tu PC host).
4. **Alternativa con IP** (usar sólo si el nombre no funciona):
   ```
   \\192.168.1.23\CoppolaPavese
   ```
5. Guardar.
6. La app debería cargar inmediatamente los mismos datos que ves en la host.

### ¿Nombre o IP? — recomendación

| Opción | Cuándo usarla | Pro | Contra |
|--------|---------------|-----|--------|
| Nombre (`\\DESKTOP-HQIB8B4\CoppolaPavese`) | Default, probá siempre primero | No se rompe si cambia la IP | A veces NetBIOS/mDNS no resuelve en algunas redes |
| IP (`\\192.168.1.23\CoppolaPavese`) | Fallback si el nombre no resuelve | Funciona aunque falle la resolución de nombres | Si la IP cambia, se rompe (por eso usamos IP fija en A3) |

## B5. Checklist final de cada PC no-host

- [ ] Ping a la host funciona (por nombre o IP).
- [ ] La carpeta `\\HOST\CoppolaPavese` abre desde el Explorador y se ve el `.db`.
- [ ] App extraída del `.rar` y accesible desde el escritorio.
- [ ] Ruta UNC configurada en el engranaje.
- [ ] Credenciales de la host guardadas (si pidió contraseña).
- [ ] La app carga los mismos datos que la host.

---

# 🧪 PARTE C — Test de estabilidad (importante)

Para confirmar que **nada se va a desconfigurar al apagar/prender las PCs**,
hacé este test una vez después de dejar todo configurado:

1. Cerrar la app en todas las PCs.
2. Apagar todas las PCs.
3. Encender **primero la PC host**, esperar 30 segundos a que termine de arrancar.
4. Encender una PC no-host.
5. Abrir la app en la PC no-host → debería cargar los datos sin pedir configurar
   nada de nuevo.
6. Repetir el ciclo 2–3 veces.

Si funciona sin pedir reconfigurar la ruta, **la configuración es estable** y ya
está lista para el uso diario.

---

# 🚨 PARTE D — Solución de problemas comunes

## "La app me pide reconfigurar la ruta cada vez que abro"

Ese era un bug de `SharedPreferences` que ya se arregló en esta versión. Si
vuelve a pasar:

1. Cerrar la app.
2. Ir a `%APPDATA%\coppolapavese\` (copiar y pegar en Explorador).
3. Borrar los archivos de preferencias.
4. Abrir de nuevo y configurar la ruta.

## "No encuentra la ruta de red"

1. ¿Está encendida la PC host?
2. Desde la no-host, ¿`ping NOMBRE-HOST` responde?
3. ¿El Explorador abre `\\NOMBRE-HOST\CoppolaPavese`?
4. Si el nombre no resuelve, probar con IP. Si la IP no responde, revisar
   firewall y perfil de red (privada vs pública) en la host.

## "La IP de la host cambió"

Pasa si el router da IPs por DHCP sin reserva. Soluciones:

- Reservar la IP en el router (A3, paso 3).
- O cambiar la ruta en el engranaje de la no-host para que apunte al nombre de
  equipo en lugar de la IP.

## "La PC host está apagada y la app de la no-host no abre"

Normal. La base vive en la host. Si la host no está en la red, la no-host no
puede trabajar. Encender la host y volver a intentar.

## "Pide usuario y contraseña y no me los acepta"

- Usar las credenciales de Windows **de la PC host**, no las de la PC no-host.
- Formato: `NOMBRE-HOST\usuario` (ej. `DESKTOP-HQIB8B4\Inmobiliaria`).
- Si no sabés la contraseña de Windows de la host, en la host: Configuración →
  Cuentas → Opciones de inicio de sesión → Contraseña.
- Alternativa: desactivar el uso compartido con protección por contraseña
  (paso A6, punto 3).

---

# 📦 PARTE E — Resumen visual

```
┌─────────────────────────────────────────────────────────┐
│  PC HOST — DESKTOP-HQIB8B4 (IP fija: 192.168.1.23)       │
│                                                          │
│  C:\Users\Inmobiliaria\Documents\                        │
│  └── CoppolaPavese\        ← carpeta compartida          │
│       └── inmobiliaria.db                                │
│                                                          │
│  C:\Users\Inmobiliaria\Desktop\                          │
│  └── CoppolaPavese-App\    ← la app extraída del .rar    │
│       └── coppolapavese.exe                              │
│                                                          │
│  Engranaje → ruta: C:\Users\Inmobiliaria\Documents\      │
│                    CoppolaPavese                         │
└──────────────────────────┬──────────────────────────────┘
                           │
                           │  red LAN
                           │
           ┌───────────────┴────────────────┐
           │                                │
           ▼                                ▼
┌───────────────────────┐        ┌───────────────────────┐
│  PC NO-HOST 1         │        │  PC NO-HOST 2         │
│                       │        │                       │
│  Desktop\             │        │  Desktop\             │
│  └── CoppolaPavese-   │        │  └── CoppolaPavese-   │
│      App\             │        │      App\             │
│      └── ...exe       │        │      └── ...exe       │
│                       │        │                       │
│  Engranaje:           │        │  Engranaje:           │
│  \\DESKTOP-HQIB8B4\   │        │  \\DESKTOP-HQIB8B4\   │
│  CoppolaPavese        │        │  CoppolaPavese        │
└───────────────────────┘        └───────────────────────┘
```

---

**Tip final:** dejá esta guía guardada en el pendrive junto con el `.rar` de la
app. Si en algún momento hay que reinstalar todo (formateo, PC nueva, etc.),
seguir estos mismos pasos te deja operativo en 20–30 minutos.
