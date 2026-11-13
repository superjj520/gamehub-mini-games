#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
轮盘倍数模块 —— 数值分析脚本
=========================================
规则（待分析的现状版）：
  · 6 弹膛装 B 颗实弹，B = 2/3/4/5
  · 每人 L 条命，L = 3/3/2/1
  · 轮到你：可「转轮」（重装 + 倍数归 1）或「开枪」
  · 空枪：得分 += M，然后 M += 1
  · 中弹：命 -1，得分 -= 2M，M = 1，抽惩罚卡
  · 命归 0 出局（保留座位、跳过回合），只剩 1 人时结束，最高分者胜

弹巢模型：物理正确的无放回——6 个膛按顺序转过去，打空的膛不会再来。
命中率 p = 剩余实弹 / 剩余膛位。

运行：python3 scripts/roulette-economy-sim.py
"""

import random
import statistics
from math import comb
from itertools import combinations
from collections import defaultdict

N_CH = 6
DIFFS = [(2, 3), (3, 3), (4, 2), (5, 1)]   # (B, L) 现状
C_NOW = 2.0                                  # 现状：中弹扣 2M

# ---- 推荐参数（见 docs/product/roulette-multiplier-economy-analysis.md §6）
PRESET = {          # B -> (L, c, x)
    2: (3, 1.20, 1.0),
    3: (3, 0.75, 1.6),
    4: (3, 0.40, 2.4),
    5: (3, 0.10, 3.5),
}


def hr(t):
    print("\n" + "=" * 76)
    print(t)
    print("=" * 76)


# ------------------------------------------------------------ 1. 解析

def tri(n):
    return n * (n + 1) // 2


def seg_pmf(B):
    """满膛、M=1 时，第一个实弹出现在第 a+1 枪的概率。"""
    return [(a, comb(N_CH - a - 1, B - 1) / comb(N_CH, B))
            for a in range(0, N_CH - B + 1)]


def seg_ev(B, c=C_NOW):
    """整段期望：满膛 M=1 起，一直开枪直到中弹。"""
    return sum(p * (tri(a) - c * (a + 1)) for a, p in seg_pmf(B))


def c_seg_max(B):
    """整段打平的最大扣分系数 c*（段期望为 0 的 c）。"""
    num = sum(p * tri(a) for a, p in seg_pmf(B))
    den = sum(p * (a + 1) for a, p in seg_pmf(B))
    return num / den


def c_shot_max(B):
    """单枪打平的最大扣分系数：M(1-(1+c)p)=0 → c=(6-B)/B。"""
    return (N_CH - B) / B


def tier_c(B, target=5.4):
    """分档扣分系数：让首枪 EV = (1 - target/6)·M，即目标系数下统一。
    target=5.4 → 首枪 EV = +0.1M；target=4.8 → +0.2M；target=6 → 恰好 0。"""
    return max(0.0, target / B - 1.0)


def cycle_stats(B, c=C_NOW):
    """打满 6 膛一整轮：枚举全部 C(6,B) 种实弹排布，返回 (总收益, 总扣分)。
    注意最后一个实弹之后可能还有一段「免费空枪」——它不领罚。"""
    g_sum = l_sum = 0.0
    cfg = list(combinations(range(N_CH), B))
    for pos in cfg:
        prev = -1
        g = l = 0.0
        M = 1
        for p in pos:
            run = p - prev - 1
            g += sum(M + i for i in range(run))
            M += run
            l += c * M
            M = 1
            prev = p
        tail = N_CH - 1 - prev
        g += sum(M + i for i in range(tail))
        g_sum += g
        l_sum += l
    n = len(cfg)
    return g_sum / n, l_sum / n


# ------------------------------------------------------------ 2. 模拟

def simulate(n_players, B, L, strategy="always", c=C_NOW, card=0.0,
             bank=None, hit_cap=None, spin_cap=None,
             max_shots=4000, max_turns=4000, turn_budget=0, seed=0):
    """bank: 转轮兑现系数（None=不兑现）。hit_cap: 单次中弹扣分上限。
    spin_cap: 连续转轮上限，超过必须开枪。"""
    rng = random.Random(seed)
    P = [dict(lives=L, score=0.0, alive=True, shots=0, hits=0,
              turns=0, spins=0, seat=i) for i in range(n_players)]
    zero = 0.0

    def reload():
        ch = [1] * B + [0] * (N_CH - B)
        rng.shuffle(ch)
        return ch, 0

    ch, ptr = reload()
    M, k, r = 1, 0, B
    shots = cur = 0
    consec = 0

    turns_total = 0
    while True:
        alive = sum(1 for p in P if p["alive"])
        if turn_budget:
            if all((not p["alive"]) or p["turns"] >= turn_budget for p in P):
                break
        elif alive <= 1:
            break
        if shots >= max_shots or turns_total >= max_turns:
            break
        turns_total += 1
        if not P[cur]["alive"] or (turn_budget and P[cur]["turns"] >= turn_budget):
            if turn_budget and all((not p["alive"]) or p["turns"] >= turn_budget
                                   for p in P):
                break
            cur = (cur + 1) % n_players
            continue

        pl = P[cur]
        pl["turns"] += 1

        if strategy == "always":
            shoot = True
        elif strategy == "chase":
            # 人类策略：追倍数——M>=2 就开，否则转轮
            shoot = M >= 2
            if spin_cap and consec >= spin_cap:
                shoot = True
        elif strategy == "random":
            shoot = rng.random() < r / (N_CH - k)   # 假装不懂概率
        else:
            p = r / (N_CH - k)
            shoot = M * (1 - (1 + c) * p) > 0
            if spin_cap and consec >= spin_cap:
                shoot = True

        if not shoot:
            pl["spins"] += 1
            consec += 1
            if bank:
                pl["score"] += int(M * bank)
            M = 1
            ch, ptr = reload()
            k, r = 0, B
            cur = (cur + 1) % n_players
            continue

        consec = 0
        pl["shots"] += 1
        shots += 1

        if ch[ptr] == 0:
            pl["score"] += M
            M += 1
        else:
            pl["hits"] += 1
            pl["lives"] -= 1
            loss = c * M
            if hit_cap is not None:
                loss = min(loss, hit_cap)
            pl["score"] -= loss + card
            M = 1
            r -= 1
            if pl["lives"] <= 0:
                pl["alive"] = False

        ptr += 1
        k += 1
        if k >= N_CH:
            ch, ptr = reload()
            k, r = 0, B
        cur = (cur + 1) % n_players

    sc = [p["score"] for p in P]
    order = sorted(range(n_players), key=lambda i: -sc[i])
    return dict(shots=shots, scores=sc, actions=[p["turns"] for p in P],
                rank={i: pos + 1 for pos, i in enumerate(order)},
                winner=order[0], win=sc[order[0]], worst=min(sc),
                total=sum(sc), neg=sum(1 for s in sc if s < 0),
                never=sum(1 for p in P if p["turns"] == 0))


def batch(n, B, L, runs=3000, **kw):
    R = [simulate(n, B, L, seed=s, **kw) for s in range(runs)]
    q = lambda key, f=statistics.median: f(r[key] for r in R)
    seat_sc = [statistics.mean(r["scores"][i] for r in R) for i in range(n)]
    seat_rk = [statistics.mean(r["rank"][i] for r in R) for i in range(n)]
    seat_ac = [statistics.mean(r["actions"][i] for r in R) for i in range(n)]
    seat_wr = [sum(1 for r in R if r["winner"] == i) / runs for i in range(n)]
    return dict(
        shots=q("shots"), win=q("win", statistics.mean),
        worst=q("worst", statistics.mean), total=q("total", statistics.mean),
        neg=q("neg", statistics.mean) / n,
        act_mean=statistics.mean(seat_ac), act_max=max(seat_ac),
        act_min=min(seat_ac), never=statistics.mean(r["never"] for r in R),
        seat_sc=seat_sc, seat_rk=seat_rk, seat_ac=seat_ac, seat_wr=seat_wr,
    )


# ------------------------------------------------------------ 3. 主程序

def main():
    hr("【1】单枪期望与两个临界扣分系数")
    print("单枪 EV = M·(1 - (1+c)·p)，p = 剩余实弹/剩余膛位")
    print("判据：p < 1/(1+c) = 1/3 才值得开枪（c=2 时）\n")
    print(f"{'B':>2} {'L':>2} {'初始p':>7} {'单枪EV(M=1)':>12} "
          f"{'c_shot_max':>11} {'c_seg_max':>10} {'整段EV(c=2)':>12}")
    for B, L in DIFFS:
        p = B / N_CH
        print(f"{B:>2} {L:>2} {p:>7.3f} {1*(1-(1+C_NOW)*p):>12.3f} "
              f"{c_shot_max(B):>11.3f} {c_seg_max(B):>10.3f} {seg_ev(B):>12.3f}")
    print("\nc_shot_max：让「单枪」不亏的最大扣分系数 = (6-B)/B")
    print("c_seg_max ：让「一整段（打到中弹）」不亏的最大扣分系数")

    hr("【2】逐 a 明细：从 M=1 满膛开枪，前 a 枪空、第 a+1 枪中弹")
    for B, L in DIFFS:
        print(f"\n--- B={B}  L={L}  整段EV(c=2)={seg_ev(B):+.3f}   "
              f"整段EV(c=1)={seg_ev(B, 1.0):+.3f}")
        print(f"{'a':>2} {'P(a)':>7} {'得分':>6} {'扣分c=2':>8} {'净c=2':>7} "
              f"{'扣分c=1':>8} {'净c=1':>7}")
        for a, pr in seg_pmf(B):
            g = tri(a)
            print(f"{a:>2} {pr:>7.3f} {g:>6.0f} {2*(a+1):>8.0f} "
                  f"{g-2*(a+1):>7.0f} {1*(a+1):>8.0f} {g-(a+1):>7.0f}")

    hr("【3】打满一整轮弹巢（6 枪）全桌净变化")
    print("注意：最后一个实弹之后的那段空枪是「免费分」——不领罚。\n")
    print(f"{'B':>2} {'空枪总收益':>10} {'中弹总扣分':>10} {'净':>8} "
          f"{'每枪均值':>9} {'c=1 净':>9}")
    for B, L in DIFFS:
        g, l = cycle_stats(B, C_NOW)
        g1, l1 = cycle_stats(B, 1.0)
        print(f"{B:>2} {g:>10.3f} {l:>10.3f} {g-l:>8.3f} "
              f"{(g-l)/N_CH:>9.3f} {g1-l1:>9.3f}")

    hr("【4】倍数 M 的轨迹：M 涨 = 命中率涨，两者同步恶化")
    print(f"{'B':>2} " + "".join(f"{'M='+str(m):>10}" for m in range(1, 7)))
    for B, L in DIFFS:
        row = f"{B:>2} "
        for j in range(6):
            M = 1 + j
            n = N_CH - j
            row += f"{'(%.2f) %+.1f' % (B/n, M*(1-3*B/n)):>10}" if n >= B else f"{'—':>10}"
        print(row)
    print("括号内 = 该枪命中率，右侧 = 单枪 EV。M 越大 EV 越负，没有拐点。")

    hr("【5】该不该开枪：p < 1/3 判定表")
    print(f"{'r\\k':>4}" + "".join(f"{k:>8}" for k in range(N_CH)))
    for r in range(6, -1, -1):
        row = f"{r:>4}"
        for k in range(N_CH):
            n = N_CH - k
            if r > n:
                row += f"{'—':>8}"
            else:
                p = r / n
                m = "○" if p < 1/3 - 1e-9 else ("=" if abs(p-1/3) < 1e-9 else "×")
                row += f"{'%.2f%s' % (p, m):>8}"
        print(row)
    print("r=剩余实弹  k=本弹巢已开枪数")
    print("○ 可开  = 打平  × 该转轮")
    print("→ 只有 r≤1 且 k≤2（或 r=0）时才该开枪。其余一律转轮。")

    hr("【6】局长与座位偏差（策略：永远开枪）")
    print("理论：总枪数 ≈ 6(n-1)L/B，人均行动 ≈ 6L(n-1)/(Bn)\n")
    for n in (2, 4, 8):
        print(f"### {n} 人")
        print(f"{'B/L':>5} {'枪数':>5} {'理论':>6} {'人均行动':>8} {'理论':>6} "
              f"{'未出手者':>8} {'冠军分':>7} {'最差分':>7} {'净和':>7} {'负分率':>7}")
        for B, L in DIFFS:
            r = batch(n, B, L, runs=2500)
            th_shots = 6 * (n - 1) * L / B
            th_act = 6 * L * (n - 1) / (B * n)
            print(f"{B}/{L:<3} {r['shots']:>5.0f} {th_shots:>6.1f} {r['act_mean']:>8.2f} "
                  f"{th_act:>6.2f} {r['never']*100:>7.1f}% {r['win']:>7.2f} "
                  f"{r['worst']:>7.2f} {r['total']:>7.2f} {r['neg']*100:>6.1f}%")
        print()

    hr("【7】座位偏差：各座平均行动次数 / 平均名次 / 夺冠率")
    for n in (2, 4, 8):
        print(f"\n### {n} 人")
        for B, L in DIFFS:
            r = batch(n, B, L, runs=2500)
            print(f"{B}/{L}  行动 " + " ".join(f"{v:>5.2f}" for v in r['seat_ac']))
            print(f"{'':>4}  名次 " + " ".join(f"{v:>5.2f}" for v in r['seat_rk']))
            print(f"{'':>4}  夺冠 " + " ".join(f"{v*100:>4.1f}%" for v in r['seat_wr']))
            print()

    hr("【8】纯理性策略 = 死锁验证")
    for B, L in DIFFS:
        p = B / N_CH
        print(f"B={B}  初始单枪EV={1*(1-3*p):+.3f} → "
              f"{'开枪' if 1-3*p > 0 else '转轮'}")
    r = batch(4, 3, 3, runs=20, strategy="ev")
    print(f"模拟（4人 B=3 纯EV策略，4000枪上限）：{r['shots']:.0f} 枪，"
          f"人均行动 {r['act_mean']:.1f}，未出手者 {r['never']*100:.0f}%")

    hr("【9】修正方案实测对比（策略=always，上限估计）")
    plans = [
        ("现状 c=2", dict(c=2.0)),
        ("c=1", dict(c=1.0)),
        ("c 分难度", dict(c=1.2)),
        ("+转轮兑现", dict(c=1.2, bank=0.5)),
        ("+兑现+上限6", dict(c=1.2, bank=0.5, hit_cap=6)),
        ("+兑现+强制开", dict(c=1.2, bank=0.5, hit_cap=6, spin_cap=2)),
    ]
    for n in (4, 8):
        print(f"\n### {n} 人 · B=3 L=3")
        print(f"{'方案':>14} {'枪数':>6} {'人均行动':>8} {'冠军分':>8} "
              f"{'最差分':>8} {'净和':>8} {'负分率':>7} {'夺冠偏差':>9}")
        for name, kw in plans:
            r = batch(n, 3, 3, runs=2500, **kw)
            bias = max(r['seat_wr']) - min(r['seat_wr'])
            print(f"{name:>14} {r['shots']:>6.0f} {r['act_mean']:>8.2f} "
                  f"{r['win']:>8.2f} {r['worst']:>8.2f} {r['total']:>8.2f} "
                  f"{r['neg']*100:>6.1f}% {bias*100:>8.1f}%")

    hr("【10】死锁修复：理性策略下的实际可玩性（B=3 L=3 · 每格 2000 局）")
    print("纯 EV 策略在原版 = 0 枪死锁。以下看每个补丁能否让枪声真的响起来。\n")
    fixes = [
        ("原版（无补丁）", dict(c=2.0)),
        ("c=1", dict(c=1.0)),
        ("c=1 + 强制开(2转)", dict(c=1.0, spin_cap=2)),
        ("c=1 + 兑现0.5", dict(c=1.0, bank=0.5)),
        ("c=1 + 兑现0.5 + 强制开", dict(c=1.0, bank=0.5, spin_cap=2)),
        ("c=1 + 兑现1.0 + 强制开", dict(c=1.0, bank=1.0, spin_cap=2)),
    ]
    for n in (4, 8):
        print(f"### {n} 人")
        print(f"{'方案':>22} {'枪数':>7} {'人均行动':>9} {'冠军分':>8} "
              f"{'最差分':>8} {'净和':>8} {'负分率':>7}")
        for name, kw in fixes:
            r = batch(n, 3, 3, runs=2000, strategy="ev", max_turns=600, **kw)
            print(f"{name:>22} {r['shots']:>7.0f} {r['act_mean']:>9.2f} "
                  f"{r['win']:>8.2f} {r['worst']:>8.2f} {r['total']:>8.2f} "
                  f"{r['neg']*100:>6.1f}%")
        print()

    hr("【11】分档扣分系数：让每一档的「首枪 EV」统一")
    print("目标：首枪 EV = +0.1·M（玩家一上来就有开枪动机，但整轮不失控）")
    print("公式 c_B = 5.4/B - 1，下限 0\n")
    print(f"{'B':>2} {'L':>2} {'c_B':>6} {'首枪EV':>8} {'整轮净':>8} "
          f"{'单枪阈值c':>10} {'整段阈值c':>10}")
    for B, L in DIFFS:
        ct = tier_c(B, 5.4)
        g, l2 = cycle_stats(B, 2.0)
        sm = l2 / 2.0                       # ΣM
        print(f"{B:>2} {L:>2} {ct:>6.2f} {1 - (1+ct)*B/6:>8.3f} "
              f"{g - ct*sm:>8.3f} {c_shot_max(B):>10.3f} {c_seg_max(B):>10.3f}")

    hr("【12】纯理性（EV 策略）在分档 c 下能否打破死锁 · 2000 局")
    print(f"{'人数':>4} {'B/L':>5} {'c_B':>6} {'枪数':>7} {'人均行动':>9} "
          f"{'冠军分':>8} {'最差分':>8} {'净和':>8} {'负分率':>7} {'夺冠偏差':>9}")
    for n in (2, 4, 8):
        for B, L in DIFFS:
            ct = tier_c(B, 5.4)
            r = batch(n, B, L, runs=2000, strategy="ev", c=ct, max_turns=400)
            bias = max(r['seat_wr']) - min(r['seat_wr'])
            print(f"{n:>4} {B}/{L:<3} {ct:>6.2f} {r['shots']:>7.0f} "
                  f"{r['act_mean']:>9.2f} {r['win']:>8.2f} {r['worst']:>8.2f} "
                  f"{r['total']:>8.2f} {r['neg']*100:>6.1f}% {bias*100:>8.1f}%")

    hr("【13】三套扣分方案 × 三种人数（B=3 L=3，策略=ev，2000 局）")
    print("看「纯理性的枪声量」和「分数是否还在地上趴着」\n")
    schemes = [("现状 c=2", 2.0), ("c=1", 1.0), ("分档 c=0.8", 0.8),
               ("分档 c=0.6", 0.6)]
    print(f"{'人数':>4} {'方案':>12} {'枪数':>7} {'人均行动':>9} {'冠军分':>8} "
          f"{'最差分':>8} {'净和':>8} {'负分率':>7}")
    for n in (2, 4, 8):
        for name, cv in schemes:
            r = batch(n, 3, 3, runs=2000, strategy="ev", c=cv,
                      spin_cap=2, max_turns=400)
            print(f"{n:>4} {name:>12} {r['shots']:>7.0f} {r['act_mean']:>9.2f} "
                  f"{r['win']:>8.2f} {r['worst']:>8.2f} {r['total']:>8.2f} "
                  f"{r['neg']*100:>6.1f}%")
        print()

    hr("【14】B=5/L=1 是崩坏档：改 L 之后座位偏差变化")
    print(f"{'人数':>4} {'L':>3} {'枪数':>6} {'人均行动':>9} {'未出手者':>8} "
          f"{'最差座行动':>10} {'夺冠偏差':>9}")
    for n in (2, 4, 8):
        for L in (1, 2, 3):
            r = batch(n, 5, L, runs=2000, strategy="always")
            print(f"{n:>4} {L:>3} {r['shots']:>6.0f} {r['act_mean']:>9.2f} "
                  f"{r['never']*100:>7.1f}% {r['act_min']:>10.2f} "
                  f"{(max(r['seat_wr'])-min(r['seat_wr']))*100:>8.1f}%")
        print()

    hr("【15】结束条件换成「每人固定 A 次行动」——座位偏差归零验证")
    print("规则：每人最多 A 次行动，出局即作废；全员用尽或出局后结束。")
    print("对比现状（只剩 1 人结束）\n")
    print(f"{'人数':>4} {'B/L':>5} {'A':>3} {'枪数':>6} {'人均行动':>9} "
          f"{'未出手者':>8} {'最差座行动':>10} {'夺冠偏差':>9} {'净和':>8}")
    for n in (2, 4, 8):
        for B, L in DIFFS:
            for A in (2, 3):
                r = batch(n, B, L, runs=2000, strategy="ev",
                          c=tier_c(B, 5.4), turn_budget=A)
                print(f"{n:>4} {B}/{L:<3} {A:>3} {r['shots']:>6.0f} "
                      f"{r['act_mean']:>9.2f} {r['never']*100:>7.1f}% "
                      f"{r['act_min']:>10.2f} "
                      f"{(max(r['seat_wr'])-min(r['seat_wr']))*100:>8.1f}% "
                      f"{r['total']:>8.2f}")
        print()

    hr("【16】最终推荐参数下的完整体检（分档 c + 每人 A 次行动）")
    REC_A = 3
    print(f"c_B = max(0, 5.4/B-1)；A = {REC_A}；结束=行动预算\n")
    for n in (2, 4, 8):
        print(f"### {n} 人")
        print(f"{'B/L':>5} {'c_B':>5} {'枪数':>6} {'人均行动':>9} {'冠军分':>7} "
              f"{'最差分':>7} {'净和':>7} {'负分率':>7} {'夺冠偏差':>9}")
        for B, L in DIFFS:
            ct = tier_c(B, 5.4)
            r = batch(n, B, L, runs=2000, strategy="ev", c=ct,
                      turn_budget=REC_A)
            print(f"{B}/{L:<3} {ct:>5.2f} {r['shots']:>6.0f} {r['act_mean']:>9.2f} "
                  f"{r['win']:>7.2f} {r['worst']:>7.2f} {r['total']:>7.2f} "
                  f"{r['neg']*100:>6.1f}% "
                  f"{(max(r['seat_wr'])-min(r['seat_wr']))*100:>8.1f}%")
        print()

    hr("【17】B=5 换命数：L=1 是崩坏根因")
    print("条件：分档 c + 每人 A=3 次行动预算\n")
    print(f"{'人数':>4} {'L':>3} {'c_B':>5} {'枪数':>6} {'人均行动':>9} {'冠军分':>7} "
          f"{'最差分':>7} {'净和':>7} {'负分率':>7} {'夺冠偏差':>9}")
    for n in (2, 4, 8):
        for L in (1, 2, 3):
            ct = tier_c(5, 5.4)
            r = batch(n, 5, L, runs=2000, strategy="ev", c=ct, turn_budget=3)
            print(f"{n:>4} {L:>3} {ct:>5.2f} {r['shots']:>6.0f} {r['act_mean']:>9.2f} "
                  f"{r['win']:>7.2f} {r['worst']:>7.2f} {r['total']:>7.2f} "
                  f"{r['neg']*100:>6.1f}% "
                  f"{(max(r['seat_wr'])-min(r['seat_wr']))*100:>8.1f}%")
        print()

    hr("【18】分档目标档位对比：首枪 EV 定 +0.1 / 0 / -0.1 的量级差异")
    print("B=3 L=3，4 人，A=3 行动预算，策略=ev\n")
    print(f"{'target':>8} {'c_B':>6} {'枪数':>6} {'冠军分':>8} {'最差分':>8} "
          f"{'净和':>8} {'负分率':>7} {'夺冠偏差':>9}")
    for tgt in (4.8, 5.4, 6.0, 6.6):
        ct = tier_c(3, tgt)
        r = batch(4, 3, 3, runs=2500, strategy="ev", c=ct, turn_budget=3)
        print(f"{tgt:>8.1f} {ct:>6.2f} {r['shots']:>6.0f} {r['win']:>8.2f} "
              f"{r['worst']:>8.2f} {r['total']:>8.2f} {r['neg']*100:>6.1f}% "
              f"{(max(r['seat_wr'])-min(r['seat_wr']))*100:>8.1f}%")
    print("\ntarget 越小 = 首枪 EV 越正 = 分数越通胀 = 越好玩但越没张力")


    hr("【19】推荐参数 PRESET 完整体检（本文档 §6.7 的数据来源）")
    print("L 统一为 3；c 分档；结束 = 只剩 1 人；策略 = 理性 EV；各 2000 局\n")
    for n in (8, 4, 2):
        print(f"### {n} 人")
        print(f"{'B/L':>5} {'c':>5} {'枪数':>6} {'人均行动':>9} {'冠军分':>8} "
              f"{'最差分':>8} {'净和':>8} {'负分率':>7} {'夺冠偏差':>9}")
        for B in (2, 3, 4, 5):
            L, c, _x = PRESET[B]
            r = batch(n, B, L, runs=2000, strategy="ev", c=c, max_turns=900)
            print(f"{B}/{L:<3} {c:>5.2f} {r['shots']:>6.0f} {r['act_mean']:>9.2f} "
                  f"{r['win']:>8.2f} {r['worst']:>8.2f} {r['total']:>8.2f} "
                  f"{r['neg']*100:>6.1f}% "
                  f"{(max(r['seat_wr'])-min(r['seat_wr']))*100:>8.1f}%")
        print()

    hr("【20】边界复现：c 恰等于阈值 (6-B)/B 时必定死锁")
    print(f"{'B':>2} {'c=(6-B)/B':>10} {'首枪EV':>8} {'枪数':>6} {'人均行动':>9} {'判定':>8}")
    for B in (2, 3, 4, 5):
        ct = c_shot_max(B)
        r = batch(8, B, PRESET[B][0], runs=300, strategy="ev", c=ct, max_turns=400)
        verdict = "死锁" if r["shots"] == 0 else "正常"
        print(f"{B:>2} {ct:>10.2f} {1-(1+ct)*B/6:>8.3f} {r['shots']:>6.0f} "
              f"{r['act_mean']:>9.2f} {verdict:>8}")
    print("\n→ c 必须严格低于 (6-B)/B，推荐取阈值的 50~80%")


if __name__ == "__main__":
    main()
