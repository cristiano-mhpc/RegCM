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
| 0 | 0 | `+0-1` | 0 | `mlx5_0:1` |
| 1 | 1 | `+2-3` | 0 | `mlx5_3:1` |
| 2 | 2 | `+4-5` | 0 | `mlx5_4:1` |
| 3 | 3 | `+6-7` | 0 | `mlx5_5:1` |
| 4 | 4 | `+8-9` | 1 | `mlx5_6:1` |
| 5 | 5 | `+10-11` | 1 | `mlx5_9:1` |
| 6 | 6 | `+12-13` | 1 | `mlx5_10:1` |
| 7 | 7 | `+14-15` | 1 | `mlx5_11:1` |

The CPU sets use numactl's cpuset-relative `+` syntax. This is required because Slurm constrains jobs with cgroups, so physical CPU IDs from node introspection may not be visible inside the job cpuset even for exclusive allocations.

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

## Staged Benchmarking Plan

The goal is to identify which topology-aware controls help without running an unnecessarily large toggle matrix. The baseline production results in `../Discoverer_3day_with_IO` remain the reference for comparison.

### Stage 1: Hand-Tuned Baseline

Use the topology-aware wrapper with CPU/NUMA/GPU binding enabled and all extra tuning disabled:

```bash
export REGCM_ENABLE_CPU_BINDING=1
export REGCM_ENABLE_NIC_PINNING=auto
export REGCM_ENABLE_UCX_TUNING=0
export REGCM_ENABLE_ACC_POOL=0
```

Planned matrix:

- `2gpu_2proc`
- `4gpu_4proc`
- `8gpu_8proc`
- `12gpu_12proc`
- `14gpu_14proc`

Initial execution choice: start with only `8gpu_8proc` to validate the wrapper on a full single-node DGX before spending allocation on the full matrix.

Current Stage 1 result:

| Run | Job | Status at submission |
|---|---:|---|
| `8gpu_8proc` | `179837` | `COMPLETED`, RegCM elapsed `1474.89 s` (`491.63 s/day`) |

### Stage 2: Single-Toggle Tests

After Stage 1 validates the wrapper, test one tuning feature at a time on representative configurations.

Recommended first targets:

- `8gpu_8proc`: checks whether tuning hurts a full single-node run.
- `12gpu_12proc`: checks multi-node behavior with 6 ranks per node.
- `14gpu_14proc`: checks multi-node behavior with 7 ranks per node.

Variants:

| Variant | CPU binding | NIC pinning | UCX tuning | ACC pool |
|---|---:|---:|---:|---:|
| `HT-base` | 1 | auto | 0 | 0 |
| `HT-no-nic` | 1 | 0 | 0 | 0 |
| `HT-ucx` | 1 | auto | 1 | 0 |
| `HT-pool` | 1 | auto | 0 | 1 |

`HT-no-nic` is important because manual `UCX_NET_DEVICES` pinning can hurt if Open MPI/UCX would otherwise select better rails automatically.

For single-node `8gpu_8proc`, `HT-no-nic` is equivalent to `HT-base` because `REGCM_ENABLE_NIC_PINNING=auto` enables explicit `UCX_NET_DEVICES` only for multi-node jobs. The first 8-GPU Stage 2 submissions therefore cover the two meaningful single-node toggles:

| Run | Variant | Job | Status at submission |
|---|---|---:|---|
| `8gpu_8proc_ht_ucx` | `HT-ucx` | `180346` | `PENDING (Priority)` |
| `8gpu_8proc_ht_pool` | `HT-pool` | `180347` | `PENDING (Priority)` |

### Stage 3: Combination Tests

Only run combinations if Stage 2 shows a benefit or neutral behavior. Start with `12gpu_12proc` and `14gpu_14proc` before expanding to other GPU counts.

Candidate variants:

| Variant | CPU binding | NIC pinning | UCX tuning | ACC pool |
|---|---:|---:|---:|---:|
| `HT-ucx-pool` | 1 | auto | 1 | 1 |
| `HT-forced-nic-ucx` | 1 | 1 | 1 | 0 |
| `HT-all` | 1 | 1 | 1 | 1 |

### Stage 4: Final Selected Matrix

After selecting the best stable configuration, run the final matrix:

- `2gpu_2proc`
- `4gpu_4proc`
- `8gpu_8proc`
- `12gpu_12proc`
- `14gpu_14proc`

For timing claims, repeat final candidate runs at least twice for `8gpu_8proc`, `12gpu_12proc`, and `14gpu_14proc`, because the 12- and 14-GPU timings are close enough that single-run noise can be misleading.

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
- `production_3day_hand_tuned_8gpu_ht_ucx/output`
- `production_3day_hand_tuned_8gpu_ht_pool/output`
- `production_3day_hand_tuned_12gpu/output`
- `production_3day_hand_tuned_14gpu/output`
