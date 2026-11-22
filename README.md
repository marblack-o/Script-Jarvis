# Script-Jarvis

Asistente J.A.R.V.I.S. para Roblox.

## Ejecutar

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/marblack-o/Script-Jarvis/main/loader-allinone.lua"))()
```

## Notas

- Requiere executor con `HttpGet` y `loadstring`.
- Usa Groq API key local.
- Si Project UAI está disponible en el entorno, se conecta automáticamente.
- Si UAI no está disponible, usa NativeBridge como fallback.
