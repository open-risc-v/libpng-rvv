# 性能与正确性日志 —— `media-libs/libpng`

每条记录必须包含：**日期 / 变更 / 内核 / 输入规模 / A / B / 比值 / 是否位精确 / 证据路径**。
没有 A/B 双数字的记录不算数。

## 基线（G2，内核关闭）

| 日期 | 构建 | 用例 | 规模 | A(ms) | B(ms) | 备注 |
|---|---|---|---|---|---|---|
|  | riscv64 |  |  |  |  |  |

```
cpu_probe（目标机）：
vlen=
vle_ticks=  vlse_ticks=  vrgather_ticks=  vsetvl_ticks=
```

## 逐轮记录（G3）

| 轮 | 日期 | 内核 | LMUL | 规模 | A(ms) | B(ms) | 收益 | 位精确 | 备注 |
|---|---|---|---|---|---|---|---|---|---|
| 1 | 2026-11-19 | filter_sub（Hillis-Steele 前缀和 + 跨块进位） | e8m4 | 2048 行 × 6144 B, bpp=3 | 7.5 | 12.9 | 1.72x | PASS | 进位必须在倍增前注入；LMUL=1 只有 9.9ms |
| 2 | 2026-11-19 | filter_up | e8m1 | 2048 行 × 6144 B | 4.1 | 4.2 | 1.02x | PASS | 纯访存带宽受限，RVV 无收益，保留（不劣化） |
| 3 | 2026-11-19 | filter_sub/up 端到端（2048×2048 RGB 解码） | — | PNG_FILTER_SUB 图 9.05 MB / UP 图 7.29 MB | 107.1 / 90.1 | 113.3 / 91.4 | 1.06x / 1.01x | PASS（chk=bd5b0d7dee2dd1fd 同） | 解码主耗时在 inflate，过滤器占比小 |

设备：<board>（<distro>, gcc 15.2.0, VLEN=256, 8 核）。
A = `-O2 -march=rv64gcv -DRVV_KERNELS=1`，B = `-O2 -march=rv64gc`，其余完全一致。

## 收敛分析（G4）

```
perf top（剩余热点，按占比排序）：
1.
2.
3.
结论：覆盖度 f=____；停止理由：____
```
