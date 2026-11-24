from pathlib import Path
import numpy as np
import matplotlib.pyplot as plt

DOCS = Path(__file__).resolve().parent.parent / "docs"   # 実行場所に依存しない保存先

PRESETS = {  # (a, b, c, d)  Izhikevich (2003) Fig. 2
    "RS": (0.02, 0.2, -65, 8),
    "IB": (0.02, 0.2, -55, 4),
    "CH": (0.02, 0.2, -50, 2),
    "FS": (0.10, 0.2, -65, 2),
}




def step_current(T, dt, t_on, amp):
    # t_onは電流を入れ始める時刻(ms)
    # ステップ数N = T / Δt = 300ms / 0.25ms = 1200
    N = round(T / dt)
    I = np.zeros(N)
    # k_onはその時刻が配列の何番目であるか
    k_on = round(t_on / dt)
    I[k_on:] = amp
    return I


    ...

def izhikevich(a, b, c, d, I, T, dt=0.25):
    # Izhikevichモデルの微分方程式
    # dv/dt = 0.04v^2 + 5v + 140 - u + I
    # du/dt = a(bv - u)
    N = len(I)
    t = np.arange(N) * dt
    v_rec = np.empty(N)
    u_rec = np.empty(N)
    spike_times = []

    v = -65.0
    u = b * v

    for k in range(N):
        # 一つ前のv, uから新しいdv/dt, du/dtを求める(紛らわしいが、変数名の簡略化のため dv/dt = dv, du/dt = duとしてここでは扱う)
        dv = 0.04 * (v ** 2) + 5 * v + 140 - u + I[k]
        du = a * (b*v - u)
        #v1, u1を新しいv, uとして一時的に用いる
        v1 = v + dt*dv
        u1 = u + dt*du
        #v1 >= 30なら発火（原理的に）
        if v1 >= 30:
            spike_times.append(t[k])
            v_rec[k] = 30
            v = c
            u = u1 + d
        else:
            v = v1
            u = u1
            v_rec[k] = v1
        u_rec[k] = u
    
    return t, v_rec, u_rec, spike_times

def lif(I, T, dt=0.25, tau=16.0, v_rest=-65.0, v_th=-50.0, v_reset=-65.0):
    N = len(I)
    t = np.arange(N) * dt
    v_rec = np.empty(N)
    spike_times = []

    v = ...

    for k in range(N):
        # 傾きを出してv1 = v + (Δt/τ) * ( -(v - v_rest) + I[k] )を計算

if __name__ == "__main__":
    I = step_current(300, 0.25, 20, 10)

    fig, axes = plt.subplots(2, 2, figsize = (10, 6))
    for ax, (name, (a, b, c, d)) in zip(axes.ravel(), PRESETS.items()):
        t, v, u, sp = izhikevich(a, b, c, d, I, 300)
        ax.plot(t, v)
        ax.set_title(name)
        ax.set_xlabel("time [ms]")
        ax.set_ylabel("v [mV]")
    fig.tight_layout()
    fig.savefig(DOCS / "izh_4types_hand.png", dpi=150)

