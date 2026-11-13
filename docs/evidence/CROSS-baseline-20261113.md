# 交叉基线证据（2026-11-13）

| 项 | 值 |
|---|---|
| 包 | `media-libs/libpng` |
| 上游固定点 | `7ef5852` |
| 上游构建系统 | cmake |
| 目标 | `riscv64-linux-gnu`，`-march=rv64gc`（无向量，纯基线） |
| 执行方式 | `qemu-riscv64 -L /usr/riscv64-linux-gnu`（功能性，**无性能意义**） |
| 镜像 | `rvv-cross:1`（Ubuntu 24.04 + gcc 13.3 riscv64 + qemu-user + meson/ninja） |

## 命令

```bash
cd $(pwd)/libpng-rvv && ./scripts/cross-baseline.sh
```

## 结果

```
riscv64 : size=131x99 png=28995 fnv_png=3bd158cdb34ca865 fnv_px=7322844870c2c46b
native  : size=131x99 png=28936 fnv_png=cf1f4f33c6a93f61 fnv_px=7322844870c2c46b
```

判定：**像素一致、PNG 字节不同**

## 说明

- 基线（`baseline/`）按上游原样编译，`RVV_KERNELS` 关闭；`src/` 此时内容与 `baseline` 相同，
  因此 A/B 尚未产生真实差异，本步只证明**交叉编译链路与目标执行链路可用**。
- qemu 下的运行结果只用于功能回归；任何性能数字都不从这里取（真机 `pair_bench.sh` 才是 G3 判据）。
