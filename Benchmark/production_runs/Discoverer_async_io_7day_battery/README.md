# Discoverer+ Async-I/O Battery: EURR-3 7 Days, 8 GPUs

This battery uses the same instrumented async-NetCDF `mem:managed` executable, seven-day namelist, input data, MPI layout, OpenMP setting, and GPU mapping for every arm. Jobs are submitted sequentially and pinned to `dgx1` to reduce system variability.

## Async-I/O Strategy

### Build and Runtime Enablement

Asynchronous NetCDF support is compile-time opt-in through `./configure --enable-async-netcdf`. The option defines `ASYNC_NETCDF`, checks for POSIX threads, adds `-pthread`, and includes the C pthread shim in the RegCM support library. A build without this option follows the normal synchronous paths. The instrumented executable used here was built with asynchronous support, OpenACC/stdpar, CLM4.5, and `mem:managed`.

Compilation only makes the feature available. `RCM_ASYNC_OUTPUT_GB` controls runtime activation:

- An unset, malformed, zero, or negative value disables the worker and preserves synchronous behavior.
- A positive value starts asynchronous operation and sets the per-process buffer reservation target in GiB.
- `RCM_BDYIN_PREFETCH_STEPS` controls boundary-input lead time. Values at or below zero disable prefetch; positive values request the next boundary up to that many model timesteps before it is needed.
- A prefetch value is not a queue depth. The implementation has one active prefetch slot and will not buffer multiple future boundaries.

The current namelist uses `do_parallel_netcdf_in=.true.`, `do_parallel_netcdf_out=.false.`, and `lsync=.false.`. This is the intended tested shape: distributed local ICBC reads with serial NetCDF output. Parallel or PnetCDF output is not part of the supported async-performance result.

### Deferred Output Writes

Each process that initializes async NetCDF creates one pthread worker. Output calls copy the caller's data into worker-owned host storage and enqueue a typed NetCDF operation. The model can then reuse its original arrays while the worker performs the disk write. For OpenACC device data, the current path first performs a synchronous device-to-host copy into pinned memory; overlap begins with the subsequent NetCDF operation, not with that copy.

Ordinary output operations remain FIFO. Writes, eligible sync operations, and closes can be queued, while file creation, opening, metadata changes, and other foreground NetCDF activity use a serialization gate shared with the worker. This protects the serial NetCDF library and gives a waiting foreground model thread priority over new worker calls.

The queue has no item-count limit. Instead, byte reservations apply backpressure when the configured buffer target is occupied. A producing model thread then waits until the worker frees storage. Consequently, buffer size affects how much output can be outstanding and whether write latency is hidden, but increasing it beyond the working set should not improve performance. A single item larger than the configured pool can use a separate pinned allocation, so `RCM_ASYNC_OUTPUT_GB` is not an absolute pinned-memory ceiling.

### Boundary-Input Prefetch

Before each model timestep, RegCM checks whether the next boundary event falls within `RCM_BDYIN_PREFETCH_STEPS * dt`. If so, each participating rank can queue reads for its local ICBC hyperslabs. The prefetched fields include surface pressure and temperature; U, V, temperature, and water vapor; optional cloud water and ice; and additional dynamics-dependent fields.

Boundary reads use a separate priority queue. They may move ahead of queued output operations, although they cannot interrupt a NetCDF call already in progress. At the boundary event, the model consumes completed prefetched data or waits for outstanding reads. A speculative read failure does not poison the output worker: RegCM records the prefetch failure and falls back to the normal synchronous boundary read.

Prefetch is active only when async support is compiled, the runtime buffer is positive and large enough for one local ICBC slot, parallel NetCDF input is enabled, the build is not using PnetCDF, and a valid next boundary exists. Output and prefetch share a worker and buffer pool within each process. With parallel input, non-output ranks can also initialize workers and reserve enough pinned memory for one local prefetch slot; therefore aggregate job memory must be considered separately from the full output buffer retained by the serial-I/O rank.

When output and boundary work coincide, RegCM temporarily defers output-worker wakeups, enqueues output, consumes the higher-priority boundary input, and then releases deferred output work. A producer blocked by the memory target releases deferred work before waiting, preventing the batching policy from intentionally deadlocking a full queue.

### Completion, Timing, and Errors

Normal finalization drains both queues, waits for any active operation, closes output streams, stops and joins the worker, and frees the pinned pool. Performance comparisons must use full model elapsed time through this final drain; stopping the timer before shutdown would only move visible I/O outside the measurement.

The first non-speculative worker failure is sticky in `first_error` and is returned by later enqueue, flush, close, or shutdown calls. Because a write reports success when accepted into the queue, its actual NetCDF error may become visible only at a later synchronization point. Normal shutdown drains work, but abrupt process termination has no persistent queue or recovery mechanism.

The runtime diagnostic reports `enabled`, `worker_running`, effective `buffer_gib`, and `first_error`. A valid synchronous control reports `enabled=F`; a valid async-output rank reports an active worker, the requested output buffer, and `first_error=0`. Parallel-input ranks may report the smaller effective buffer required for their local prefetch slot.

### CPU and NetCDF Constraints

The worker has no explicit affinity and no configurable worker count. Each active worker needs CPU time in addition to the model/OpenMP threads. The controlled battery therefore used `OMP_NUM_THREADS=1`, two CPUs per MPI rank, and exclusive-node allocation. Testing with no spare CPU is useful as a contention experiment but should not be mixed into the primary feature comparison.

The validated output path is serial NetCDF. PnetCDF builds bypass the principal async output and prefetch paths, while collective parallel-NetCDF operations are unsafe to launch independently from uncoordinated per-rank workers without explicit MPI thread support. Compatibility runs should verify that unsupported combinations are bypassed or rejected; they should not be treated as headline performance arms.

The primary implementation is in `Share/mod_async_netcdf.F90` and `Share/regcm_async_netcdf_thread.c`. Output routing is in `Share/mod_ncstream.F90`; boundary scheduling and reads are in `Main/mod_bdycod.F90` and `Main/mod_ncio.F90`; timestep and shutdown orchestration is in `Main/mod_regcm_interface.F90`.

### Build-to-Runtime Flow

<p align="center">
  <img src="async_io_build_runtime_flow.svg" alt="RegCM asynchronous NetCDF flow from configure and compilation through runtime output overlap, boundary prefetch, and final queue draining" width="1000">
</p>

<p align="center"><strong>Figure 1. RegCM asynchronous NetCDF build-to-runtime flow.</strong> The async-enabled binary still provides a synchronous runtime control. A positive output buffer activates the worker; output writes use the normal FIFO queue, while speculative boundary reads use the priority queue.</p>

Read the diagram from top to bottom:

1. The configure option decides whether pthread-backed async support is compiled and linked.
2. The same async-capable executable becomes either the synchronous control or an active async run based on runtime environment variables and namelist compatibility.
3. During the model loop, output and boundary reads share the worker, memory pool, and NetCDF serialization gate, but boundary reads receive queue priority.
4. Finalization drains all queued operations before timing and validation are complete; this prevents apparent speedups that merely move unfinished writes past the measured interval.

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

## Performance-Test Strategy

The test program is phased so that each comparison changes one feature while holding the executable, input data, namelist, MPI decomposition, GPU mapping, OpenMP setting, CPU allocation, output variables, filesystem, and node constant. Arms must use unique output directories and run sequentially on an exclusive node. Full elapsed time must include final queue draining.

| Phase | Controlled arms | Performance implication isolated |
|---|---|---|
| Build integration | Non-async build; async-enabled build with output buffer 0 and prefetch 0 | Compile/link integration overhead when runtime async is disabled |
| Deferred writes | Buffer 0 versus positive buffer, prefetch 0 | Benefit from overlapping serial output writes |
| Buffer capacity | 1, 2, 3, 4, and 8 GiB, prefetch 0 | Queue backpressure, pinned-memory cost, and the point beyond which more buffering has no benefit |
| Prefetch lead | Prefetch 0, 1, 5, 15, 20, and 40 with fixed sufficient buffer | Boundary-read overlap and whether the read completes before use |
| Input mode | Parallel input off/on with prefetch 0, then parallel input on with the selected prefetch lead | Distributed input cost separately from speculative prefetch |
| Worker CPU | `OMP_NUM_THREADS=1` with one versus two CPUs per rank; then OMP N with N versus N+1 CPUs | Contention cost and value of a dedicated worker core |
| Sync policy | `lsync=.true.` versus `.false.` with output schedule fixed | Cost and overlap of queued NetCDF sync operations |
| Event alignment | Output and boundary events coincident versus offset with equal output volume | Read priority and deferred-wakeup behavior |
| Output pressure | Progressively denser output frequency or larger variable sets | Worker saturation, producer stalls, and final-drain growth |
| Precision | Double and single precision, each with async disabled/enabled | Precision-specific I/O benefit without conflating compute speedup |
| NetCDF features | Serial classic/NetCDF4 and compression disabled/enabled | Worker CPU cost, compression benefit, and storage-bandwidth tradeoff |
| Decomposition | Selected MPI/GPU counts with per-rank and aggregate memory recorded | Output aggregation, local prefetch size, worker count, and scaling effects |
| Robustness | Bad path, full filesystem, constrained pinned memory, forced termination, restart validation | Delayed errors, shutdown behavior, and data integrity rather than peak speed |

The first completed battery covered the core runtime-disabled, deferred-write, prefetch-lead, and 3-versus-4-GiB cases. It establishes the large effect, approximately 10%, of deferred writes. It does not resolve sub-1% differences among prefetch settings or independently test every related namelist and resource control.

For effects below approximately 1%, use at least five repetitions and an alternating ABBA or randomized/Latin-square order rather than a fixed sequence. Keep input-cache policy consistent and record competing filesystem load. Three-day runs are preferred for screening and repetition; seven-day runs are reserved for configurations that survive correctness checks and show a repeatable material effect.

Each phase should collect:

- Full model and Slurm elapsed time, including final drain.
- Simulated days per hour and improvement against the matched control.
- Worker activation, effective per-rank buffer, and `first_error` diagnostics.
- Output bytes, file count, and effective write bandwidth.
- CPU utilization and whether the model blocks on buffer reservations.
- Final-drain duration and, after adding instrumentation, queue high-water marks and prefetch hit, wait, and fallback counts.
- Per-rank and aggregate pinned-memory reservations.
- Numerical comparisons of restart, ATM, RAD, SRF, and CLM outputs against the synchronous control.

Before interpreting small-buffer tests, determine the largest individual output item and the required local ICBC slot. Otherwise an oversized-item fallback or an inactive prefetch path can make the nominal toggle differ from the feature that actually ran.

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
