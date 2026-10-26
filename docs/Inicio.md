# Coppola Pavese — Inicio

Bóveda de Obsidian del proyecto (la carpeta `C:\dev\cp` completa). Las notas son
archivos `.md` comunes: las leés y editás acá, y Claude Code las lee desde la terminal.

- [[guia-completa]] — **empezar acá**: dejar la red, la auto-actualización y el acceso remoto andando, y qué hacer si algo falla
- [[reglas-de-negocio]] — cuotas, "Va por", períodos fijos, prórrogas y textos del pie del recibo
- [[red-compartida]] — detalle técnico de la red: scripts, diagnóstico, problemas típicos
- [[bitacora]] — qué se hizo en cada sesión y qué falta
- [Instalación y actualización](../INSTALACION_Y_ACTUALIZACION.md) — guía completa de instalación
- [CLAUDE.md](../CLAUDE.md) — el resumen que Claude lee al empezar cada sesión

## Cómo trabajar con Claude Code desde la terminal

```powershell
cd C:\dev\cp
claude
```

- Claude lee `CLAUDE.md` solo al arrancar. Ahí está el resumen y a qué nota ir por tema.
- Para un tema puntual: *"leé docs/red-compartida.md y …"*. Lee solo esa nota y no gasta
  tokens releyendo todo el código.
- Al cerrar: *"agregá a docs/bitacora.md lo que hicimos hoy"*.
- Entre tareas que no tienen que ver, `/clear` (arranca de cero, con `CLAUDE.md` igual).
  Si una conversación se hace larga, `/compact` la resume.
