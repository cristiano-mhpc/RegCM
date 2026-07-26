# RegCM Seven-Day GPU Scaling Experiment

## Document Status

This is the final report for the 4-, 8-, 16-, and 32-GPU RegCM strong-scaling
experiment. It records the common configuration, build and launcher fixes
inherited from the validated one-day test, job results, scaling analysis, known
warnings, and output locations.

Final status:

- All four scaling runs completed successfully with exit code `0:0`.
- Every run reached `2009-10-08 00:00:00 UTC` and printed the successful-end
  marker.
- Rank-to-GPU placement was correct and stderr was empty in every run.
- No environment-loader changes were made for these scaling runs.

The detailed one-day build and bring-up history is recorded in:

```text
../../../1003_1003_50_1day_with_IO/sequential_output/Non_MPS_stdpar/Test_8gpu_8proc/Test_8gpu_8proc_report.md
```

The older 8-GPU hand-tuning study is separate from this scaling experiment and
is documented in:

```text
8gpus_COPY/RegCM_7day_hand_tuning_summary.md
```

## Experiment Objective

The objective is to measure strong scaling for one fixed RegCM problem while
changing only the number of MPI ranks and A100 GPUs. The experiment compares
4, 8, 16, and 32 GPUs with one MPI rank per GPU and four ranks per Leonardo
Booster node.

The fixed simulation is:

| Parameter | Value |
| --- | --- |
| Horizontal grid | 1003 x 1003 |
| Vertical levels | 50 |
| Interior CLM grid | 1000 x 1000 |
| Start time | 2009-10-01 00:00:00 UTC |
| Final time | 2009-10-08 00:00:00 UTC |
| Simulated duration | 168 hours, or 7 days |
| Dynamics timestep | 45 seconds |
| Land-surface model | CLM 4.5 |
| Output mode | Sequential NetCDF output |
| ATM frequency | 1 hour |
| RAD frequency | 1 hour |
| SRF frequency | 1 hour |
| Parallel NetCDF input | Enabled |
| Parallel NetCDF output | Disabled |

The 4-, 16-, and 32-GPU folders link to the exact namelist in
`Test_8gpu_8proc/EURR-3_namelist.in`. Relative `input` and `output` paths are
resolved from each test's working directory, so input is shared but output is
isolated.

## Test Matrix

| Test | GPUs / MPI ranks | Nodes | Ranks per node | RegCM decomposition | Time limit | Submit script |
| --- | ---: | ---: | ---: | --- | ---: | --- |
| `Test_4gpu_4proc` | 4 / 4 | 1 | 4 | 2 x 2 | 10:00:00 | `submit_4gpu_task.job` |
| `Test_8gpu_8proc` | 8 / 8 | 2 | 4 | 2 x 4 | 02:30:00 | `submit_8gpu_task.job` |
| `Test_16gpu_16proc` | 16 / 16 | 4 | 4 | 4 x 4 | 04:00:00 | `submit_16gpu_task.job` |
| `Test_32gpu_32proc` | 32 / 32 | 8 | 4 | 8 x 4 | 02:40:00 | `submit_32gpu_task.job` |

All jobs request four A100 GPUs per node with `--gres=gpu:4` and use direct
`srun` to launch `STD_launch_per_rank.sh`.

## Software Configuration

The experiment uses:

- NVHPC 25.11
- CUDA 12.2
- HPC-X/OpenMPI 2.25.1 through the user MPI shim
- NVHPC-built NetCDF-C, NetCDF-Fortran, PnetCDF, and HDF5
- OpenACC and Fortran standard parallelism
- NVIDIA A100 target architecture `cc80`
- CUDA managed memory
- Relocatable device code

The principal compiler options are:

```text
-acc -stdpar=gpu -gpu=cc80,lineinfo,mem:managed,rdc
```

The tested executable is:

```text
/leonardo/home/userexternal/ctica000/MS_thesis/RegCM/bin/regcmMPICLM45_OPENACC_STDPAR
```

Executable identity:

| Property | Value |
| --- | --- |
| Size | 114077976 bytes |
| SHA-256 | `716830495962f52474cda4cb0c09529b5f854988eebf8881c7454b8137f12fc9` |
| CUDA image | `sm_80` |

The final build log is:

```text
/leonardo/home/userexternal/ctica000/MS_thesis/RegCM/build_urban_serial_nvhpc.log
```

## Source Changes Required for This Executable

The following source or build-configuration files were changed during the
one-day bring-up that produced the executable used here.

### `configure.ac`

- Set the NVIDIA GPU target to `cc80`.
- Enabled both OpenACC and stdpar with `-acc -stdpar=gpu`.
- Added `rdc` for relocatable device code.
- Kept line information and managed memory enabled.

RDC was added because RegCM device code is split across separately compiled
Fortran modules and static libraries. It lets `nvlink` resolve device routines
and module variables at the final device-link stage. The RDC link exposed
missing device definitions in the WSM/WDM microphysics code; it was added for
link correctness, not as a performance optimization.

### `Main/microlib/mod_micro_wsm5.F90`

- Declared `pidn0r` and `pidn0s` as OpenACC device variables.
- Copied their initialized values to the device.

### `Main/microlib/mod_micro_wsm7.F90`

- Declared `pidn0r`, `pidn0s`, `pidn0g`, and `pidn0h` as device variables.
- Copied their initialized values to the device.

### `Main/microlib/mod_micro_wdm7.F90`

- Declared `pidnc`, `pidnr`, `pidn0s`, `pidn0g`, and `pidn0h` as device
  variables.
- Copied their initialized values to the device.

The eleven microphysics values are transferred once during initialization, so
the added updates should have negligible steady-state runtime cost.

### `Main/clmlib/clm4.5/mod_clm_urban.F90`

- Selected the existing serial fallback for an `UrbanFluxes` loop that failed
  as a GPU-offloaded stdpar `do concurrent` loop with CUDA error 719.

The serial urban loop is the source modification most likely to have a
measurable runtime cost. A controlled GPU alternative or profiler run is needed
before attributing a specific percentage to it.

## Launcher Configuration and Findings

Each submission script:

- Sources `environment_loaders/regcm5_leonardo_nvhpc_hpcx.sh`.
- Exports `OPAL_PREFIX="$MPI_SHIM"` so relocated OpenMPI uses the accessible
  HPC-X shim prefix.
- Uses the verified executable in `bin`.
- Launches through `srun ./STD_launch_per_rank.sh`.
- Records compiler, linker, binary-dependency, GPU, node, and task information.

Each rank wrapper:

- Uses `SLURM_LOCALID` as the local GPU index.
- Sets `CUDA_VISIBLE_DEVICES` to that local index.
- Sets `ACC_DEVICE_TYPE=nvidia`.
- Sets `ACC_DEVICE_NUM=0` inside the restricted visible-device view.
- Records global rank, local rank, host, and GPU selection.

The important launcher findings from bring-up were:

- Direct `srun` initially failed in `MPI_Init_thread` because OpenMPI retained
  an inaccessible original `/proj/nv/...` prefix.
- Test-local `OPAL_PREFIX="$MPI_SHIM"` fixed that relocation problem.
- A temporary `mpirun` launch inherited batch-level `SLURM_LOCALID=0`, causing
  every process to select GPU 0.
- Returning to direct `srun` with `OPAL_PREFIX` gave correct rank mapping and
  eliminated the CLM coordinate abort seen in the `mpirun` attempt.

The shared environment loader is intentionally not changed by these jobs. Its
runtime path remains minimal because adding sibling HPC-X UCX/UCC/HCOLL paths
previously reintroduced CLM coordinate failures.

## Job History and Results

### Cancelled First 8-GPU Submission

Job `50160651` was allocated nodes `lrdn[2884-2885]` but was cancelled by UID 0
after 21 minutes 41 seconds. Slurm recorded no reason, admin comment, or system
comment. No batch step, log, or output file was created, so this was an
administrative/system cancellation before RegCM launched, not a model failure.

### Successful 8-GPU Reference

| Item | Result |
| --- | --- |
| Job ID | `50289272` |
| State | `COMPLETED` |
| Exit code | `0:0` |
| Nodes | `lrdn[0115,0119]` |
| Slurm elapsed time | 01:30:36, or 5436 seconds |
| RegCM model elapsed time | 5428.5812 seconds |
| Runtime per simulated day | 775.5116 seconds/day |
| Simulation speed | Approximately 111.4 times real time |
| Final time | 2009-10-08 00:00:00 UTC |
| Stderr | Empty |
| Final marker | `RegCM V5 simulation successfully reached end` |

The run wrote all requested daily NetCDF containers with hourly records, CLM
history, and final restart files. Its output occupied approximately 424 GiB at
the time this report was created. After the run was validated and documented,
its 33 NetCDF output files were deleted to reclaim that scratch space; the logs
and test configuration were retained.

Logs:

```text
Test_8gpu_8proc/production/newest/LOG_7d_8gpu_wIO_test_50289272.out
Test_8gpu_8proc/production/newest/LOG_7d_8gpu_wIO_test_50289272.err
```

### Completed Scaling Runs

| GPUs | Job ID | State / exit | Nodes | Slurm elapsed | Model elapsed (s) | Stderr |
| ---: | ---: | --- | --- | ---: | ---: | --- |
| 4 | `50328146` | `COMPLETED` / `0:0` | `lrdn3410` | 03:54:11 | 14042.8682 | Empty |
| 8 | `50289272` | `COMPLETED` / `0:0` | `lrdn[0115,0119]` | 01:30:36 | 5428.5812 | Empty |
| 16 | `50328144` | `COMPLETED` / `0:0` | `lrdn[1447,1493,1500,1527]` | 00:57:04 | 3415.7813 | Empty |
| 32 | `50328145` | `COMPLETED` / `0:0` | `lrdn[0731,1305,1334,1378,1408,1437,3380,3398]` | 00:47:44 | 2855.8972 | Empty |

All runs passed the validation criteria below. Each used four MPI ranks per
node, mapped local ranks 0-3 to the four local GPUs, recognized the full
168-hour simulation, wrote the final restart and output files, and ended with:

```text
RegCM V5 simulation successfully reached end
```

The 4-, 16-, and 32-GPU runs were submitted together and ran on the nodes shown
above. The 8-GPU reference was run separately after its first submission was
cancelled before launch.

Final logged surface-pressure extrema were consistent to the displayed
precision: the minimum was 683.26-683.27 hPa and the maximum was 968.42 hPa.
The validation establishes successful completion and a consistent output-file
structure, but not bitwise numerical equivalence between decompositions. No
field-by-field NetCDF comparison was performed, and the 8-GPU NetCDF files are
no longer available for such a comparison.

## Strong-Scaling Results

The 4-GPU run is the scaling baseline. Speedup and parallel efficiency are:

```text
speedup(N) = T4 / TN
efficiency(N) = speedup(N) / (N / 4)
```

The primary comparison uses RegCM's `Total elapsed seconds of run` value and
therefore includes model computation and the requested sequential NetCDF I/O.

| GPUs | Model time (s) | Speedup vs. 4 GPUs | Parallel efficiency | Simulation speed |
| ---: | ---: | ---: | ---: | ---: |
| 4 | 14042.8682 | 1.0000 | 100.00% | 43.07x real time |
| 8 | 5428.5812 | 2.5868 | 129.34% | 111.41x real time |
| 16 | 3415.7813 | 4.1112 | 102.78% | 177.06x real time |
| 32 | 2855.8972 | 4.9171 | 61.46% | 211.77x real time |

### Throughput and Compute Time per Simulated Day

Throughput and its inverse are calculated from RegCM's model elapsed time:

```text
throughput (simulated days/hour) = 7 * 3600 / model_time_seconds
compute time (seconds/simulated day) = model_time_seconds / 7
compute time (hours/simulated day) = 1 / throughput
```

| GPUs | Throughput (simulated days/hour) | Compute time (seconds/simulated day) | Compute time (hours/simulated day) |
| ---: | ---: | ---: | ---: |
| 4 | 1.7945 | 2006.12 | 0.5573 |
| 8 | 4.6421 | 775.51 | 0.2154 |
| 16 | 7.3775 | 487.97 | 0.1355 |
| 32 | 8.8238 | 407.99 | 0.1133 |

Here, compute time means model elapsed wall-clock time for the full allocation,
not the GPU-hour allocation cost reported below.

Slurm elapsed time was only 7.42-8.22 seconds longer than RegCM's measured time
for every configuration. Startup and shutdown overhead outside the model timer
was therefore small and nearly constant.

| GPUs | Slurm time (s) | Slurm minus model (s) | Allocated GPU-hours |
| ---: | ---: | ---: | ---: |
| 4 | 14051 | 8.13 | 15.61 |
| 8 | 5436 | 7.42 | 12.08 |
| 16 | 3424 | 8.22 | 15.22 |
| 32 | 2864 | 8.10 | 25.46 |

Allocated GPU-hours are calculated from the Slurm elapsed time multiplied by
the requested GPU count. They measure allocation cost, not energy consumption.

### Scaling Interpretation

- Increasing from 4 to 8 GPUs reduced runtime by 61.34% and produced a 2.5868x
  speedup. The resulting 129.34% efficiency is superlinear relative to the
  4-GPU baseline, potentially reflecting a smaller per-rank working set and
  better memory/cache behavior. This experiment does not isolate the cause.
- Increasing from 8 to 16 GPUs reduced runtime by a further 37.08%. The
  incremental speedup was 1.5893x, or 79.46% efficiency for that doubling.
- Increasing from 16 to 32 GPUs reduced runtime by only 16.39%. The incremental
  speedup was 1.1960x, or 59.80% efficiency for that doubling, showing that this
  problem is entering a strong-scaling plateau.
- The 32-GPU run gave the shortest time to solution: 47 minutes 35.9 seconds of
  model time, 79.66% less than the 4-GPU run.
- The 8-GPU run used the fewest allocation resources at 12.08 GPU-hours. Moving
  from 8 to 16 GPUs increased GPU-hour cost by 25.97%, and moving from 16 to 32
  GPUs increased it by 67.29%.
- On this single-run evidence, 8 GPUs is the resource-efficient choice, 16 GPUs
  is a useful time-to-solution compromise, and 32 GPUs is justified only when
  the shortest elapsed time is more important than allocation efficiency.

The plateau cannot be assigned to one subsystem from elapsed times alone.
Increasing MPI communication, fixed or serial model work, and sequential output
are all possible contributors. Profiling is required to separate them. The
superlinear 4-to-8 result and exact percentages should also be treated as point
estimates because each configuration was run once, and the 8-GPU job ran at a
different time and on different nodes from the other three jobs.

## Output and Log Locations

Project test root:

```text
/leonardo/home/userexternal/ctica000/MS_thesis/RegCM/Benchmark/with_IO/1003_1003_50_7days_with_IO/sequential_output/Non_MPS_stdpar
```

Scratch output root:

```text
/leonardo_scratch/large/userexternal/ctica000/1003_1003_50_7days_Benchmark/openacc_with_do_concurrent
```

| Test | Log directory | Scratch output directory | NetCDF files | Retained size |
| --- | --- | --- | ---: | ---: |
| 4 GPU | `Test_4gpu_4proc/production/newest` | `Test_4gpu_4proc/output` | 33 | About 424 GiB |
| 8 GPU | `Test_8gpu_8proc/production/newest` | `Test_8gpu_8proc/output` | 33 written, then deleted | 0 |
| 16 GPU | `Test_16gpu_16proc/production/newest` | `Test_16gpu_16proc/output` | 33 | About 424 GiB |
| 32 GPU | `Test_32gpu_32proc/production/newest` | `Test_32gpu_32proc/output` | 33 | About 424 GiB |

All `input` links point to:

```text
/leonardo_scratch/large/userexternal/ggiulian/testio/input
```

The retained 4-, 16-, and 32-GPU output occupies approximately 1.24 TiB in
total. Each configuration generated the same 33-file structure and
approximately 424 GiB of data. The 8-GPU files had the same count and size
before they were deleted after validation.

## Known Warning

All tested launches print a nonfatal UCX warning similar to:

```text
UCP API version is incompatible: required >= 1.20, actual 1.15.0
```

The library is loaded from `/lib64/libucp.so.0`. The validated one-day run and
all four seven-day runs completed successfully despite this warning. It should
be recorded but is not currently treated as a model failure. Any attempt to
alter the shared loader to remove it requires a separate controlled test because
the full sibling HPC-X component path previously triggered CLM coordinate
errors.

## Validation Criteria

A scaling run is considered valid only when all of the following hold:

- Slurm state is `COMPLETED`.
- Exit code is `0:0`.
- All ranks map one-to-one to local GPUs 0-3.
- RegCM reports the expected MPI-rank count and decomposition.
- CLM prints `Checked LAT/LON compliance`.
- CLM initializes successfully.
- The requested final time `2009-10-08 00:00:00 UTC` is reached.
- Final ATM, SRF, STS, RAD, SAV, and CLM restart writes complete.
- Stderr contains no fatal model, CUDA, MPI, or Slurm errors.
- The log ends with `RegCM V5 simulation successfully reached end`.

## Data-Cleanup Record

Before this scaling experiment, 66 old NetCDF files were removed from the
linked seven-day DCGP `200proc` and `400proc` output targets. This reclaimed
approximately 318 GiB. The current 4/8/16/32-GPU test outputs were not included
in that initial cleanup. After successful validation, the 33 NetCDF files from
the 8-GPU run were removed separately, reclaiming approximately 424 GiB. The
completed 4-, 16-, and 32-GPU outputs were retained and occupy approximately
1.24 TiB in total. The five-day benchmark was also checked, but its output link
was dangling and no NetCDF files were present.

## Reproduction and Monitoring

Submit a test from its folder with the corresponding script, for example:

```bash
sbatch submit_8gpu_task.job
```

Inspect the completed scaling jobs:

```bash
sacct -j 50289272,50328146,50328144,50328145 --format=JobID,JobName,State,ExitCode,Elapsed,Timelimit,NodeList
```

Extract the model timers and final markers:

```bash
rg 'Total elapsed seconds of run|simulation successfully reached end' Test_*gpu_*proc/production/newest/*.out
```
