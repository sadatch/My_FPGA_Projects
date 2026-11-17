#!/usr/bin/env python3
"""serial_viewer.py -- FPGA (UART) から膜電位を受信してリアルタイム描画する

  python3 python/serial_viewer.py --port /dev/tty.usbserial-XXXX          # ライブ表示 (要 pyserial)
  python3 python/serial_viewer.py --replay sim/out/uart_capture.bin --save docs/uart_capture.png
  python3 python/serial_viewer.py --selftest                              # パーサーの自己テスト

フレーム (4 byte / サンプル, 0.25 ms ごと, 921600 baud 8N1):
  [0] 0xA5            同期
  [1] v[7:0]          v は Q8.8 の int16 (mV = v/256), リトルエンディアン
  [2] v[15:8]
  [3] {seq[3:0], preset[1:0], mode, spike}
"""
from __future__ import annotations

import argparse
import sys
import threading
from collections import deque
from dataclasses import dataclass

SYNC = 0xA5
FRAME = 4
DT_MS = 0.25
PRESET_NAMES = ["RS", "IB", "CH", "FS"]


@dataclass
class Frame:
    v16: int
    spike: int
    mode: int
    preset: int
    seq: int

    @property
    def v_mv(self) -> float:
        return self.v16 / 256.0


def parse_frames(buf: bytearray, final: bool = False) -> list[Frame]:
    """buf からフレームを取り出し、使った分を buf から削除する。

    データ中にも 0xA5 は現れるので、次のフレーム頭も 0xA5 であることを確認してから採用する
    （確認できる分だけ受信が済むまで待つ。final=True のときは末尾まで確認なしで採用）。
    """
    frames: list[Frame] = []
    i = 0
    n = len(buf)
    while n - i >= FRAME:
        if buf[i] != SYNC:
            i += 1
            continue
        if n - i >= 2 * FRAME:
            if buf[i + FRAME] != SYNC:
                i += 1
                continue
        elif not final:
            break
        v16 = int.from_bytes(buf[i + 1:i + 3], "little", signed=True)
        fl = buf[i + 3]
        frames.append(Frame(v16=v16, spike=fl & 1, mode=(fl >> 1) & 1, preset=(fl >> 2) & 3, seq=fl >> 4))
        i += FRAME
    del buf[:i]
    return frames


def count_dropped(frames: list[Frame]) -> int:
    drop = 0
    for a, b in zip(frames, frames[1:]):
        drop += (b.seq - a.seq - 1) % 16
    return drop


# ----------------------------------------------------------------------
def make_figure(frames: list[Frame], title: str):
    import matplotlib.pyplot as plt
    t = [k * DT_MS for k in range(len(frames))]
    v = [f.v_mv for f in frames]
    fig, ax = plt.subplots(figsize=(10, 3.6))
    ax.plot(t, v, lw=1.0, color="#1b9e50")
    sp = [k * DT_MS for k, f in enumerate(frames) if f.spike]
    ax.plot(sp, [30] * len(sp), "v", ms=4, color="#d62728", label="spike")
    ax.set_xlabel("time [ms]")
    ax.set_ylabel("membrane potential v [mV]")
    ax.set_ylim(-85, 40)
    ax.set_title(title)
    ax.grid(alpha=0.3)
    if sp:
        ax.legend(loc="upper right")
    fig.tight_layout()
    return fig


def live(port: str, baud: int, window_ms: float):
    try:
        import serial
    except ImportError:
        sys.exit("pyserial が必要です:  pip install pyserial")
    import matplotlib.pyplot as plt
    from matplotlib.animation import FuncAnimation

    n = int(window_ms / DT_MS)
    vs = deque([-65.0] * n, maxlen=n)
    sp = deque([0] * n, maxlen=n)
    info = {"seq": None, "drop": 0, "label": ""}
    lock = threading.Lock()
    stop = threading.Event()

    def reader():
        ser = serial.Serial(port, baud, timeout=0.05)
        buf = bytearray()
        while not stop.is_set():
            buf += ser.read(4096)
            fr = parse_frames(buf)
            if not fr:
                continue
            with lock:
                for f in fr:
                    if info["seq"] is not None:
                        info["drop"] += (f.seq - info["seq"] - 1) % 16
                    info["seq"] = f.seq
                    vs.append(f.v_mv)
                    sp.append(f.spike)
                    info["label"] = ("LIF" if f.mode else f"Izhikevich {PRESET_NAMES[f.preset]}")
        ser.close()

    threading.Thread(target=reader, daemon=True).start()

    fig, ax = plt.subplots(figsize=(10, 4))
    ts = [k * DT_MS for k in range(n)]
    (line,) = ax.plot(ts, list(vs), lw=1.0, color="#1b9e50")
    (dots,) = ax.plot([], [], "v", ms=4, color="#d62728")
    ax.set_ylim(-85, 40)
    ax.set_xlim(0, window_ms)
    ax.set_xlabel("time [ms]")
    ax.set_ylabel("v [mV]")
    ax.grid(alpha=0.3)
    ttl = ax.set_title("waiting for data ...")

    def update(_):
        with lock:
            y = list(vs)
            s = list(sp)
            lab, drop = info["label"], info["drop"]
        line.set_ydata(y)
        idx = [k for k, f in enumerate(s) if f]
        dots.set_data([ts[k] for k in idx], [30] * len(idx))
        ttl.set_text(f"{lab}   spikes in window: {len(idx)}   dropped frames: {drop}")
        return line, dots, ttl

    anim = FuncAnimation(fig, update, interval=50, blit=False, cache_frame_data=False)
    try:
        plt.show()
    finally:
        stop.set()
    return anim


# ----------------------------------------------------------------------
def selftest() -> bool:
    import random
    rng = random.Random(1)
    ok = True

    # 1) 通常のストリーム（0xA5 がデータ側に現れるケースを含む）
    frames_in = []
    for k in range(500):
        v16 = rng.choice([-0x5A00, -0x5B5B, 0x1E00, 0x00A5, -0x5B00 + 0xA5, rng.randint(-20000, 7680)])
        frames_in.append((v16, k & 1, 0, k % 4, k & 0xF))
    raw = bytearray()
    for v16, sp, mode, preset, seq in frames_in:
        raw += bytes([SYNC, v16 & 0xFF, (v16 >> 8) & 0xFF, (seq << 4) | (preset << 2) | (mode << 1) | sp])

    # 2) 途中から受信を始め、細切れに受け取る
    stream = bytearray(rng.randrange(256) for _ in range(7)) + raw
    buf = bytearray()
    got: list[Frame] = []
    pos = 0
    while pos < len(stream):
        step = rng.randint(1, 13)
        buf += stream[pos:pos + step]
        pos += step
        got += parse_frames(buf)
    got += parse_frames(buf, final=True)

    # 先頭の数フレームは誤同期の可能性があるので、末尾から揃えて比較
    m = min(len(got), len(frames_in))
    tail_got = got[-(m - 10):]
    tail_in = frames_in[-(m - 10):]
    for g, (v16, sp, mode, preset, seq) in zip(tail_got, tail_in):
        if (g.v16, g.spike, g.mode, g.preset, g.seq) != (v16, sp, mode, preset, seq):
            ok = False
            print("  mismatch:", g, (v16, sp, mode, preset, seq))
            break
    print(f"  stream test: parsed {len(got)} / {len(frames_in)} frames  -> {'PASS' if ok else 'FAIL'}")

    # 3) 取りこぼしカウント
    fr = [Frame(0, 0, 0, 0, s) for s in (14, 15, 0, 2, 3)]
    d = count_dropped(fr)
    ok &= (d == 1)
    print(f"  dropped count: {d} (expected 1) -> {'PASS' if d == 1 else 'FAIL'}")
    return ok


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--port")
    ap.add_argument("--baud", type=int, default=921600)
    ap.add_argument("--window", type=float, default=300.0, help="表示窓 [ms]")
    ap.add_argument("--replay", help="録画したバイナリを読む")
    ap.add_argument("--save", help="PNG に保存して終了 (--replay と併用)")
    ap.add_argument("--selftest", action="store_true")
    a = ap.parse_args()

    if a.selftest:
        sys.exit(0 if selftest() else 1)
    if a.replay:
        import matplotlib
        if a.save:
            matplotlib.use("Agg")
        import matplotlib.pyplot as plt
        raw = bytearray(open(a.replay, "rb").read())
        frames = parse_frames(raw, final=True)
        print(f"{len(frames)} frames, dropped={count_dropped(frames)}, spikes={sum(f.spike for f in frames)}")
        fig = make_figure(frames, f"UART capture ({len(frames)} samples, dt = {DT_MS} ms)")
        if a.save:
            fig.savefig(a.save, dpi=130)
            print("saved", a.save)
        else:
            plt.show()
        return
    if not a.port:
        ap.error("--port か --replay か --selftest を指定してください")
    live(a.port, a.baud, a.window)


if __name__ == "__main__":
    main()
