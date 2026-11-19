#!/usr/bin/env python3
"""Makes the seven nudge sounds (chime, bell, marimba, pop, rise, knock, louder) as .caf files in
App/Resources/Sounds/. Standard library only (wave, math) + macOS's afconvert.  Run: python3 Tools/make-sounds.py"""
import math, os, struct, subprocess, tempfile, wave

RATE = 44100
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "App", "Resources", "Sounds")

def note(freq, dur, amp=0.5, decay=4.0, partials=((1, 1.0),), attack=0.005, start=0.0, total=None):
    """One plucked/struck tone: summed partials with an exponential decay."""
    n = int(RATE * (total if total else start + dur))
    buf = [0.0] * n
    s0 = int(start * RATE)
    for i in range(int(dur * RATE)):
        if s0 + i >= n: break
        t = i / RATE
        env = min(1.0, t / attack) * math.exp(-decay * t)
        v = sum(a * math.sin(2 * math.pi * freq * mult * t) for mult, a in partials)
        buf[s0 + i] += amp * env * v
    return buf

def mix(*tracks):
    n = max(len(t) for t in tracks)
    out = [0.0] * n
    for t in tracks:
        for i, v in enumerate(t): out[i] += v
    return out

def fade_end(buf, secs=0.08):
    k = int(secs * RATE)
    for i in range(min(k, len(buf))): buf[-1 - i] *= i / k
    return buf

def write(name, buf):
    peak = max(1e-9, max(abs(v) for v in buf))
    scale = min(0.8, 0.8 / peak)
    frames = b"".join(struct.pack("<h", int(max(-1, min(1, v * scale)) * 32767)) for v in fade_end(buf))
    with tempfile.TemporaryDirectory() as tmp:
        wav = os.path.join(tmp, name + ".wav")
        with wave.open(wav, "wb") as w:
            w.setnchannels(1); w.setsampwidth(2); w.setframerate(RATE); w.writeframes(frames)
        os.makedirs(OUT, exist_ok=True)
        subprocess.run(["afconvert", "-f", "caff", "-d", "LEI16", wav, os.path.join(OUT, name + ".caf")], check=True)

SOFT = ((1, 1.0), (2, 0.25), (3, 0.08))
BELL = ((1, 1.0), (2.76, 0.5), (5.4, 0.25), (8.9, 0.1))
WOOD = ((1, 1.0), (4, 0.45), (10, 0.15))

# chime: two soft rising notes (E5, B5), 1.2 s
write("chime", mix(note(659.3, 1.2, 0.5, 3.5, SOFT, total=1.2), note(987.8, 1.0, 0.45, 4.0, SOFT, start=0.22, total=1.2)))
# bell: one round bell strike (A5), 1.5 s
write("bell", note(880.0, 1.5, 0.55, 3.0, BELL, total=1.5))
# marimba: three quick wooden notes going down (G5, E5, C5), 1.0 s
write("marimba", mix(note(784.0, 0.5, 0.55, 9.0, WOOD, total=1.0), note(659.3, 0.5, 0.55, 9.0, WOOD, start=0.18, total=1.0), note(523.3, 0.6, 0.55, 8.0, WOOD, start=0.36, total=1.0)))
# pop: a tiny bubble, a short upward sweep, 0.5 s
pop = []
phase = 0.0
for i in range(int(0.5 * RATE)):
    t = i / RATE
    f = 420 + 900 * min(1.0, t / 0.06)
    phase += 2 * math.pi * f / RATE
    pop.append(0.6 * math.sin(phase) * math.exp(-14 * t) * min(1.0, t / 0.003))
write("pop", pop)
# rise: three steps up (C5, E5, G5), 1.3 s
write("rise", mix(note(523.3, 0.6, 0.45, 4.0, SOFT, total=1.3), note(659.3, 0.6, 0.45, 4.0, SOFT, start=0.28, total=1.3), note(784.0, 0.9, 0.5, 3.5, SOFT, start=0.56, total=1.3)))
# knock: two soft knocks, 0.7 s
write("knock", mix(note(180.0, 0.25, 0.8, 22.0, ((1, 1.0), (2.3, 0.4)), total=0.7), note(170.0, 0.25, 0.7, 22.0, ((1, 1.0), (2.3, 0.4)), start=0.25, total=0.7)))
# louder: a stronger, brighter three-ring pattern (A5 + E6 together, three times), 1.5 s
rings = [note(880.0, 0.4, 0.5, 5.0, BELL, start=s, total=1.5) for s in (0.0, 0.45, 0.9)]
rings += [note(1318.5, 0.4, 0.35, 5.0, SOFT, start=s, total=1.5) for s in (0.0, 0.45, 0.9)]
write("louder", mix(*rings))
print("Sounds written to", os.path.normpath(OUT))
