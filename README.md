# El ataque del medu

Juego infinito submarino para Android (Godot 4.7, GDScript). Controlas a una medusa: esquiva basura, minas, peces y rocas, y destruye con descargas eléctricas.

## Instalar en el teléfono (sin instalar nada en la PC)
1. En GitHub abre **Releases** → **El ataque del medu (APK)** → descarga `medu.apk` desde el teléfono.
2. Ábrelo e instala (permite "orígenes desconocidos" si lo pide).

El APK se compila solo en GitHub Actions cada vez que se hace push a `main`.

## Controles
- **Mantener el dedo en la pantalla**: subir. Soltar: hundirse suave.
- **Botón rayo**: descarga frontal (destruye basura y peces) · recarga 0.5 s.
- **Botón onda**: descarga circular (destruye además minas) · recarga ~3 s.
- Botón pausa arriba a la derecha; el botón "atrás" también pausa.
- PC: espacio/↑ subir, X ataque, C onda, Esc pausa (el mouse también funciona como dedo).

## Reglas
3 corazones; cada golpe quita uno (1.3 s de invulnerabilidad). Corazones rosados curan.
Puntos: +10/s sobrevivido, +10 basura, +25 pez, +40 mina. Récord guardado en el teléfono.
La velocidad y la frecuencia de obstáculos suben durante 150 s hasta el máximo.

## Estructura
- `scripts/game_manager.gd` (autoload): estado, vidas, puntos, dificultad, guardado.
- `scripts/player.gd`, `obstacle.gd`, `obstacle_spawner.gd` (object pooling de 28 obstáculos), `effects.gd` (partículas en buffer circular), `background.gd`, `touch_controls.gd`, `ui.gd`, `main.gd`.
- `scripts/autotest.gd`: bot de prueba para CI (`godot --headless --fixed-fps 60 -- --autotest`).
- `tools/make_assets.py`: regenera sonidos, música e iconos.

## Rendimiento
Sin texturas (todo con `_draw`), un solo bucle para obstáculos, pool fijo, partículas sin asignaciones, renderer GL Compatibility, 60 FPS.
