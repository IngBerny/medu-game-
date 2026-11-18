#!/usr/bin/env python3
"""
Genera los recursos del juego (sonidos, música e iconos) sin depender de nada externo.

Uso (desde la raíz del proyecto):
    python3 tools/make_assets.py

Requiere: numpy y Pillow  (pip install numpy pillow)
Los archivos generados ya vienen incluidos en el repositorio; este script solo
sirve por si quieres retocar los sonidos o los iconos.
"""
import math
import os
import wave

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

RATE = 22050
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SFX_DIR = os.path.join(ROOT, "assets", "sfx")
MUSIC_DIR = os.path.join(ROOT, "assets", "music")
ICON_DIR = os.path.join(ROOT, "assets", "icons")
for d in (SFX_DIR, MUSIC_DIR, ICON_DIR):
    os.makedirs(d, exist_ok=True)

rng = np.random.default_rng(7)


# --------------------------------------------------------------------------- #
#  Utilidades de audio
# --------------------------------------------------------------------------- #
def save_wav(path, x, peak=0.85):
    x = np.asarray(x, dtype=np.float64)
    m = np.max(np.abs(x))
    if m > 0:
        x = x / m * peak
    data = (np.clip(x, -1, 1) * 32767).astype("<i2")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(data.tobytes())


def t_axis(dur):
    return np.arange(int(dur * RATE)) / RATE


def sweep_phase(f0, f1, dur):
    """Fase acumulada de un barrido de frecuencia (exponencial)."""
    t = t_axis(dur)
    f = f0 * (f1 / f0) ** (t / dur)
    return 2 * np.pi * np.cumsum(f) / RATE


def env_exp(dur, attack=0.004, decay=6.0):
    t = t_axis(dur)
    a = np.minimum(1.0, t / max(attack, 1e-6))
    return a * np.exp(-decay * t / dur)


def lowpass_noise(dur, width=8):
    n = rng.normal(0, 1, int(dur * RATE))
    k = np.ones(width) / width
    return np.convolve(n, k, mode="same")


def sfx_dash():
    dur = 0.2
    noise = lowpass_noise(dur, 5) * env_exp(dur, 0.01, 4.0)
    tone = np.sin(sweep_phase(900, 260, dur)) * env_exp(dur, 0.003, 7.0)
    return 0.7 * noise + 0.5 * tone


def sfx_zap():
    dur = 0.42
    t = t_axis(dur)
    ph = sweep_phase(780, 110, dur)
    sq = np.sign(np.sin(ph)) * 0.6 + np.sin(ph * 2.01) * 0.3
    am = 1 + 0.6 * np.sin(2 * np.pi * 55 * t)
    crackle = rng.normal(0, 1, len(t)) * (rng.random(len(t)) > 0.93)
    return (sq * am + 0.9 * crackle) * env_exp(dur, 0.002, 3.2)


def sfx_pop():
    dur = 0.16
    tone = np.sin(sweep_phase(380, 1100, dur)) * env_exp(dur, 0.002, 7.0)
    click = lowpass_noise(dur, 3) * env_exp(dur, 0.001, 18.0)
    return 0.8 * tone + 0.4 * click


def sfx_hit():
    dur = 0.45
    thud = np.sin(sweep_phase(240, 55, dur)) * env_exp(dur, 0.002, 4.5)
    crunch = lowpass_noise(dur, 6) * env_exp(dur, 0.001, 6.5)
    return 0.9 * thud + 0.7 * crunch


def note(freq, dur, decay=4.0):
    t = t_axis(dur)
    s = np.sin(2 * np.pi * freq * t) + 0.35 * np.sin(2 * np.pi * freq * 2 * t)
    return s * env_exp(dur, 0.005, decay)


def sfx_gameover():
    parts = [note(f, 0.26, 3.0) for f in (392.0, 329.6, 261.6, 174.6)]
    tail = note(130.8, 0.6, 5.0)
    return np.concatenate(parts + [tail])


def sfx_start():
    parts = [note(f, 0.1, 3.0) for f in (330.0, 440.0, 660.0)]
    return np.concatenate(parts + [note(880.0, 0.2, 5.0)])


def sfx_click():
    dur = 0.06
    return np.sin(2 * np.pi * 760 * t_axis(dur)) * env_exp(dur, 0.001, 9.0)


def sfx_heal():
    parts = [note(f, 0.09, 4.0) for f in (523.3, 659.3, 784.0, 1046.5)]
    return np.concatenate(parts)


# --------------------------------------------------------------------------- #
#  Música ambiental (bucle perfecto de 12 s)
# --------------------------------------------------------------------------- #
def make_music():
    dur = 12.0
    n = int(dur * RATE)
    t = np.arange(n) / RATE
    # Acordes: Am - Fmaj7 - C - G (3 s cada uno)
    chords = [
        [110.0, 220.0, 261.63, 329.63, 440.0],
        [87.31, 174.61, 220.0, 261.63, 329.63],
        [130.81, 196.0, 261.63, 329.63, 392.0],
        [98.0, 196.0, 246.94, 293.66, 392.0],
    ]
    out = np.zeros(n)
    for i, notes in enumerate(chords):
        center = 1.5 + 3.0 * i
        d = (t - center + dur / 2) % dur - dur / 2        # distancia circular
        w = np.where(np.abs(d) < 3.0, np.cos(np.pi * d / 6.0) ** 2, 0.0)
        for f in notes:
            fq = round(f * 12) / 12                        # ciclos enteros en 12 s
            out += w * 0.16 * (np.sin(2 * np.pi * fq * t)
                               + np.sin(2 * np.pi * (fq + 1 / 12) * t)) / 2
            out += w * 0.04 * np.sin(2 * np.pi * (fq * 2) * t)
    out += 0.10 * np.sin(2 * np.pi * 55.0 * t)             # drone grave
    out *= 1 + 0.08 * np.sin(2 * np.pi * (1 / 3) * t)       # respiración lenta
    # Burbujitas (plinks) que no cruzan el punto de unión del bucle
    for start in (0.7, 2.4, 4.1, 5.0, 6.9, 8.3, 9.6, 10.8):
        f = rng.choice([880.0, 988.0, 1174.7, 1318.5, 1568.0])
        m = int(0.5 * RATE)
        tt = np.arange(m) / RATE
        ping = np.sin(2 * np.pi * f * tt) * np.exp(-9 * tt) * 0.06
        s = int(start * RATE)
        out[s:s + m] += ping[: n - s]
    save_wav(os.path.join(MUSIC_DIR, "ambient.wav"), out, peak=0.7)


# --------------------------------------------------------------------------- #
#  Iconos
# --------------------------------------------------------------------------- #
SS = 4  # supersampling


def gradient(size, top, bottom):
    arr = np.zeros((size, size, 4), dtype=np.uint8)
    for y in range(size):
        k = y / (size - 1)
        arr[y, :, 0] = int(top[0] * (1 - k) + bottom[0] * k)
        arr[y, :, 1] = int(top[1] * (1 - k) + bottom[1] * k)
        arr[y, :, 2] = int(top[2] * (1 - k) + bottom[2] * k)
        arr[y, :, 3] = 255
    return Image.fromarray(arr, "RGBA")


def jellyfish_layer(size, scale=1.0, mono=False):
    """Dibuja la medusa sobre una capa transparente de size x size."""
    s = size * SS
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    cx, cy = s / 2, s * 0.44
    r = s * 0.27 * scale
    body = (255, 255, 255, 255) if mono else (245, 120, 235, 255)
    glow = (255, 255, 255, 255) if mono else (255, 190, 250, 255)
    tent = (255, 255, 255, 255) if mono else (250, 150, 240, 255)
    # tentáculos
    for i, off in enumerate((-0.62, -0.31, 0.0, 0.31, 0.62)):
        pts = []
        for k in range(0, 21):
            u = k / 20
            x = cx + off * r + math.sin(u * 5.0 + i) * r * 0.10
            y = cy + r * 0.25 + u * r * (1.5 - 0.15 * abs(off))
            pts.append((x, y))
        d.line(pts, fill=tent, width=max(2, int(r * 0.11)), joint="curve")
    # domo
    d.pieslice([cx - r, cy - r, cx + r, cy + r], 180, 360, fill=body)
    d.ellipse([cx - r, cy - r * 0.18, cx + r, cy + r * 0.34], fill=body)
    if not mono:
        d.ellipse([cx - r * 0.55, cy - r * 0.82, cx - r * 0.05, cy - r * 0.42], fill=glow)
        # ojitos
        for ex in (-0.28, 0.28):
            d.ellipse([cx + ex * r - r * 0.11, cy - r * 0.05 - r * 0.11,
                       cx + ex * r + r * 0.11, cy - r * 0.05 + r * 0.11], fill=(40, 20, 70, 255))
            d.ellipse([cx + ex * r - r * 0.04, cy - r * 0.05 - r * 0.07,
                       cx + ex * r + r * 0.02, cy - r * 0.05 - r * 0.01], fill=(255, 255, 255, 255))
    img = img.resize((size, size), Image.LANCZOS)
    return img


def rounded_mask(size, radius):
    m = Image.new("L", (size * SS, size * SS), 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, size * SS - 1, size * SS - 1], radius * SS, fill=255)
    return m.resize((size, size), Image.LANCZOS)


def make_icons():
    top, bottom = (24, 120, 170), (4, 24, 70)
    # Icono clásico 192
    bg = gradient(192, top, bottom)
    fg = jellyfish_layer(192, 1.0)
    bg.alpha_composite(fg)
    bg.putalpha(rounded_mask(192, 38))
    bg.save(os.path.join(ICON_DIR, "icon_192.png"))
    # Adaptativo 432 (zona segura central ~66 %)
    gradient(432, top, bottom).save(os.path.join(ICON_DIR, "adaptive_background_432.png"))
    jellyfish_layer(432, 0.78).save(os.path.join(ICON_DIR, "adaptive_foreground_432.png"))
    jellyfish_layer(432, 0.78, mono=True).save(os.path.join(ICON_DIR, "adaptive_monochrome_432.png"))
    # Vista previa grande (no se usa en el juego)
    prev = gradient(512, top, bottom)
    prev.alpha_composite(jellyfish_layer(512, 1.0))
    prev.putalpha(rounded_mask(512, 100))
    prev.save(os.path.join(ICON_DIR, "preview_512.png"))


def main():
    sfx = {
        "dash": sfx_dash(), "zap": sfx_zap(), "pop": sfx_pop(), "hit": sfx_hit(),
        "gameover": sfx_gameover(), "start": sfx_start(), "click": sfx_click(), "heal": sfx_heal(),
    }
    for name, data in sfx.items():
        save_wav(os.path.join(SFX_DIR, name + ".wav"), data)
        print("sfx", name, f"{len(data) / RATE:.2f}s")
    make_music()
    print("música ambient.wav 12.00s")
    make_icons()
    print("iconos listos")


if __name__ == "__main__":
    main()
