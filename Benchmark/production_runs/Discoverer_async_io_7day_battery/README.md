# Discoverer+ Async-I/O Battery: EURR-3 7 Days, 8 GPUs

This battery uses the same instrumented async-NetCDF `mem:managed` executable, seven-day namelist, input data, MPI layout, OpenMP setting, and GPU mapping for every arm. Jobs are submitted sequentially and pinned to `dgx1` to reduce system variability.

## Matrix

| Run | `RCM_ASYNC_OUTPUT_GB` | `RCM_BDYIN_PREFETCH_STEPS` | Purpose |
|---|---:|---:|---|
| `sync_control` | 0 | 0 | Synchronous baseline |
| `writes_only` | 4 | 0 | Isolate deferred output writes |
| `prefetch_1` | 4 | 1 | Add minimal boundary prefetch |
| `prefetch_15` | 4 | 15 | Test Everett's benchmark prefetch depth |
| `prefetch_20` | 4 | 20 | Test Everett's practical recommendation |
| `buffer_3_prefetch_15` | 3 | 15 | Compare 3 GiB against 4 GiB at depth 15 |

Each run writes to a matching directory under `scratch/EURR3/output_from_runs/async_io_battery_7day_8gpu/`.

## Runtime Validation

The executable reports `ASYNC_NETCDF enabled`, `worker_running`, effective `buffer_gib`, and `first_error`. The synchronous arm should report `enabled=F`; all other arms should report an active output worker with no initialization error.

## Submission

Each directory contains a `submit.job`. Submit the jobs as a sequential dependency chain so the runs do not contend with one another.

| Order | Run | Job |
|---:|---|---:|
| 1 | `sync_control` | `182781` |
| 2 | `writes_only` | `182782` |
| 3 | `prefetch_1` | `182783` |
| 4 | `prefetch_15` | `182784` |
| 5 | `prefetch_20` | `182785` |
| 6 | `buffer_3_prefetch_15` | `182786` |

## Results

All six jobs completed successfully on `dgx1`. Every error log was empty and every arm produced approximately 424 GB.

| Run | Job | Model elapsed | Reduction vs. control | Simulated days/hour |
|---|---:|---:|---:|---:|
| `sync_control` | `182781` | 3112.341 s | baseline | 8.10 |
| `writes_only` | `182782` | 2799.777 s | 10.04% | 9.00 |
| `prefetch_1` | `182783` | 2797.323 s | 10.12% | 9.01 |
| `prefetch_15` | `182784` | 2782.433 s | 10.60% | 9.06 |
| `prefetch_20` | `182785` | 2780.474 s | 10.66% | 9.06 |
| `buffer_3_prefetch_15` | `182786` | 2805.567 s | 9.86% | 8.98 |

The runtime diagnostics confirmed that the control was disabled and every async output worker started successfully with the requested 3 or 4 GiB buffer and `first_error=0`. Deferred writes again account for nearly all of the improvement. The nominally fastest configuration was 4 GiB with a 20-step prefetch, but it was only 19.303 seconds, or 0.69%, faster than writes-only. The 3 GiB buffer with a 15-step prefetch was 0.21% slower than writes-only while reserving less pinned memory.

These are single measurements executed in fixed order. Differences among the async arms remain small enough that repeated, order-balanced runs would be required before selecting a prefetch depth based on performance.

## Storage Cleanup

After completion and timing validation, all 198 generated NetCDF files, 33 per arm, were deleted from the six scratch output directories. The cleanup reduced the battery output tree from approximately 2.5 TB to 220 KB and increased available `/valhalla` capacity from 934 GB to 3.4 TB. The run directories, namelist, launch and submission scripts, symlinks, README, and all Slurm logs were retained.

## Next Directions

1. Complete job `183194`, the pending seven-day validation of the best NUMA-pool configuration with `OMP_NUM_THREADS=4`, and compare it with the original eight-GPU baseline job `179001` at 3057.76 seconds.
2. Run a controlled three-day A/B comparison combining the validated NUMA-pool and `OMP_NUM_THREADS=4` compute configuration with 4 GiB deferred asynchronous writes. Validate the combination at three days before committing storage and allocation time to a seven-day run.
3. Repeat writes-only and prefetch-20 measurements in alternating order. Their 0.69% difference in this battery is too small to separate reliably from run-to-run variability using one fixed-order sample.
4. Compare synchronous and asynchronous NetCDF outputs numerically, including restart files and representative ATM, RAD, SRF, and CLM variables, before treating asynchronous I/O as production-ready.
5. Exercise asynchronous-I/O robustness and portability paths: abrupt termination and queue draining, CPU-only builds, alternate compiler or NetCDF configurations, and repeated file creation and closure.

The immediate sequence is to evaluate job `183194`, run the three-day combined compute-plus-async A/B, and retain only logs and comparison summaries after validating generated outputs.
