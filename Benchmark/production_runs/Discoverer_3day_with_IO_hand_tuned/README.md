# Discoverer+ 3-Day Hand-Tuned Production Runs

This tree is separate from the baseline 3-day production tree and uses a Discoverer+-specific topology-aware per-rank launcher.

The topology mapping is based on node introspection run:

```text
/valhalla/projects/ehpc-ben-2026b06-085/tchristian/work/RegCM/Discoverer_node_introspection/runs/179466_dgx1_8gpu_initial_openacc_probe
```

## Scope

Included run directories:

- `2gpu_2proc`
- `4gpu_4proc`
- `8gpu_8proc`
- `12gpu_12proc`
- `14gpu_14proc`

The `1gpu` case is omitted because the current single-rank configuration repeatedly hits the known `radinp` accelerator fatal error. The `16gpu` and `32gpu` cases are omitted because they are not feasible with the current visible Discoverer+ allocation and GRES layout.

## Topology Mapping

Each MPI rank controls one GPU. The wrapper maps local ranks to GPU, CPU cores, NUMA node, and nearest active HCA:

| Local rank | GPU | CPU set | NUMA | HCA |
|---:|---:|---|---:|---|
| 0 | 0 | `0-1` | 0 | `mlx5_0:1` |
| 1 | 1 | `2-3` | 0 | `mlx5_3:1` |
| 2 | 2 | `4-5` | 0 | `mlx5_4:1` |
| 3 | 3 | `6-7` | 0 | `mlx5_5:1` |
| 4 | 4 | `56-57` | 1 | `mlx5_6:1` |
| 5 | 5 | `58-59` | 1 | `mlx5_9:1` |
| 6 | 6 | `60-61` | 1 | `mlx5_10:1` |
| 7 | 7 | `62-63` | 1 | `mlx5_11:1` |

NIC pinning defaults to `auto`, which enables `UCX_NET_DEVICES` only for multi-node jobs. To force or disable it:

```bash
export REGCM_ENABLE_NIC_PINNING=1
export REGCM_ENABLE_NIC_PINNING=0
```

Optional controls are available but disabled by default:

```bash
export REGCM_ENABLE_UCX_TUNING=1
export REGCM_ENABLE_ACC_POOL=1
```

## Submission

Submit from the desired run directory:

```bash
sbatch submit.job
```

All submit scripts request exclusive nodes so that the explicit CPU binding in the topology-aware wrapper is valid and reproducible.

## Output Targets

Each run writes to a unique scratch target:

- `production_3day_hand_tuned_2gpu/output`
- `production_3day_hand_tuned_4gpu/output`
- `production_3day_hand_tuned_8gpu/output`
- `production_3day_hand_tuned_12gpu/output`
- `production_3day_hand_tuned_14gpu/output`
