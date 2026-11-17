#!/usr/bin/env python3
"""run_tests.py -- RTL を iverilog で動かし、Python 参照モデルと突き合わせる

    python3 python/run_tests.py            # core / bcd / top(UART+VGA) をすべて
    python3 python/run_tests.py core       # ニューロンコアだけ（数秒）
    python3 python/run_tests.py bcd
    python3 python/run_tests.py top        # 上位まで通した確認（UART 全フレーム照合 + VGA 画像出力）
"""
from __future__ import annotations

import shutil
import subprocess
import sys
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "python"))
import ref_model as rm  # noqa: E402

BUILD = ROOT / "build"
OUT = ROOT / "sim" / "out"
DOCS = ROOT / "docs"

RTL = {
    "core": ["serial_mul.sv", "preset_rom.sv", "neuron_core.sv"],
    "bcd": ["bin2bcd.sv"],
    "top": ["serial_mul.sv", "preset_rom.sv", "neuron_core.sv", "tick_gen.sv", "uart_tx.sv",
            "uart_frame_tx.sv", "vga_timing.sv", "wave_display.sv", "bin2bcd.sv",
            "seg7_4digit.sv", "top_basys3.sv"],
}
TB = {"core": "tb_neuron_core.sv", "bcd": "tb_bin2bcd.sv", "top": "tb_top.sv"}


def need(tool):
    if shutil.which(tool) is None:
        sys.exit(f"{tool} が見つかりません（Icarus Verilog をインストールしてください: brew install icarus-verilog）")


def compile_tb(name, extra=()):
    BUILD.mkdir(exist_ok=True)
    OUT.mkdir(parents=True, exist_ok=True)
    vvp = BUILD / f"{name}.vvp"
    srcs = [str(ROOT / "rtl" / f) for f in RTL[name]] + [str(ROOT / "sim" / TB[name])]
    cmd = ["iverilog", "-g2012", "-o", str(vvp), *extra, *srcs]
    r = subprocess.run(cmd, capture_output=True, text=True,
                       encoding="utf-8", errors="replace")
    if r.returncode != 0:
        print(r.stdout, r.stderr)
        sys.exit(f"コンパイル失敗: {name}")
    # iverilog 固有の「always_comb 内の定数ビット選択は未対応」警告は動作に影響しないので隠す
    msgs = [l for l in r.stderr.splitlines() if l.strip() and "constant selects in always_" not in l]
    if msgs:
        print("\n".join(msgs))
    return vvp


def run_vvp(vvp, *plusargs):
    # vvp の +plusarg 文字列は長い/日本語入りのパスだと途中で切れて $fopen が失敗するため、
    # sim/out を cwd にして、出力ファイルは短い相対名で渡す（呼び出し側は .name を渡す）
    OUT.mkdir(parents=True, exist_ok=True)
    r = subprocess.run(["vvp", str(vvp), *plusargs], capture_output=True, text=True,
                       encoding="utf-8", errors="replace", cwd=str(OUT))
    if r.returncode != 0:
        print(r.stdout, r.stderr)
        sys.exit("シミュレーション失敗")
    return r.stdout


# ----------------------------------------------------------------------
def test_core():
    need("iverilog")
    for name in rm.PRESETS:
        assert rm.preset_params(name) == rm.RTL_PRESET_ROM[name], f"preset_rom.sv と ref_model の値が不一致: {name}"
    vvp = compile_tb("core")
    q = rm.q
    cases = [
        # (label, mode, preset, I[Q16.16], steps)
        ("izh RS  I=10",    0, "RS", q(10.0),   1200),
        ("izh IB  I=10",    0, "IB", q(10.0),   1200),
        ("izh CH  I=10",    0, "CH", q(10.0),   1200),
        ("izh FS  I=10",    0, "FS", q(10.0),   1200),
        ("izh FS  I=63.75", 0, "FS", q(63.75),  1200),
        ("izh RS  I=63.75", 0, "RS", q(63.75),  1200),
        ("izh RS  I=-20",   0, "RS", q(-20.0),  1200),
        ("lif     I=20",    1, "RS", q(20.0),   1200),
        ("lif     I=63.75", 1, "RS", q(63.75),  1200),
        ("lif     I=10",    1, "RS", q(10.0),   1200),
    ]
    ok_all = True
    for label, mode, preset, Iq, steps in cases:
        csv = OUT / f"core_{mode}_{preset}_{Iq}.csv"
        run_vvp(vvp, f"+mode={mode}", f"+preset={rm.PRESET_INDEX[preset]}", f"+Iq={Iq}",
                f"+steps={steps}", "+on=80", f"+out={csv.name}")
        rtl = np.loadtxt(csv, dtype=np.int64)
        ref = rm.fixed_run(mode, preset, rm.step_current_q(steps, 80, Iq))
        ref = np.array([[k, v, u, s] for k, (v, u, s) in enumerate(ref)], dtype=np.int64)
        same = rtl.shape == ref.shape and np.array_equal(rtl, ref)
        nspk = int(ref[:, 3].sum())
        if same:
            print(f"  PASS  {label:<18s} {steps} steps, spikes={nspk}")
        else:
            ok_all = False
            bad = np.where((rtl != ref).any(axis=1))[0]
            k = bad[0] if len(bad) else -1
            print(f"  FAIL  {label:<18s} first mismatch at step {k}")
            if k >= 0:
                print(f"        rtl: {rtl[k].tolist()}\n        ref: {ref[k].tolist()}")
    return ok_all


def test_bcd():
    need("iverilog")
    vvp = compile_tb("bcd")
    out = run_vvp(vvp)
    print("  " + out.strip().replace("\n", "\n  "))
    return "FAIL" not in out and "PASS" in out


# ----------------------------------------------------------------------
def parse_frames(buf: bytearray, final=False):
    """serial_viewer.parse_frames と同じものを使う"""
    import serial_viewer as sv
    return sv.parse_frames(buf, final=final)


def test_top():
    need("iverilog")
    import serial_viewer as sv
    TICK_DIV = 5000
    vvp = compile_tb("top", extra=[f"-Ptb_top.TICK_DIV={TICK_DIV}"])
    steps = 1200
    # sw: I = 40 (=10.0), preset=RS(0), dec=1 (x2), mode=0
    out = run_vvp(vvp, f"+steps={steps}", "+uart=uart_hex.txt", "+ppm=frame.ppm")
    print("  " + out.strip().replace("\n", "\n  "))
    hexs = (OUT / "uart_hex.txt").read_text().split()
    raw = bytearray(int(h, 16) for h in hexs)
    (OUT / "uart_capture.bin").write_bytes(raw)
    frames = sv.parse_frames(bytearray(raw), final=True)
    ref = rm.fixed_run(0, "RS", rm.step_current_q(steps + 10, 80, rm.q(10.0)))
    n = min(len(frames), len(ref))
    mism = 0
    for k in range(n):
        v_exp = (ref[k][0] >> 8) & 0xFFFF
        v_exp = v_exp - 0x10000 if v_exp & 0x8000 else v_exp
        sp_exp = ref[k][2]
        if frames[k].v16 != v_exp or frames[k].spike != sp_exp:
            if mism < 3:
                print(f"    frame {k}: got v16={frames[k].v16} spike={frames[k].spike}, expected v16={v_exp} spike={sp_exp}")
            mism += 1
    seq_ok = all(frames[k].seq == (k & 0xF) for k in range(len(frames)))
    spikes = sum(f.spike for f in frames)
    print(f"  UART: {len(raw)} bytes -> {len(frames)} frames, mismatches={mism}, seq_ok={seq_ok}, spikes={spikes}")
    ok = len(frames) >= steps - 2 and mism == 0 and seq_ok and spikes > 0

    # 7セグ用の発火率: 窓 RATE_WIN=400 ステップの最後の窓 (steps 800..1199) の発火数
    import re
    m = re.search(r"BCD=([0-9a-fA-F]+)", out)
    if m:
        bcd = int(m.group(1), 16)
        shown = sum(((bcd >> (4 * i)) & 0xF) * 10 ** i for i in range(4))
        expected = sum(r[2] for r in ref[800:1200])
        print(f"  7seg: displayed rate={shown}, expected={expected} (steps 800..1199)")
        ok = ok and shown == expected
    else:
        print("  7seg: BCD の出力が見つかりません")
        ok = False

    # VGA フレームを PNG に
    from PIL import Image
    ppm = OUT / "frame.ppm"
    if ppm.exists():
        toks = ppm.read_text().split()
        w, h, mx = int(toks[1]), int(toks[2]), int(toks[3])
        arr = np.array(toks[4:], dtype=np.uint8).reshape(h, w, 3)
        DOCS.mkdir(exist_ok=True)
        Image.fromarray(arr).save(DOCS / "vga_frame_sim.png")
        print(f"  VGA : {w}x{h} -> docs/vga_frame_sim.png  (非黒ピクセル={int((arr.sum(axis=2) > 0).sum())})")
    return ok


if __name__ == "__main__":
    which = sys.argv[1:] or ["core", "bcd", "top"]
    res = {}
    for w in which:
        print(f"[{w}]")
        res[w] = {"core": test_core, "bcd": test_bcd, "top": test_top}[w]()
    print()
    for w, ok in res.items():
        print(f"{w:5s}: {'PASS' if ok else 'FAIL'}")
    sys.exit(0 if all(res.values()) else 1)
