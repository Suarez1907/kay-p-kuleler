#!/usr/bin/env python3
"""Kayıp Kuleler — ASMR müzik ve dokunsal foley üretim hattı (Python DSP).

    python3 tools/generate_asmr_audio.py            (tümünü üret)
    python3 tools/generate_asmr_audio.py --wav      (OGG yerine WAV)

Çıktı: godot-program/assets/audio/{music,sfx,assembly}/  — 44.1 kHz, stereo, 16 bit; ffmpeg (libvorbis) varsa
.ogg (quality 6), yoksa soundfile ile .ogg, o da yoksa .wav. Her dosya -1.5 dBFS'e normalize edilir (kırpılma yok).

Ses tasarımı: çıplak sinüs/8-bit yok. Her ses organik ADSR zarfı, Butterworth alçak geçiren filtre, hafif stereo
genişlik (Haas gecikmesi + ayrık gürültü), pembe/kahverengi gürültü katmanları kullanır. Müzik döngüleri
overlap-add çapraz geçişle dikişsizdir. Armoni: C majör / A minör pentatonik (C D E G A), 90 BPM, 16 sn (6 ölçü).

Bağımlılıklar: numpy (zorunlu), scipy (varsa Butterworth; yoksa tek kutuplu filtre yedeği), ffmpeg/soundfile (OGG).
Sonunda tools/asmr_audio_report.json yazılır (dosya, süre, tepe dBFS, boyut).
"""
import json
import os
import shutil
import subprocess
import sys
import wave

import numpy as np

try:
    from scipy.signal import butter, sosfilt
    HAVE_SCIPY = True
except Exception:  # pragma: no cover
    HAVE_SCIPY = False

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "godot-program", "assets", "audio"))
SR = 44100
BPM = 90.0
BEAT = 60.0 / BPM
LOOP_SEC = 16.0
PEAK_DB = -1.5
RNG = np.random.default_rng(1907)
FORCE_WAV = "--wav" in sys.argv

# C majör / A minör pentatonik frekansları
def midi(n):
    return 440.0 * 2.0 ** ((n - 69) / 12.0)
NOTE = {"C": 0, "D": 2, "E": 4, "G": 7, "A": 9}
def nf(name, octave):
    return midi(12 * (octave + 1) + NOTE[name])

# ---------------------------------------------------------------------------
# DSP yardımcıları
def t_axis(sec):
    return np.arange(int(sec * SR)) / SR

def lp(x, fc, order=4):
    fc = min(fc, SR * 0.45)
    if HAVE_SCIPY:
        return sosfilt(butter(order, fc, "low", fs=SR, output="sos"), x, axis=0)
    a = np.exp(-2 * np.pi * fc / SR)
    y = np.zeros_like(x)
    acc = np.zeros(x.shape[1:]) if x.ndim > 1 else 0.0
    for _ in range(2):
        for i in range(len(x)):
            acc = (1 - a) * x[i] + a * acc
            y[i] = acc
        x = y.copy()
    return y

def hp(x, fc, order=2):
    if HAVE_SCIPY:
        return sosfilt(butter(order, fc, "high", fs=SR, output="sos"), x, axis=0)
    return x - lp(x, fc)

def bp(x, lo, hi, order=2):
    if HAVE_SCIPY:
        return sosfilt(butter(order, [lo, min(hi, SR * 0.45)], "band", fs=SR, output="sos"), x, axis=0)
    return hp(lp(x, hi), lo)

def white(n):
    return RNG.standard_normal(n)

def pink(n):
    """1/f gürültü (FFT ile şekillendirilmiş)."""
    w = np.fft.rfft(white(n))
    f = np.arange(len(w))
    f[0] = 1
    p = np.fft.irfft(w / np.sqrt(f), n)
    return p / (np.max(np.abs(p)) + 1e-9)

def brown(n):
    b = np.cumsum(white(n))
    b = hp(b, 20.0, 1)
    return b / (np.max(np.abs(b)) + 1e-9)

def adsr(n, a, d, s, r, curve=2.0):
    """Organik ADSR (saniye); üstel eğrili."""
    env = np.ones(n) * s
    na, nd, nr = int(a * SR), int(d * SR), int(r * SR)
    na = min(na, n)
    if na > 0:
        env[:na] = (np.linspace(0, 1, na)) ** (1 / curve)
    if nd > 0 and na + nd <= n:
        env[na:na + nd] = s + (1 - s) * (np.linspace(1, 0, nd)) ** curve
    if nr > 0:
        nr = min(nr, n)
        env[n - nr:] *= np.linspace(1, 0, nr) ** curve
    return env

def decay(n, tau):
    return np.exp(-np.arange(n) / (tau * SR))

def stereo(mono, width=0.35, haas_ms=9.0):
    """Hafif stereo genişlik: sağ kanala kısa gecikme + ayrık yüksek frekans."""
    d = int(haas_ms * SR / 1000)
    r = np.concatenate([np.zeros(d), mono[:-d]]) if d > 0 else mono
    l = mono
    mid = (l + r) / 2
    side = (l - r) / 2 * width * 2.0
    return np.stack([mid + side, mid - side], axis=1)

def pan(mono, p):
    """p: -1 sol .. 1 sağ (eşit güç)."""
    a = (p + 1) * np.pi / 4
    return np.stack([mono * np.cos(a), mono * np.sin(a)], axis=1)

def add_at(buf, sig, start):
    s = int(start * SR)
    if s >= len(buf):
        return
    e = min(len(buf), s + len(sig))
    buf[s:e] += sig[:e - s]

def seamless(x, tail):
    """Overlap-add: döngü sonunu (tail) eşit güçlü geçişle başa ekler; uzunluk = len(x) - tail."""
    n = len(x) - tail
    out = x[:n].copy()
    k = np.linspace(0, np.pi / 2, tail)
    fin, fout = np.sin(k), np.cos(k)
    if x.ndim > 1:
        fin, fout = fin[:, None], fout[:, None]
    out[:tail] = out[:tail] * fin + x[n:n + tail] * fout
    return out

def osc(freq, sec, shape="warm", detune=0.0, phase=0.0):
    """Sıcak analog osilatör: bant sınırlı testere (ilk 9 harmonik, azalan) + detune."""
    t = t_axis(sec)
    f = freq * (1 + detune)
    y = np.zeros_like(t)
    if shape == "warm":
        for h in range(1, 10):
            y += np.sin(2 * np.pi * f * h * t + phase * h) / (h ** 1.35)
    elif shape == "soft":
        for h, a in ((1, 1.0), (2, 0.35), (3, 0.12), (4, 0.05)):
            y += a * np.sin(2 * np.pi * f * h * t + phase)
    elif shape == "glass":
        for h, a in ((1, 1.0), (2.76, 0.4), (5.4, 0.18), (8.93, 0.07)):
            y += a * np.sin(2 * np.pi * f * h * t + phase)
    return y

def normalize(x, db=PEAK_DB):
    peak = np.max(np.abs(x)) + 1e-12
    return x * (10 ** (db / 20) / peak)

# ---------------------------------------------------------------------------
# yazma
REPORT = []

def write(rel, x):
    if x.ndim == 1:
        x = np.stack([x, x], axis=1)
    x = normalize(x)
    pcm = np.clip(np.round(x * 32767), -32768, 32767).astype("<i2")
    path_noext = os.path.join(ROOT, rel)
    os.makedirs(os.path.dirname(path_noext), exist_ok=True)
    wav_path = path_noext + ".wav"
    with wave.open(wav_path, "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    out = wav_path
    if not FORCE_WAV:
        ogg = path_noext + ".ogg"
        ok = False
        if shutil.which("ffmpeg"):
            r = subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav_path, "-c:a", "libvorbis", "-q:a", "6", ogg])
            ok = r.returncode == 0 and os.path.getsize(ogg) > 0
        if not ok:
            try:
                import soundfile as sf
                sf.write(ogg, pcm, SR, format="OGG", subtype="VORBIS")
                ok = os.path.getsize(ogg) > 0
            except Exception:
                ok = False
        if ok:
            os.remove(wav_path)
            out = ogg
    peak_db = 20 * np.log10(np.max(np.abs(pcm.astype(np.float64))) / 32767 + 1e-12)
    clipped = int(np.sum(np.abs(pcm.astype(np.int32)) >= 32767))
    REPORT.append({"file": os.path.relpath(out, ROOT), "sec": round(len(x) / SR, 3), "peak_dbfs": round(float(peak_db), 2),
                   "clipped_samples": clipped, "bytes": os.path.getsize(out)})
    print("  %-40s %6.2f sn  tepe %6.2f dBFS  %7.1f KB" % (os.path.relpath(out, ROOT), len(x) / SR, peak_db, os.path.getsize(out) / 1024))

# ---------------------------------------------------------------------------
# A) MÜZİK: 5 faz grubu × 3 senkronize katman (think / code / run)
TAIL = int(1.5 * SR)
N = int(LOOP_SEC * SR) + TAIL
# 6 ölçü × 4 vuruş: pentatonik akor dizisi (Am7(11) — Cadd9 — Dsus — Em7 — Am — Gsus), her ölçü bir akor
PROG = [
    [("A", 2), ("E", 3), ("G", 3), ("C", 4), ("D", 4)],
    [("C", 3), ("G", 3), ("D", 4), ("E", 4)],
    [("D", 3), ("A", 3), ("C", 4), ("E", 4)],
    [("E", 2), ("G", 3), ("D", 4), ("A", 4)],
    [("A", 2), ("E", 3), ("C", 4), ("G", 4)],
    [("G", 2), ("D", 3), ("A", 3), ("C", 4)],
]
BAR = BEAT * 4

def pad_layer(bright=900.0, breath=0.0, width=0.5, level=1.0, octave_up=False):
    """Sıcak low-pass pad: her ölçüde yumuşak giriş, akorlar birbirine akar."""
    buf = np.zeros((N, 2))
    for b, chord in enumerate(PROG):
        dur = BAR * 1.6
        for k, (nm, o) in enumerate(chord):
            f = nf(nm, o + (1 if octave_up else 0))
            for det in (-0.004, 0.0035):
                y = osc(f, dur, "warm", det, RNG.uniform(0, 6.28))
                y *= adsr(len(y), 1.4, 0.8, 0.75, 1.6)
                st = pan(y, np.clip(det * 120 + (k - 2) * 0.12, -0.9, 0.9))
                add_at(buf, st * 0.12 * level, b * BAR)
    # akorlar ölçü sonunu aşar: kuyruğu başa sar (döngü)
    if breath > 0:
        t = np.arange(N) / SR
        lfo = 1.0 - breath * (0.5 + 0.5 * np.sin(2 * np.pi * t / (BAR * 2)))
        buf *= lfo[:, None]
    buf = lp(buf, bright)
    return buf

def micro_ticks(fc=5200.0, density=4, level=0.4, swing=0.0, glass=False):
    """Hipnotik mikro ritim: 16'lıklarda çok kısa filtreli tıkırtılar, sol/sağ salınımlı."""
    buf = np.zeros((N, 2))
    step = BEAT / density
    n_steps = int(LOOP_SEC / step)
    for i in range(n_steps):
        acc = 1.0 if i % density == 0 else (0.55 if i % 2 == 0 else 0.35)
        ln = int(0.03 * SR)
        click = bp(white(ln), fc * 0.6, fc * 1.4) * decay(ln, 0.004)
        click += 0.4 * np.sin(2 * np.pi * (fc * 0.42) * np.arange(ln) / SR) * decay(ln, 0.006)
        if glass and i % (density * 2) == 0:
            nm, o = [("E", 6), ("G", 6), ("A", 6), ("C", 7)][(i // (density * 2)) % 4]
            g = osc(nf(nm, o), 0.9, "glass") * decay(int(0.9 * SR), 0.25) * 0.25
            add_at(buf, pan(g, 0.3 if (i // 8) % 2 else -0.3), i * step)
        tt = i * step + (swing * step if i % 2 else 0.0)
        add_at(buf, pan(click * acc * level, 0.45 * np.sin(i * 0.7)), tt)
    return buf

def run_layer(arp_oct=4, arp_div=2, pulse=True, level=1.0, bright=2600.0):
    """Yumuşak bas nabzı (çeyrek) + pentatonik arpej (sekizlik/16'lık) hareketi."""
    buf = np.zeros((N, 2))
    for b, chord in enumerate(PROG):
        root = chord[0]
        if pulse:
            for q in range(4):
                ln = int(BEAT * 0.9 * SR)
                f = nf(root[0], 1 if root[1] <= 2 else 2)
                y = osc(f, BEAT * 0.9, "soft") * adsr(ln, 0.012, 0.25, 0.35, 0.35)
                y = lp(y, 420)
                add_at(buf, stereo(y * (0.5 if q % 2 else 0.62) * level, 0.15), b * BAR + q * BEAT)
        notes = [nf(nm, arp_oct) for nm, _ in chord] + [nf(chord[1][0], arp_oct + 1)]
        steps = 4 * arp_div
        for s in range(steps):
            f = notes[(s * 2 + b) % len(notes)]
            ln = int(0.55 * SR)
            pl = osc(f, 0.55, "soft") * adsr(ln, 0.005, 0.18, 0.2, 0.3)
            add_at(buf, pan(lp(pl, bright) * 0.22 * level, np.sin(s * 0.9) * 0.55), b * BAR + s * BAR / steps)
    return buf

def hum(base=50.0, level=0.03):
    """Güç trafosu uğultusu: 50/100/150 Hz, çok kısık, hafif dalgalanmalı."""
    t = np.arange(N) / SR
    y = np.zeros(N)
    for h, a in ((1, 1.0), (2, 0.55), (3, 0.22), (4, 0.1)):
        y += a * np.sin(2 * np.pi * base * h * t)
    y *= 1 + 0.08 * np.sin(2 * np.pi * 0.11 * t)
    return stereo(lp(y, 380) * level, 0.2)

def air(fc=1400.0, level=0.12, motion=0.25):
    """Fan/hava dokusu: pembe gürültü, yavaş dalgalanan filtre genliği."""
    t = np.arange(N) / SR
    l = bp(pink(N), 120, fc)
    r = bp(pink(N), 120, fc)
    env = 1 - motion * (0.5 + 0.5 * np.sin(2 * np.pi * t / (BAR * 3)))
    return np.stack([l * env, r * env], axis=1) * level

def data_whisper(level=0.05):
    """İnce veri akışı fısıltısı: yüksek bantlı, ritmik kapılı gürültü."""
    n = N
    t = np.arange(n) / SR
    g = 0.5 + 0.5 * np.sign(np.sin(2 * np.pi * (BPM / 60.0) * 4 * t))
    g = lp(g, 40, 2)
    s = bp(white(n), 6000, 12000) * g
    return stereo(s * level, 0.8)

def make_group(name, think, code, run):
    for layer, buf in (("think", think), ("code", code), ("run", run)):
        x = seamless(buf, TAIL)
        x = lp(x, 16000, 2)
        write(os.path.join("music", "%s_%s" % (name, layer)), x)

def music():
    print("MÜZİK (90 BPM, 16 sn, 3 katman)")
    make_group("phase_1_2",
               pad_layer(700, 0.15, level=1.1) + hum(50, 0.05) + 0.25 * brown(N)[:, None] * 0.06,
               micro_ticks(4200, 4, 0.32),
               run_layer(4, 2, True, 0.9, 2000))
    make_group("phase_3_4",
               pad_layer(1100, 0.1, level=0.9) + micro_ticks(7000, 1, 0.05, glass=True),
               micro_ticks(6800, 4, 0.36, swing=0.08, glass=True),
               run_layer(5, 2, True, 0.85, 3200))
    make_group("phase_5_6",
               pad_layer(950, 0.45, level=1.0) + data_whisper(0.025),
               micro_ticks(5200, 4, 0.3) + data_whisper(0.04),
               run_layer(4, 4, True, 0.8, 2600))
    make_group("phase_7_8",
               pad_layer(1300, 0.2, level=0.85, octave_up=True) + air(1600, 0.16, 0.35),
               micro_ticks(3600, 2, 0.34) + air(2400, 0.05, 0.6),
               run_layer(5, 2, True, 0.85, 3000))
    make_group("phase_9_10",
               pad_layer(1200, 0.25, level=1.0) + pad_layer(2200, 0.3, level=0.45, octave_up=True) + hum(50, 0.025) + air(1400, 0.07),
               micro_ticks(5600, 4, 0.3, glass=True) + data_whisper(0.03),
               run_layer(4, 4, True, 0.95, 3400))

# ---------------------------------------------------------------------------
# B) FOLEY ve bileşen sesleri
def thock(seed):
    r = np.random.default_rng(seed)
    ln = int(0.14 * SR)
    t = np.arange(ln) / SR
    atk = bp(r.standard_normal(ln), 1800, 7000) * decay(ln, 0.0011 + r.uniform(0, 0.0004))
    f0, f1 = 190 * r.uniform(0.95, 1.05), 85 * r.uniform(0.95, 1.05)
    ph = 2 * np.pi * np.cumsum(f1 + (f0 - f1) * np.exp(-t / 0.012)) / SR
    body = np.sin(ph) * decay(ln, 0.035) * 0.9
    base = lp(r.standard_normal(ln), 900) * decay(ln, 0.006) * 0.35
    base = np.roll(base, int(0.004 * SR))
    y = atk * 0.7 + body + base
    return stereo(lp(y, 9000), 0.12)

def marimba(f, sec=1.2):
    """Sönümlü harmonik marimba/kalimba: 1, 3.93, 9.2 oranlı kısmi tonlar, yumuşak tokmak."""
    ln = int(sec * SR)
    t = np.arange(ln) / SR
    y = np.sin(2 * np.pi * f * t) * decay(ln, 0.42)
    y += 0.28 * np.sin(2 * np.pi * f * 3.93 * t) * decay(ln, 0.09)
    y += 0.07 * np.sin(2 * np.pi * f * 9.2 * t) * decay(ln, 0.03)
    mallet = lp(white(ln), 2500) * decay(ln, 0.004) * 0.25
    y = (y + mallet) * adsr(ln, 0.003, 0.0, 1.0, 0.15)
    return stereo(lp(y, 6000), 0.25)

def karplus(f, sec=1.0, damp=0.996):
    """Karplus-Strong telli/ahşap ton."""
    ln = int(sec * SR)
    per = int(SR / f)
    buf = lp(white(per), 3000)
    out = np.zeros(ln)
    for i in range(ln):
        v = buf[i % per]
        out[i] = v
        buf[i % per] = damp * 0.5 * (v + buf[(i + 1) % per])
    return out

def smd(seed):
    r = np.random.default_rng(seed)
    ln = int(0.35 * SR)
    t = np.arange(ln) / SR
    contact = bp(r.standard_normal(ln), 3000, 9000) * decay(ln, 0.002)
    glow = np.sin(2 * np.pi * (1320 * r.uniform(0.97, 1.03)) * t) * decay(ln, 0.06) * 0.25
    stat = bp(r.standard_normal(ln), 5000, 12000) * (r.random(ln) < 0.04) * decay(ln, 0.08) * 0.5
    return stereo(contact + glow + stat, 0.4)

def diode_block():
    ln = int(0.32 * SR)
    t = np.arange(ln) / SR
    thud = np.sin(2 * np.pi * (95 * np.exp(-t / 0.05) + 55) * t) * decay(ln, 0.06)
    bounce = np.roll(np.sin(2 * np.pi * 140 * t) * decay(ln, 0.025) * 0.35, int(0.11 * SR))
    hit = lp(white(ln), 1200) * decay(ln, 0.006) * 0.5
    return stereo(lp(thud + bounce + hit, 2500), 0.15)

def cap_launch():
    ln = int(0.7 * SR)
    t = np.arange(ln) / SR
    f = 220 + 1500 * (t / t[-1]) ** 1.8
    ph = 2 * np.pi * np.cumsum(f) / SR
    y = (np.sin(ph) + 0.3 * np.sin(2 * ph) + 0.12 * np.sin(3.01 * ph)) * adsr(ln, 0.06, 0.0, 1.0, 0.25)
    shimmer = bp(white(ln), 3000, 9000) * (t / t[-1]) * 0.15
    return stereo(lp(y * 0.6 + shimmer, 7000), 0.5)

def resistor_tick():
    ln = int(0.18 * SR)
    y = np.zeros(ln)
    for k, at in enumerate((0.0, 0.05)):
        s = int(at * SR)
        m = ln - s
        y[s:] += (bp(white(m), 2200, 6000) * decay(m, 0.0025) + 0.5 * np.sin(2 * np.pi * (1500 - 300 * k) * np.arange(m) / SR) * decay(m, 0.012))
    return stereo(y, 0.2)

def relay(seed):
    r = np.random.default_rng(seed)
    ln = int(0.24 * SR)
    y = np.zeros(ln)
    for at, f, amp in ((0.0, 2300, 1.0), (0.075 + r.uniform(-0.008, 0.008), 3300, 0.75)):
        s = int(at * SR)
        m = ln - s
        tt = np.arange(m) / SR
        y[s:] += amp * (bp(r.standard_normal(m), 1500, 8000) * decay(m, 0.0016) + 0.45 * np.sin(2 * np.pi * f * tt) * decay(m, 0.01)
                        + 0.35 * np.sin(2 * np.pi * 180 * tt) * decay(m, 0.02))
    return stereo(y, 0.25)

def whoosh():
    ln = int(1.1 * SR)
    t = np.arange(ln) / SR
    n = pink(ln)
    env = np.sin(np.pi * np.clip(t / 1.1, 0, 1)) ** 2
    out = np.zeros(ln)
    seg = 2048
    for i in range(0, ln, seg):
        fc = 400 + 2600 * env[min(i + seg // 2, ln - 1)]
        out[i:i + seg] = lp(n[i:i + seg], fc, 2)
    l = out * env
    return np.stack([l * (1 - 0.4 * t / 1.1), l * (0.6 + 0.4 * t / 1.1)], axis=1)

def snap(seed):
    r = np.random.default_rng(seed)
    ln = int(0.5 * SR)
    t = np.arange(ln) / SR
    click = bp(r.standard_normal(ln), 2500, 10000) * decay(ln, 0.0018) * 1.2
    metal = (np.sin(2 * np.pi * 3600 * r.uniform(0.96, 1.04) * t) + 0.5 * np.sin(2 * np.pi * 5230 * t)) * decay(ln, 0.03) * 0.25
    body = np.sin(2 * np.pi * (160 * np.exp(-t / 0.03) + 70) * t) * decay(ln, 0.07) * 0.7
    sizzle = bp(r.standard_normal(ln), 4000, 12000) * (r.random(ln) < 0.06) * decay(ln, 0.09) * 0.35
    sizzle = np.roll(sizzle, int(0.03 * SR))
    return stereo(click + metal + body + sizzle, 0.35)

def power_switch():
    ln = int(0.5 * SR)
    t = np.arange(ln) / SR
    press = bp(white(ln), 800, 5000) * decay(ln, 0.003)
    latch = np.roll(bp(white(ln), 1500, 7000) * decay(ln, 0.002) * 0.8, int(0.06 * SR))
    body = np.sin(2 * np.pi * (110 * np.exp(-t / 0.04) + 55) * t) * decay(ln, 0.1) * 0.9
    return stereo(lp(press + latch + body, 8000), 0.2)

def fan_spinup():
    sec = 6.0
    ln = int(sec * SR)
    t = np.arange(ln) / SR
    k = (1 - np.exp(-t / 1.8))
    n = pink(ln)
    out = np.zeros(ln)
    seg = 4096
    for i in range(0, ln, seg):
        fc = 150 + 2200 * k[min(i + seg // 2, ln - 1)]
        out[i:i + seg] = lp(n[i:i + seg], fc, 2)
    motor_f = 30 + 170 * k
    motor = np.sin(2 * np.pi * np.cumsum(motor_f) / SR) * 0.15 * k
    blade = np.sin(2 * np.pi * np.cumsum(motor_f * 7) / SR) * 0.05 * k
    y = (out * (0.3 + 0.7 * k) + motor + blade) * adsr(ln, 0.3, 0.0, 1.0, 0.6)
    return stereo(y, 0.6)

def bios_beep():
    ln = int(0.12 * SR)
    t = np.arange(ln) / SR
    y = (np.sin(2 * np.pi * 1000 * t) * 0.8 + 0.2 * np.sin(2 * np.pi * 3000 * t)) * adsr(ln, 0.004, 0.0, 1.0, 0.012)
    return stereo(lp(y, 6000), 0.05)

def boot_chord():
    sec = 4.6
    ln = int(sec * SR)
    buf = np.zeros((ln, 2))
    notes = [nf("C", 3), nf("G", 3), nf("E", 4), nf("D", 5), nf("G", 4), nf("C", 4)]   # Cmaj9 (C E G D) + oktavlar
    for k, f in enumerate(notes):
        for det in (-0.003, 0.003):
            y = osc(f, sec, "warm", det, RNG.uniform(0, 6)) * adsr(ln, 0.25 + 0.05 * k, 0.6, 0.6, 3.2)
            buf += pan(y * 0.1, (k / (len(notes) - 1) - 0.5) * 1.4 + det * 50)
    shimmer = stereo(bp(pink(ln), 4000, 10000) * adsr(ln, 0.8, 0.5, 0.3, 2.5) * 0.04, 0.9)
    return lp(buf, 3800) + shimmer

def foley():
    print("FOLEY ve BİLEŞENLER")
    for i in range(4):
        write("sfx/ui_key_thock_%02d" % (i + 1), thock(100 + i))
    for nm, (n, o) in (("c5", ("C", 5)), ("d5", ("D", 5)), ("e5", ("E", 5)), ("g5", ("G", 5)), ("a5", ("A", 5)), ("c6", ("C", 6))):
        f = nf(n, o)
        y = marimba(f) + stereo(lp(karplus(f, 1.2), 4000) * 0.18 * adsr(int(1.2 * SR), 0.002, 0, 1, 0.2), 0.3)
        write("sfx/step_note_" + nm, y)
    for i in range(3):
        write("sfx/sfx_smd_pulse_%02d" % (i + 1), smd(200 + i))
    write("sfx/sfx_diode_block", diode_block())
    write("sfx/sfx_capacitor_launch", cap_launch())
    write("sfx/sfx_resistor_tick", resistor_tick())
    for i in range(2):
        write("sfx/sfx_relay_clack_%02d" % (i + 1), relay(300 + i))
    print("MONTAJ ve FİNAL")
    write("assembly/sfx_part_whoosh", whoosh())
    for i in range(3):
        write("assembly/sfx_part_snap_%02d" % (i + 1), snap(400 + i))
    write("assembly/sfx_power_switch", power_switch())
    write("assembly/sfx_fan_spinup", fan_spinup())
    write("assembly/sfx_bios_beep", bios_beep())
    write("assembly/sfx_boot_chord", boot_chord())

def main():
    print("scipy: %s · çıktı: %s" % (HAVE_SCIPY, ROOT))
    # eski üretimleri temizle (yalnızca bu betiğin klasörleri)
    for sub in ("music", "sfx", "assembly"):
        d = os.path.join(ROOT, sub)
        if os.path.isdir(d):
            for f in os.listdir(d):
                if f.endswith((".ogg", ".wav")):
                    os.remove(os.path.join(d, f))
    music()
    foley()
    total = sum(r["bytes"] for r in REPORT)
    bad = [r for r in REPORT if r["bytes"] == 0 or r["clipped_samples"] > 0 or r["peak_dbfs"] > -1.0]
    rep = {"sample_rate": SR, "bpm": BPM, "loop_sec": LOOP_SEC, "files": REPORT, "count": len(REPORT),
           "total_mb": round(total / 1e6, 2), "problems": bad}
    with open(os.path.join(HERE, "asmr_audio_report.json"), "w") as f:
        json.dump(rep, f, ensure_ascii=False, indent=1)
    print("toplam %d dosya, %.2f MB, sorunlu: %d" % (len(REPORT), total / 1e6, len(bad)))
    sys.exit(1 if bad else 0)

if __name__ == "__main__":
    main()
