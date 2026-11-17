#!/usr/bin/env python3
"""make_figures.py -- 参照モデルの図を docs/ に出す（浮動小数点 vs 固定小数点の比較つき）

    python3 python/make_figures.py
"""
from __future__ import annotations

import sys
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "python"))
import ref_model as rm  # noqa: E402

DOCS = ROOT / "docs"
DOCS.mkdir(exist_ok=True)


def fig_izh():
    T, t_on, amp = 300.0, 20.0, 10.0
    I = rm.step_current(T, rm.DT, t_on, amp)
    N = len(I)
    Iq = rm.step_current_q(N, int(round(t_on / rm.DT)), rm.q(amp))
    fig, axs = plt.subplots(2, 2, figsize=(11, 6), sharex=True, sharey=True)
    print("Izhikevich: 浮動小数点 vs 固定小数点 (Q16.16)")
    for ax, name in zip(axs.ravel(), ["RS", "IB", "CH", "FS"]):
        t, vf, uf, spf = rm.float_izh(name, I)
        fx = rm.fixed_run(0, name, Iq)
        vx = np.array([r[0] for r in fx]) / rm.ONE
        spx = np.array([k for k, r in enumerate(fx) if r[2]], dtype=int)
        ax.plot(t, vf, color="#999999", lw=2.2, label="float")
        ax.plot(t, vx, color="#1b9e50", lw=1.0, ls="--", label="fixed Q16.16")
        a, b, c, d = rm.PRESETS[name]
        ax.set_title(f"{name}  (a={a}, b={b}, c={c}, d={d})", fontsize=10)
        ax.grid(alpha=0.3)
        n = min(len(spf), len(spx))
        dev = int(np.abs(spf[:n] - spx[:n]).max()) if n else 0
        print(f"  {name}: spikes float={len(spf)} fixed={len(spx)}  max spike-time diff={dev} step(s) ({dev * rm.DT} ms)")
    axs[0, 0].legend(loc="lower right", fontsize=8)
    for ax in axs[1]:
        ax.set_xlabel("time [ms]")
    for ax in axs[:, 0]:
        ax.set_ylabel("v [mV]")
    fig.suptitle(f"Izhikevich neuron, step current I={amp:g} from t={t_on:g} ms, dt={rm.DT} ms", fontsize=11)
    fig.tight_layout()
    fig.savefig(DOCS / "izh_4types.png", dpi=130)
    plt.close(fig)


def fig_lif():
    Is = np.arange(0, 40.01, 0.5)
    T = 2000.0
    N = int(round(T / rm.DT))
    rate_f, rate_x = [], []
    for I in Is:
        _, _, spf = rm.float_lif(np.full(N, I))
        fx = rm.fixed_run(1, "RS", [rm.q(I)] * N)
        spx = np.array([k for k, r in enumerate(fx) if r[2]], dtype=int)
        rate_f.append(rm.rate_from_spikes(spf))
        rate_x.append(rm.rate_from_spikes(spx))
    th = rm.lif_rate_theory(Is)
    fig, ax = plt.subplots(figsize=(7, 4.2))
    ax.plot(Is, th, color="#444444", lw=2.0, label="theory (continuous time)")
    ax.plot(Is, rate_f, "o", ms=4, color="#999999", label="float, dt=0.25 ms")
    ax.plot(Is, rate_x, "x", ms=5, color="#1b9e50", label="fixed Q16.16")
    ax.set_xlabel("input current I")
    ax.set_ylabel("firing rate [Hz]")
    ax.set_title("LIF f-I curve (tau=16 ms, Vth-Vrest=15)")
    ax.grid(alpha=0.3)
    ax.legend()
    fig.tight_layout()
    fig.savefig(DOCS / "lif_fi.png", dpi=130)
    plt.close(fig)
    m = Is > 16
    print("LIF f-I (I>16): 理論との相対差 (float) 平均 %.1f%%, (fixed) 平均 %.1f%%" % (
        100 * np.mean((np.array(rate_f)[m] - th[m]) / th[m]),
        100 * np.mean((np.array(rate_x)[m] - th[m]) / th[m])))
    for I in (20, 30, 40):
        k = int(np.where(Is == I)[0][0])
        print(f"  I={I}: theory={th[k]:.1f} Hz, float={rate_f[k]:.1f} Hz, fixed={rate_x[k]:.1f} Hz")


if __name__ == "__main__":
    fig_izh()
    fig_lif()
    print("saved: docs/izh_4types.png, docs/lif_fi.png")
