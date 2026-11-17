"""ref_model.py -- ニューロンの参照モデル（浮動小数点 / Q16.16 固定小数点）

固定小数点版 (fixed_*) は rtl/neuron_core.sv とビット単位で一致するように書いてある。
Python の整数は無限精度なので、RTL の 32bit 幅を超えたら assert で検出する。
"""
from __future__ import annotations

import numpy as np

DT = 0.25                      # ms
FRAC = 16
ONE = 1 << FRAC


def q(x: float) -> int:
    """実数 -> Q16.16 (四捨五入)"""
    return int(round(x * ONE))


# Izhikevich (2003) Fig.2 : (a, b, c, d)
PRESETS = {
    "RS": (0.02, 0.2, -65, 8),
    "IB": (0.02, 0.2, -55, 4),
    "CH": (0.02, 0.2, -50, 2),
    "FS": (0.10, 0.2, -65, 2),
}
PRESET_INDEX = {"RS": 0, "IB": 1, "CH": 2, "FS": 3}

# LIF
LIF_TAU = 16.0                 # ms  (dt/tau = 2^-6)
LIF_VREST = -65.0
LIF_VRESET = -65.0
LIF_VTH = -50.0
V_PEAK = 30.0                  # 発火時の記録値 (mV)

# ---- 固定小数点定数 (Q16.16) : RTL の localparam と同じ値 ----
Q_V_PEAK = 30 << FRAC
Q_V_INIT = -65 << FRAC
Q_C140 = 140 << FRAC
Q_K004 = q(0.04)               # 2621
Q_LIF_VREST = -65 << FRAC
Q_LIF_VRESET = -65 << FRAC
Q_LIF_VTH = -50 << FRAC
IZH_SHIFT = 2                  # dt = 0.25 = 2^-2
LIF_SHIFT = 6                  # dt/tau = 2^-6


# ======================================================================
# 浮動小数点
# ======================================================================
def float_izh(preset, I, dt=DT):
    """I: 入力電流の配列 (長さ N)。 return t, v, u, spike_idx"""
    a, b, c, d = PRESETS[preset] if isinstance(preset, str) else preset
    N = len(I)
    t = np.arange(N) * dt
    v_rec = np.empty(N)
    u_rec = np.empty(N)
    spikes = []
    v = -65.0
    u = b * v
    for k in range(N):
        dv = 0.04 * v * v + 5.0 * v + 140.0 - u + I[k]
        du = a * (b * v - u)
        v1 = v + dt * dv
        u1 = u + dt * du
        if v1 >= V_PEAK:
            spikes.append(k)
            v_rec[k] = V_PEAK
            v, u = c, u1 + d
        else:
            v, u = v1, u1
            v_rec[k] = v
        u_rec[k] = u
    return t, v_rec, u_rec, np.array(spikes, dtype=int)


def float_lif(I, dt=DT, tau=LIF_TAU, v_rest=LIF_VREST, v_th=LIF_VTH, v_reset=LIF_VRESET):
    N = len(I)
    t = np.arange(N) * dt
    v_rec = np.empty(N)
    spikes = []
    v = v_rest
    for k in range(N):
        v1 = v + dt / tau * (-(v - v_rest) + I[k])
        if v1 >= v_th:
            spikes.append(k)
            v_rec[k] = V_PEAK
            v = v_reset
        else:
            v = v1
            v_rec[k] = v
    return t, v_rec, np.array(spikes, dtype=int)


def lif_rate_theory(I, tau=LIF_TAU, v_rest=LIF_VREST, v_th=LIF_VTH):
    """連続時間LIFの理論発火率 [Hz]。 I <= v_th - v_rest なら 0"""
    I = np.asarray(I, dtype=float)
    thr = v_th - v_rest
    out = np.zeros_like(I)
    m = I > thr
    out[m] = 1000.0 / (tau * np.log(I[m] / (I[m] - thr)))
    return out


def rate_from_spikes(spike_idx, dt=DT):
    """ISI の平均から発火率 [Hz]。発火が2回未満なら 0"""
    if len(spike_idx) < 2:
        return 0.0
    isi = np.diff(spike_idx) * dt
    return 1000.0 / isi.mean()


# ======================================================================
# 固定小数点 (RTL とビット一致)
# ======================================================================
def _chk(x: int, name: str) -> int:
    assert -(1 << 31) <= x < (1 << 31), f"32bit overflow in {name}: {x}"
    return x


def mulq(a: int, b: int) -> int:
    """(a*b) >>> 16 (床)。serial_mul.sv と同じ。"""
    return _chk((a * b) >> FRAC, "mulq")


def preset_params(preset: str):
    """(A, B, C, D) in Q16.16"""
    a, b, c, d = PRESETS[preset]
    return q(a), q(b), c << FRAC, d << FRAC


def izh_step(v, u, I, A, B, C, D):
    vv = mulq(v, v)
    t1 = mulq(vv, Q_K004)
    bv = mulq(B, v)
    du = mulq(A, _chk(bv - u, "bv-u"))
    dv = _chk(t1 + v + (v << 2) + Q_C140 - u + I, "dv")
    v1 = _chk(v + (dv >> IZH_SHIFT), "v1")
    u1 = _chk(u + (du >> IZH_SHIFT), "u1")
    if v1 >= Q_V_PEAK:
        return C, _chk(u1 + D, "u"), Q_V_PEAK, 1
    return v1, u1, v1, 0


def lif_step(v, u, I):
    dv = _chk(Q_LIF_VREST - v + I, "dv")
    v1 = _chk(v + (dv >> LIF_SHIFT), "v1")
    if v1 >= Q_LIF_VTH:
        return Q_LIF_VRESET, u, Q_V_PEAK, 1
    return v1, u, v1, 0


def fixed_run(mode: int, preset: str, I_q):
    """I_q: Q16.16 整数のリスト。 return [(v_rec, u, spike), ...]  (RTL の1ステップごとの出力)"""
    A, B, C, D = preset_params(preset)
    v = Q_V_INIT
    u = -65 * B                     # = (B * v0) >> 16 と厳密に一致
    out = []
    for I in I_q:
        if mode:
            v, u, v_rec, sp = lif_step(v, u, I)
        else:
            v, u, v_rec, sp = izh_step(v, u, I, A, B, C, D)
        out.append((v_rec, u, sp))
    return out


def step_current_q(n_steps: int, t_on_step: int, I_q_on: int):
    return [0 if k < t_on_step else I_q_on for k in range(n_steps)]


def step_current(T, dt, t_on, amp):
    N = int(round(T / dt))
    t = np.arange(N) * dt
    return np.where(t >= t_on, float(amp), 0.0)


# RTL の preset_rom.sv と一致していること
RTL_PRESET_ROM = {
    "RS": (1311, 13107, -4259840, 524288),
    "IB": (1311, 13107, -3604480, 262144),
    "CH": (1311, 13107, -3276800, 131072),
    "FS": (6554, 13107, -4259840, 131072),
}

if __name__ == "__main__":
    for name in PRESETS:
        assert preset_params(name) == RTL_PRESET_ROM[name], name
    assert Q_K004 == 2621
    print("preset constants OK")
