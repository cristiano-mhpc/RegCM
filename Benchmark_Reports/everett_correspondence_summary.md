# Detailed Reading and Summary of the Everett Correspondence

## Document Overview

- **Source:** `everett_correspondence.pdf`
- **Thread title:** *RegCM (Test data for one week run)*
- **PDF length:** 21 pages
- **Displayed thread size:** 22 messages, with additional earlier messages preserved as quoted correspondence
- **Visible date range:** February 12 to June 23, 2026
- **Main subject:** Performance optimization, testing, and portability of RegCM V5 on NVIDIA GPU systems, especially H100 and GB200 platforms
- **Primary participants:** Everett Phillips, Christian Tica, Graziano Giuliani, Massimiliano Fatica, Ivan Girotto, Serafina Di Gioia, and Filippo Spiga

The correspondence documents a sustained optimization effort around the EURR3 seven-day RegCM benchmark. The work evolves from individual OpenACC and memory-management fixes into a substantial asynchronous NetCDF I/O implementation, followed by portability testing, single-precision work, GB200 scaling experiments, and updates to required input data.

## Executive Summary

Everett Phillips investigated a series of RegCM GPU performance problems and supplied many replacement source files and archives. Early work addressed missing GPU implementations, page faults, NaN handling, asynchronous OpenACC execution, and expensive allocation/deallocation patterns. Later work introduced an optional pthread-backed asynchronous NetCDF subsystem that overlaps output writes and boundary-condition reads with model computation.

On an 8xH100 system, asynchronous I/O reduced a seven-day EURR3 run from approximately 2,685 seconds to 2,330 seconds in double precision. Single precision reduced the baseline to 2,342 seconds, and combining single precision with asynchronous I/O reduced it further to 1,988 seconds. Everett reported 12.7 simulated days per wall-clock hour for the latter configuration.

The correspondence also shows that performance depends strongly on GPU memory-pool sizing. With insufficient effective pool capacity, repeated device allocations and frees can make the model several times slower. Everett therefore moved work arrays out of frequently called routines, replaced temporary arrays with scalars in one routine, and adjusted other data-management behavior.

GB200 testing required system-specific launch settings to preserve inter-node NVLink communication. After restoring NUMA GPU-memory mode, Everett reported improved scaling from 4 to 32 GPUs. GB200 also exposed two NVHPC 26.1 compiler problems requiring source-level workarounds.

Several matters remained unresolved or required validation: broader regression testing of asynchronous I/O, a possible uninitialized index in `mod_pbl_holtbl.F90`, remaining low-memory allocation churn, compiler portability, the correct long-term solution for configure-time CUDA-driver detection, and confirmation that all changes behave correctly across CPU compilers and different GPU systems.

## Detailed Chronological Reading

### February 12-13: Aerosol NaN Handling

An Everett message quoted in the thread states that he supplied a fixed `mod_rad_aerosol.F90`. He also added explicit OpenACC data prefetching with `acc update`, which appeared to improve performance.

Everett questioned whether comparing a value against one NaN representation would detect all NaNs. Graziano replied on February 13 that NaN detection in Fortran is subtle. He cited the older Metcalf-style expression

```fortran
((x /= x) .or. ((x > 0.0D0) .eqv. (x <= 0.0D0)))
```

and said he had restored the `is_nan` call. He asked how expensive that call was and suggested possibly copying an `isnan` implementation into the module.

**Interpretation:** This exchange identifies both a correctness issue and a performance concern. Direct equality comparisons with NaN are not reliable because IEEE NaN is not equal to itself. The restored intrinsic or helper-based check is safer, but its GPU performance needed measurement.

### February 15: Urban Albedo and Aerosol Fixes

Everett sent two files:

- `mod_clm_urban.F90`, adding routines missing from the `UrbanAlbedo` implementation
- `mod_rad_aerosol.F90`, fixing the NaN issue

This appears to be an incremental correction to the GPU-enabled urban and aerosol code.

### February 16: Urban Albedo and Vertical Interpolation

Everett first noted that an earlier `UrbanAlbedo` submission had omitted one routine. He then sent an updated file after testing it.

Later that day, he supplied an updated vertical-interpolation implementation. The change removed page faults caused by alternating CPU and GPU access to `pccm`. He moved an `if` test into the GPU loop because that was inexpensive on the device and avoided host-side access.

Everett also considered further minor optimizations:

- Use `i,j` instead of `i1,j1` if they always produce the same result, potentially prefetching values needed by the following `k` loop.
- Load `pccm` values into a local array and test only the first and last values.

He did not pursue these ideas because the expected gains were small and the alternatives had not been tested.

**Interpretation:** The important change was not arithmetic optimization but data locality. Avoiding host access to device-resident data prevented unified-memory migration or page faults.

### February 17: Seven-Day H100 Baseline

Everett reported a successful seven-day EURR3 run on 8xH100 using the latest changes:

- Model iterations: 13,440
- Model-reported total time: 2,855.09 seconds
- Average time per step: 0.21243 seconds
- Overall elapsed time: 2,897.28 seconds
- Approximate wall time: 48 minutes

The run used:

```bash
export RCM_TIMER=1
export RCM_MAX_ITER=13440
export NVCOMPILER_ACC_POOL_SIZE=32GB
export NVCOMPILER_ACC_POOL_THRESHOLD=100
export UCX_TLS=cma,rc,mm,cuda_copy,cuda_ipc,gdr_copy
export UCX_RNDV_THRESH=128
export UCX_RNDV_FRAG_MEM_TYPE=cuda
export UCX_RNDV_FRAG_SIZE=cuda:32M
```

Everett still observed page faults after `scatterv` calls and planned to investigate them. He also proposed future testing on Blackwell and unified-memory Grace-Blackwell or Grace-Hopper systems.

### February 19: Initial Cross-System Comparison

Everett compared A30, H100, and GB200 systems using the EURR3 seven-day case and reported performance in simulated days per hour.

The systems differed significantly:

- A30: 4 GPUs per node and one InfiniBand connection
- H100: 8 GPUs per node, eight InfiniBand connections, and intra-node NVLink
- GB200: 4 GPUs per node with NVLink extending between nodes in a unified-memory configuration

One loop in `mod_clm_urban.F90`, around line 3347, did not run correctly on Blackwell and was left on the CPU for the test. Everett planned to fix it and rerun if the impact was significant.

**Interpretation:** These were not architecture-only comparisons. Node topology, network connectivity, GPU count per node, storage, and one CPU fallback differed, so direct conclusions required care.

### March 2: Christian Questions the I/O Results

Christian reported that ORFEO, with 8xH100 per node, took nearly three times longer than Everett's reported H100 result when I/O was enabled in the coupled configuration. Christian's no-I/O result was similar to Everett's result.

Christian asked:

- Whether Everett's published number was for the no-I/O case
- For the exact namelist file
- For the job script used in Everett's test

This message establishes I/O as a major source of the discrepancy between sites.

### March 10: H100 and GB200 Test Setups

Everett confirmed that his tests used I/O. He noted, however, that I/O performance differed substantially between the H100 and GB200 systems, with the GB200 system having faster storage.

He attached two setup examples, one for H100 and one for GB200. Each included:

- A `submit_job` script
- A `run_app` script
- Job output named like `testjob-XXXXXXX.out`

He suggested comparing the timing for step 80 to assess output performance.

**Interpretation:** Similar no-I/O performance but divergent I/O-enabled performance strongly suggests site storage, NetCDF behavior, output frequency, or host-side I/O orchestration as the cause rather than raw GPU compute.

### March 25: Asynchronous Canopy Fluxes

Everett sent two files implementing asynchronous GPU work in `canopyfluxes`.

The approach was to:

- Add `async` to OpenACC directives
- Add `!$acc wait` only where the CPU actually required completion
- Replace some `do concurrent` loops with ordinary `do` loops because the compiler did not correctly combine the desired OpenACC directives with `do concurrent`

Everett created a separate `frictionVelocity_async` routine. He considered using an optional asynchronous argument instead, with the routine waiting only when that argument was absent. Another call site required synchronization; making all calls asynchronous caused runtime errors that were probably race conditions. He therefore retained synchronous and asynchronous versions for safety.

**Interpretation:** This change improved overlap but deliberately duplicated a routine to avoid changing synchronization semantics globally. It was a conservative workaround pending better compiler behavior and a complete dependency analysis.

### March 30: Asynchronous History Buffer Update

Everett sent another attached file for asynchronous `hist_update_hbuf`. The PDF provides no additional implementation detail for this attachment.

### May 13, First Message: Boundary Exchange Regression

Everett found a performance regression and supplied an updated `mod_mppparam.F90`. The boundary routine's four-dimensional exchange had not been implemented on the GPU.

Measured fast-iteration performance on 8xH100 was:

- Earlier expected result: approximately 0.12 seconds
- Regressed result before the fix: approximately 0.19 seconds
- Result after the fix: approximately 0.12 seconds

This restored the previous performance level.

### May 13, Second Message: Initial Asynchronous NetCDF Output

Everett supplied `RegCM_ASYNC_OUT.tgz`, introducing background NetCDF writes. The feature was enabled by setting:

```bash
export RCM_ASYNC_OUTPUT_GB=<positive integer>
```

The default was zero, retaining the old synchronous behavior.

When enabled, the implementation allocated a pinned host-memory buffer of the specified size. Output operations copied or queued data into this buffer, and a background pthread performed disk writes after the output routine returned. Reads and selected main-thread operations received priority.

The main changed areas were:

- `Share/mod_async_netcdf.F90`: queue, pinned buffer pool, and worker-facing write records
- `Share/regcm_async_netcdf_thread.c`: pthread worker and synchronization
- `Share/mod_ncstream.F90`: routing output through the asynchronous queue
- `Main/mpplib/mod_ncout.F90`: batching, flushing, and NetCDF priority wrappers
- `Main/mod_output.F90`: batching output and avoiding save-file queue drains

Everett recommended leaving at least one CPU core free for the worker, for example by setting the number of OpenMP threads below the available core count. Only serial output was supported. Parallel-output support was deferred because additional work appeared necessary.

He characterized the implementation as a large change and requested testing on multiple systems.

### May 13: Internal Follow-Up

Ivan asked Christian to integrate and test all the changes. He also pointed to a EuroHPC benchmark-access call and noted that Jupyter could apparently be requested for benchmarking.

Christian replied that the team would review the application process and run the latest version as soon as access became available.

### May 14: First Asynchronous-I/O Result

Everett completed a seven-day test on 8xH100. Overlapping disk writes with computation improved performance from 6.8 to 5.8 minutes per simulated day, approximately a 16% speedup.

Reported values included:

- Total model time: 2,451.97 seconds
- Time per step: 0.18244 seconds
- Overall elapsed time: 2,508.05 seconds

The test used:

```bash
export RCM_TIMER=1
export RCM_MAX_ITER=13440
export RCM_ASYNC_OUTPUT_GB=32
export NVCOMPILER_ACC_POOL_SIZE=70GB
export NVCOMPILER_ACC_POOL_THRESHOLD=95
export UCX_TLS=cma,rc,mm,cuda_copy,cuda_ipc,cuda
export UCX_RNDV_THRESH=128
export UCX_RNDV_FRAG_MEM_TYPE=cuda
export UCX_RNDV_FRAG_SIZE=cuda:32M
export OMP_NUM_THREADS=12
```

The host had 14 CPU cores per GPU. Everett observed that output took longer every 24 simulated hours, particularly around step 1920, and planned to profile that event.

### May 18: Asynchronous Output Fixes and Boundary Prefetch

Everett sent `RegCM_ASYNC_IO.tgz`, which superseded the previous asynchronous-output archive. It contained fixes and added asynchronous boundary-condition input.

The daily slowdown at step 1920 was caused by closing files. Closing forced the main thread to wait for queued writes. The revised implementation queued close operations so that the worker closed files only after writes completed. It also avoided blocking when creating new files.

For boundary input, `bdyin` data could be prefetched into pinned host memory and copied into model or device buffers when needed. Boundary reads had higher queue priority than output writes. Output writes were briefly held while `bdyin` consumed prefetched data, reducing host/device memory-bandwidth contention.

Relevant files were:

- `Share/mod_async_netcdf.F90`: asynchronous read tasks, read-priority scheduling, buffer and counter APIs, and allocation warmup
- `Main/mod_ncio.F90`: ICBC prefetch queuing, slot management, consumption, synchronous fallback, and allocation warmup
- `Main/mod_bdycod.F90`: `bdyin_prefetch`, parsing of `RCM_BDYIN_PREFETCH_STEPS`, and prefetched data consumption
- `Main/mod_regcm_interface.F90`: prefetch calls before `moloch`/`tend`, allowing reads to overlap computation

Configuration variables were:

```bash
export RCM_ASYNC_OUTPUT_GB=8
export RCM_BDYIN_PREFETCH_STEPS=15
```

`RCM_ASYNC_OUTPUT_GB` enabled the worker and set the pinned-memory budget. The output rank used the budget for writes and reads. Other ranks allocated only enough for one boundary prefetch, capped by the configured value. If the buffer was too small, the model skipped prefetch and used synchronous reads.

`RCM_BDYIN_PREFETCH_STEPS` controlled lead time. The default was one step, and zero disabled prefetch.

The updated 8xH100 result was approximately an 18% speedup:

- Total model time: 2,407.28 seconds
- Time per step: 0.17911 seconds
- Overall elapsed time: 2,456.39 seconds

Everett used a 16 GB asynchronous buffer, a 15-step boundary lead, a 70 GB compiler allocation pool, and 12 OpenMP threads.

Planned improvements included:

- A configure flag for asynchronous I/O
- Automatic selection of prefetch lead based on timings
- Startup diagnostics showing whether asynchronous I/O was enabled and how much memory it reserved
- Runtime buffer-usage reporting so users could tune the allocation

### May 19: Configure-Time Feature Control

Everett sent `RegCM_enable_async_netcdf.tgz`. It added:

```text
--enable-async-netcdf
```

to `configure.ac` and `./configure --help`. Asynchronous NetCDF support was disabled by default. Without the flag, configuration did not define `ASYNC_NETCDF`, check for `pthread.h`, or add `-pthread`.

Other changes included:

- Conditional compilation of `regcm_async_netcdf_thread.c` in `Share/Makefile.am`
- Synchronous/no-op defaults in `mod_async_netcdf.F90`
- `#ifdef ASYNC_NETCDF` guards in `mod_bdycod.F90`, `mod_ncio.F90`, and `mod_regcm_interface.F90`
- Updated suffix filtering in `makeinc`
- Documentation in `Install.tex`

**Interpretation:** This turned the experimental implementation into an opt-in build feature and reduced risk for platforms that did not have or did not want pthread support.

### May 20: Initial Portability Testing and Team Status

Graziano said the feature was substantial. He had performed non-regression tests with GNU Fortran and Intel compilers, but considered a GPU with spare CPU cores the essential test environment.

He temporarily broke IBM compatibility because a `$DEFINE` used during pthread detection would not otherwise work. He no longer had BlueGene/Q access and doubted that the current model still compiled there.

Graziano also added `real4` MPI communication methods, potentially enabling `--enable-singleprecision` so physically relevant real values would use 32-bit storage.

He asked Christian to test the latest code using Everett's environment on any available platform. He also noted access or scheduler problems on Marconi100/Leonardo-related resources, including MN5 and ORFEO.

Serafina thanked Everett and summarized Christian's benchmarking on Leonardo, ORFEO, and MN5. Their tested code was three commits behind the repository. Results on apparently similar architectures differed significantly from Everett's, so they had begun profiling I/O, communication, the dynamical core, and other sections. They intended to integrate the latest changes and discuss profiling results the following week.

### May 22: Memory Pool as a Likely Performance Cause

Everett reported low performance on 4xH100 and on 8xH100 when the memory pool was limited to around 48 GB per GPU. Under those conditions, execution could be almost four times slower than with a larger pool.

He suggested that pool size or total GPU-memory pressure might explain the team's slower measurements.

For EURR3 asynchronous I/O, further experiments showed that earlier buffer settings were excessive:

- `RCM_ASYNC_OUTPUT_GB=3` was sufficient.
- A value of 4 GB was slightly faster.
- Larger values produced no additional benefit.
- One prefetch step was enough on his system to hide the read completely.
- He nevertheless recommended around 20 steps to tolerate reads becoming two or three times slower.

Because writes occurred every 80 steps, a 20-step read lead still left around 60 steps for previous writes to finish.

His practical starting recommendation for EURR3 was therefore a 4 GB asynchronous buffer and a 20-step prefetch depth.

### May 23, First Message: `wafone` Allocation Churn

Everett investigated the slow 4xH100 80 GB case. The largest slowdown was in `moloch`, specifically advection routine `wafone`. The routine repeatedly allocated and deallocated three arrays, and the device memory pool could not accommodate the request even at its maximum configured size.

He supplied `mod_moloch.F90` with an attempted fix. Fast iterations improved by roughly 2x. Surface-model and radiation iterations remained slow because of memory pressure elsewhere.

The next visible hotspot was `canopyfluxes`, where profiling showed `cuMemFree` activity originating from `photosynthesis`.

### May 23, Second Message: Canopy Flux and Friction Velocity Memory Fixes

Everett sent first-pass fixes in:

- `mod_clm_canopyfluxes.F90`
- `mod_clm_frictionvelocity.F90`

The `photosynthesis` work arrays were moved into `canopyfluxes`, extending their useful lifetime and avoiding repeated allocation. One-dimensional temporary arrays in `frictionVelocity` were replaced with scalars.

The changes improved performance, but many allocations and frees remained in the constrained-memory configuration. Everett questioned whether further work was justified if the issue disappeared on larger-memory GPUs.

He suspected that the compiler's pool accounted for buffers used by the CPU, causing the configured limit to be reached before physical GPU memory was exhausted. A pool size above 100% of GPU memory might therefore help, but the current implementation did not permit it. He considered asking NVIDIA whether that limit could be changed.

### May 23, Third Message: Single-Precision MPI Exchange

Everett sent another `mod_mppparam.F90`, adding GPU support to single-precision communication routines.

Before the change, single precision was slower than double precision. The fix made it faster, but only slightly. Everett planned to investigate further and suspected that asynchronous I/O overlap might also need single-precision-specific work.

### May 24: Accumulation and Output Collection Fixes

Everett sent three files:

- `mod_clm_accumul.F90`
- `mod_clm_accflds.F90`
- `mod_lm_interface.F90`

The first two fixed host-to-device page faults in `updateAccFlds`, observed around step 20. The third added missing GPU loops in `collect_output`. Everett converted those loops to `do concurrent`, while noting that array syntax could be restored if preferred.

He also concluded that asynchronous writes appeared to work with single precision. The recent `mod_mppparam.F90` fix had apparently corrected the low I/O performance too, although he still intended to verify that both reads and writes were genuinely overlapping computation.

### May 30: More Mature Asynchronous I/O and a Possible PBL Bug

Everett sent `RegCM_ASYNC_update.tgz` with a broad set of updates:

- Automatic prefetch-depth selection when the user did not set one
- GPU name in startup output
- End-of-run tuning hints if buffer exhaustion or insufficient prefetch depth caused stalls
- GPU port of `Hist_htapes_wrapup`
- Queued `Hist_htapes_wrapup` writes when asynchronous I/O was enabled
- A common CPU/GPU output-queue path in `mod_ncstreams.F90`
- OpenACC-specific memory initialization changes in `mod_space.F90`
- Nestable locks to reduce deadlock risk
- Polling instead of blocking waits for read prefetch, resolving one observed deadlock
- Exclusion of final-step writes from buffer-size recommendations

In `mod_space.F90`, Everett avoided `source=` allocation under OpenACC because it initialized memory on the CPU and migrated it there. He instead initialized on the GPU and then explicitly prefetched to the host with `!$acc update host(...)`.

Pulling data back to the CPU remained necessary because omitting that transfer caused some radiation routines to run out of memory and evict pages during computation. He experimented with a `NO_INIT_MEM` option, but was unsure whether skipping initialization was generally safe. Avoiding initialization and host transfer saved around four seconds at startup, probably because CPU-first access otherwise caused GPU page faults on first touch.

His preferred long-term approach was to initialize on the GPU and move back only arrays that the GPU did not use.

Everett also identified two apparent issues in `Main/pbllib/mod_pbl_holtbl.F90`:

- Two directives used `!@acc loop seq` rather than `!$acc loop seq`.
- `vv(j,i,k)` was accessed before `k` was defined in the shown loop.

He changed the second expression to `vv(j,i,kz)` to avoid an out-of-bounds access, but explicitly asked whether `kz` was semantically correct.

Together with another minor `collect_output` change, the updates improved performance by approximately 3-5% before the PBL change.

### June 3: Single Precision and Async I/O Comparison

Everett reported a controlled comparison on 8xH100 80 GB:

| Mode | Seven-day time | Simulated days/hour |
|---|---:|---:|
| Double precision | 2,685 s | 9.4 |
| Double + async I/O | 2,330 s | 10.8 |
| Single precision | 2,342 s | 10.8 |
| Single + async I/O | 1,988 s | 12.7 |

The test configuration was:

```bash
export RCM_TIMER=1
export RCM_MAX_ITER=13440
export RCM_ASYNC_OUTPUT_GB=3
export RCM_BDYIN_PREFETCH_STEPS=15
export NVCOMPILER_ACC_POOL_SIZE=72GB
export NVCOMPILER_ACC_POOL_THRESHOLD=90
export UCX_TLS=cma,rc,mm,cuda_copy,cuda_ipc,cuda,gdr_copy
export UCX_RNDV_THRESH=128
export UCX_RNDV_FRAG_MEM_TYPE=cuda
export UCX_RNDV_FRAG_SIZE=cuda:32M
export OMP_NUM_THREADS=12
```

Relative to double precision, asynchronous I/O alone reduced elapsed time by about 13.2%. Single precision alone reduced it by about 12.8%. Combining both reduced it by about 26.0%. The combined gain is close to multiplicative, suggesting that compute/memory improvements and hidden I/O addressed largely distinct costs.

### June 6, First Message: GB200 Regression

Everett attempted to repeat GB200 tests and found the system much slower than before. It appeared that inter-node NVLink was no longer being used. He began investigating whether a new setting was required.

### June 6, Second Message: GPU Memory Mode

Everett learned that the internal cluster's default GPU-memory mode had changed from `numa` to `driver`. The new mode appeared to disable inter-node NVLink for RegCM.

He restored the prior behavior by adding:

```bash
#SBATCH --comment="gpu_memory_mode=numa"
```

He asked whether the team's tested systems also used unified memory.

### June 6, Third Message: GB200 Scaling and Launch Scripts

After restoring NUMA mode, Everett compared current GB200 results with previous ones:

| GPUs | Previous time | Updated time | Approximate improvement |
|---:|---:|---:|---:|
| 4 | 4,112 s | 3,410 s | 17.1% |
| 8 | 2,421 s | 2,074 s | 14.3% |
| 16 | 1,674 s | 1,313 s | 21.6% |
| 32 | 1,334 s | 1,080 s | 19.0% |

The batch script used eight nodes, four tasks per node, 36 CPU cores per task, a single eight-node NVLink segment, and NUMA GPU-memory mode. It launched Open MPI with UCX and disabled the OpenIB and SMCUDA BTL paths.

The application wrapper set:

```bash
export RCM_TIMER=1
export RCM_MAX_ITER=13440
export RCM_ASYNC_OUTPUT_GB=4
export RCM_BDYIN_PREFETCH_STEPS=15
export NVCOMPILER_ACC_POOL_SIZE=160GB
export NVCOMPILER_ACC_POOL_THRESHOLD=90
export NVCOMPILER_ACC_POOL_ALLOC_MAXSIZE=1500MB
export UCX_TLS=cma,rc,mm,cuda_copy,cuda_ipc,cuda
export UCX_RNDV_THRESH=128
export UCX_RNDV_FRAG_MEM_TYPE=cuda
export UCX_RNDV_FRAG_SIZE=cuda:16M
export ACC_NUM_CORES=32
export OMP_NUM_THREADS=32
export MKL_NUM_THREADS=32
export OMP_PROC_BIND=TRUE
export OMP_PLACES=sockets
```

Each local MPI rank was mapped to a GPU, CPU-core range, NUMA node, and network interface. The mapping was:

| Local rank | CPU cores | NUMA node | UCX device |
|---:|---|---:|---|
| 0 | 0-35 | 0 | `mlx5_0:1` |
| 1 | 36-71 | 0 | `mlx5_1:1` |
| 2 | 72-107 | 1 | `mlx5_4:1` |
| 3 | 108-143 | 1 | `mlx5_5:1` |

The attached `GB200_EURR3.png` plotted previous and updated performance in simulated days per hour for 4, 8, 16, and 32 GPUs. The updated line was consistently above the previous line.

### June 8: GB200 Compiler Workarounds

Everett supplied two additional files needed on GB200 with NVIDIA HPC SDK 26.1:

- `mod_clm_urban.F90`: A loop calling `MoninObukIni` caused an illegal memory access. Everett believed the compiler lost track of `grav`. He worked around it by making a local copy of the routine. Passing `grav` explicitly to the original routine was another possible solution.
- `mod_capecin.F90`: The compiler rejected or mishandled a routine inside a `contains` section. Moving the routine outside `contains` fixed the issue.

These workarounds were not required on the 8xH100 system.

Everett also described a configure/link problem involving cuSPARSE. The build incorrectly added `-lcuda`, but head nodes did not have the CUDA driver library, causing configuration to fail unless compilation occurred on compute nodes. His temporary workaround was a dummy `libcuda.so` symbolic link pointing to `libcudart.so`. He had reported the issue internally.

**Interpretation:** The symlink may allow a configure probe to pass, but `libcuda` and `libcudart` are not interchangeable libraries. This should be treated only as a narrow configure-time workaround, not as a valid runtime or permanent build solution.

### June 23: Updated EURR3 Input Data

Everett reported this failure while reading the EURR3 domain:

```text
Reading Domain file : input/EURR-3_DOMAIN000.nc
NetCDF: Variable not found
mod_nchelper.F90 :      748:Error search topou:          -49
```

He asked whether the input files needed updating.

Graziano confirmed that they did and provided:

```text
http://clima-dods.ictp.it/Users/ggiulian/transfer/EURR3/input/
```

The updated domain data included staggered topography. This data was now used by:

- Vertical interpolation of winds during ICBC processing
- Computation of vertical factors at staggered model points

The new directory contents were intended to replace the previous input files.

## Consolidated Performance Results

### H100 Results

| Date/context | Platform | Configuration | Result |
|---|---|---|---|
| Feb. 17 baseline | 8xH100 | Double, normal I/O | 2,897 s elapsed; 0.2124 s/step |
| May 13 boundary regression | 8xH100 | Missing 4D GPU exchange | Fast iterations regressed from ~0.12 to ~0.19 s |
| May 13 boundary fix | 8xH100 | GPU 4D exchange restored | Fast iterations returned to ~0.12 s |
| May 14 async writes | 8xH100 | 32 GB async buffer | 2,508 s elapsed; ~16% improvement |
| May 18 async writes + reads | 8xH100 | 16 GB buffer, 15-step prefetch | 2,456 s elapsed; ~18% improvement |
| June 3 controlled comparison | 8xH100 | Double | 2,685 s; 9.4 days/hour |
| June 3 controlled comparison | 8xH100 | Double + async I/O | 2,330 s; 10.8 days/hour |
| June 3 controlled comparison | 8xH100 | Single | 2,342 s; 10.8 days/hour |
| June 3 controlled comparison | 8xH100 | Single + async I/O | 1,988 s; 12.7 days/hour |

The exact baselines vary because the source version and settings changed over time. Results should therefore be compared within the same reported experiment rather than combined into one continuous trend.

### GB200 Scaling

The best reported updated times were 3,410, 2,074, 1,313, and 1,080 seconds for 4, 8, 16, and 32 GPUs respectively.

Using the four-GPU result as the baseline, the approximate parallel speedups were:

| GPUs | Time | Speedup vs. 4 GPUs | Parallel efficiency relative to ideal scaling from 4 GPUs |
|---:|---:|---:|---:|
| 4 | 3,410 s | 1.00x | 100% |
| 8 | 2,074 s | 1.64x | 82% |
| 16 | 1,313 s | 2.60x | 65% |
| 32 | 1,080 s | 3.16x | 39% |

Scaling remains beneficial through 32 GPUs, but efficiency declines as communication, synchronization, I/O, or fixed costs become more prominent.

## Major Technical Themes

### 1. Overlapping I/O with Computation

The largest architectural change was the optional pthread-backed NetCDF worker. It hides output latency by copying data into pinned host buffers and deferring disk operations to a background thread. Later revisions added prioritized ICBC reads, asynchronous close and create handling, queue diagnostics, and automatic prefetch tuning.

The design deliberately preserves synchronous behavior by default and requires `--enable-async-netcdf` plus a positive `RCM_ASYNC_OUTPUT_GB` value.

### 2. Unified Memory and Page Migration

Many fixes address data movement rather than floating-point work:

- Avoiding CPU checks of GPU-resident values
- Explicit OpenACC host/device updates
- Fixing host-to-device page faults
- Initializing arrays on the GPU
- Managing whether arrays should be pulled back to the CPU
- Prefetching boundary data through pinned buffers

This indicates that unified-memory placement and accidental host touches were important determinants of performance.

### 3. Allocation and Deallocation Overhead

Repeated temporary-array allocation in `wafone`, `photosynthesis`, and related routines caused severe performance degradation when the compiler memory pool was full. The supplied fixes increased the lifetime of work arrays or replaced them with scalars.

The correspondence suggests that memory-pool tuning can hide the problem on large-memory GPUs but does not eliminate the underlying allocation pattern.

### 4. Synchronization Correctness

Asynchronous OpenACC and pthread work introduced race and deadlock risks:

- A fully asynchronous `frictionVelocity` caused probable races.
- File-close behavior initially forced synchronization.
- Read prefetch waits caused a deadlock and were changed to polling.
- Locks were made nestable.
- Output was paused briefly while prefetched input was consumed.

The performance gains are meaningful, but correctness testing under varied timing and storage conditions is essential.

### 5. Platform-Specific Configuration

Performance depended on:

- GPU memory-pool capacity and threshold
- UCX transports and rendezvous settings
- CPU cores available to the background worker
- MPI rank, CPU, NUMA, GPU, and network-interface affinity
- GPU-memory mode on GB200
- NVLink-domain placement
- Storage throughput

Consequently, nominally similar GPU systems can produce very different results unless the complete software and topology configuration is matched.

### 6. Compiler and Portability Problems

The thread records issues involving:

- OpenACC directives with `do concurrent`
- Blackwell code generation around `MoninObukIni`
- A procedure inside a Fortran `contains` section
- IBM preprocessor compatibility
- Configure-time pthread handling
- Erroneous CUDA-driver linking during cuSPARSE checks

Some changes are workarounds rather than final source-level solutions and should remain documented as such.

## Recommended Baseline Settings From the Correspondence

For the EURR3 case on an H100-like system, Everett's later practical recommendation was approximately:

```bash
export RCM_ASYNC_OUTPUT_GB=4
export RCM_BDYIN_PREFETCH_STEPS=20
```

His June 3 benchmark instead used:

```bash
export RCM_ASYNC_OUTPUT_GB=3
export RCM_BDYIN_PREFETCH_STEPS=15
export NVCOMPILER_ACC_POOL_SIZE=72GB
export NVCOMPILER_ACC_POOL_THRESHOLD=90
export OMP_NUM_THREADS=12
```

These are starting points, not portable defaults. The asynchronous buffer must fit host pinned-memory constraints, the pool must leave sufficient device capacity, and the worker needs an available CPU core.

## Open Questions and Risks

1. **PBL indexing correctness:** Is `vv(j,i,kz)` the correct replacement for `vv(j,i,k)` in `mod_pbl_holtbl.F90`, or should another level index be used?
2. **Asynchronous-I/O regression coverage:** Has the implementation been tested across slow and fast filesystems, multiple NetCDF versions, CPU-only builds, abrupt termination, error paths, and repeated file creation and closure?
3. **Deadlock robustness:** Polling fixed an observed deadlock, but was the underlying lock-order or signaling problem fully understood?
4. **Single-precision scientific validation:** Performance improved, but the correspondence does not provide numerical-difference or scientific-validity results.
5. **Parallel NetCDF output:** The asynchronous worker supported only the serial output path at the time of the discussion.
6. **Memory-constrained GPUs:** Allocation churn remained after the first fixes and may still substantially affect 4xH100 or other constrained cases.
7. **Compiler workarounds:** The GB200 source modifications should be retested with later NVHPC releases and removed if compiler defects are fixed.
8. **CUDA link workaround:** Mapping a dummy `libcuda.so` to `libcudart.so` is not a sound permanent solution. Configure should distinguish compile-time toolkit availability from runtime driver availability.
9. **IBM portability:** Graziano explicitly noted that IBM compatibility was temporarily broken.
10. **Input-data versioning:** Current code requires the updated EURR3 domain files containing `topou` and staggered topography. Code and input versions must be tracked together.
11. **Cross-site reproducibility:** Differences among ORFEO, Leonardo, MN5, NVIDIA H100, and GB200 systems require full recording of code commit, namelist, input data, compiler, NetCDF, MPI/UCX, storage, topology, and environment variables.

## Suggested Validation Checklist

- Record the exact RegCM commit and all applied attachment versions.
- Replace old EURR3 input with the June 23 staggered-topography data.
- Validate a synchronous CPU build before enabling asynchronous NetCDF.
- Run GNU and Intel CPU non-regression tests.
- Run GPU tests with asynchronous I/O disabled and enabled.
- Compare model outputs, not only runtime, in double and single precision.
- Check startup diagnostics and end-of-run asynchronous-I/O tuning hints.
- Test `RCM_ASYNC_OUTPUT_GB` near 3-4 GB before allocating substantially more.
- Test prefetch depths of 1, 15, and 20 under the target filesystem.
- Reserve at least one CPU core for the asynchronous worker.
- Profile allocations, `cuMemFree`, unified-memory faults, and data migration.
- Confirm the PBL `k` versus `kz` correction scientifically and with bounds checking.
- Exercise daily file rollover around step 1920.
- Test final-step flushing and clean worker shutdown.
- Verify rank-to-GPU, CPU, NUMA, and network affinity.
- On GB200, confirm NVLink-domain placement and the required GPU-memory mode.
- Remove or isolate temporary compiler and link workarounds when newer toolchains permit.

## Attachment and Change Index

The PDF names the following attachments or attachment groups. It does not include their full source text in the parsed correspondence.

| Attachment | Purpose described in correspondence |
|---|---|
| `mod_mppparam.F90` | 4D boundary GPU exchange; later single-precision GPU communication routines |
| `mod_clm_urban.F90` | Missing UrbanAlbedo routines; later GB200 compiler workaround |
| `mod_rad_aerosol.F90` | NaN handling and prefetch improvements |
| `RegCM_ASYNC_OUT.tgz` | Initial asynchronous NetCDF output worker |
| `RegCM_ASYNC_IO.tgz` | Async output fixes plus ICBC/boundary prefetch |
| `RegCM_enable_async_netcdf.tgz` | `--enable-async-netcdf` configure support |
| `mod_moloch.F90` | Reduced `wafone` allocation/deallocation overhead |
| `mod_clm_frictionvelocity.F90` | Replaced temporary arrays with scalars and related memory improvements |
| `mod_clm_canopyfluxes.F90` | Moved photosynthesis work arrays to reduce allocation churn |
| `mod_clm_accumul.F90` | Fixed host-to-device page faults |
| `mod_clm_accflds.F90` | Fixed host-to-device page faults in `updateAccFlds` |
| `mod_lm_interface.F90` | Added missing GPU loops in `collect_output` |
| `RegCM_ASYNC_update.tgz` | Automatic prefetch tuning, diagnostics, queued tape wrap-up, locking and memory updates |
| `GB200_EURR3.png` | Previous versus updated GB200 scaling plot |
| `mod_capecin.F90` | GB200/NVHPC workaround for a procedure inside `contains` |
| H100 and GB200 setup archives/files | Job scripts, run scripts, and output examples used for performance comparison |
| Async canopy-flux files | OpenACC asynchronous execution and `frictionVelocity_async` changes |
| Async `hist_update_hbuf` file | Asynchronous history-buffer update |

## Overall Assessment

The correspondence captures a productive but still evolving optimization campaign. The strongest results came from treating I/O, memory placement, and temporary allocation as first-class performance concerns rather than focusing only on GPU kernels. The asynchronous NetCDF implementation appears to provide a repeatable double-digit gain, and single precision provides a similar independent benefit. Correct GPU implementation of boundary exchanges and elimination of allocation churn also recover large regressions.

At the same time, the work contains experimental components and platform-specific workarounds. The asynchronous subsystem changes threading, memory ownership, operation ordering, file lifetime, and error-handling behavior. The PBL index issue may be a correctness defect, and single precision requires scientific validation beyond successful execution. A careful integration should therefore preserve the opt-in build flag, separate independent patches, run numerical regression tests, and document exact system settings alongside all performance measurements.
