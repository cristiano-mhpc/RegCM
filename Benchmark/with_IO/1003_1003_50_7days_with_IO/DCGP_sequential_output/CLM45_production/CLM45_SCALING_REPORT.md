# RegCM5 CLM4.5 CPU Strong-Scaling Report on Leonardo DCGP

Report date: 2026-07-22

## 1. Scope and objective

This report documents the seven-day RegCM5 CPU/MPI strong-scaling experiment
performed on the Leonardo Data-Centric General-Purpose (DCGP) partition. The
same EURR-3 simulation was run at 200, 400, 800, 1200, and 1600 MPI ranks. The
objective was to measure scaling with realistic model I/O, while holding the
domain, physics, forcing, executable, and output frequencies fixed.

The main findings are:

- The 200-, 400-, and 800-rank runs completed successfully.
- Their scheduler elapsed times were `19:07:02`, `08:18:36`, and `04:02:37`,
  respectively.
- The 1600-rank model completed all seven simulated days and reported
  `02:14:13.3583` of accumulated model time, but the Slurm step stalled in a
  PMIx collective during finalization. It was cancelled after `02:20:53`.
- Two independent 1200-rank attempts failed reproducibly near the same point
  in simulation day four with a CLM urban longwave-radiation `NaN`.
- The 1200-rank failure is a model numerical failure, not a PMIx launch error.
- The explicit `srun --mpi=pmix_v3` setting was retained. Omitting it would not
  change the selected plugin because Leonardo's Slurm default is `pmix_v3`.

## 2. Repository and run locations

Repository root:

```text
/leonardo/home/userexternal/ctica000/MS_thesis/RegCM
```

Seven-day production root:

```text
/leonardo/home/userexternal/ctica000/MS_thesis/RegCM/Benchmark/with_IO/1003_1003_50_7days_with_IO/DCGP_sequential_output/CLM45_production
```

Scratch-output root:

```text
/leonardo_scratch/large/userexternal/ctica000/1003_1003_50_7days_Benchmark/DCGP_sequential_output/CLM45_production
```

The production root contains one directory per rank count, the namelists,
submission scripts, rank launcher, and scheduler logs. Each `output` entry is a
symlink to a separate directory under the scratch-output root.

## 3. Executable identity

The benchmark used only this executable:

```text
/leonardo/home/userexternal/ctica000/MS_thesis/RegCM/bin/clm45/regcmMPICLM45
```

Verified properties:

| Property | Value |
|---|---|
| SHA-256 | `b3feb4984dbe82e2b6e6d295e13ba100d924157d2692c6f01b44b9999368e452` |
| Size | 45,576,648 bytes |
| ELF type | 64-bit x86-64, dynamically linked |
| Debug state | Contains debug information; not stripped |
| File modification time | 2026-07-20 15:31:30 +0200 |
| Embedded compilation time | 2026-07-20 15:29:48 |
| Embedded source revision | `27e37e-dirty` |
| Full repository commit at inspection | `27e37ef7933c752c332347f93b66207705523bf5` |

The `dirty` suffix is important: the executable was built from a worktree with
local source modifications. The exact dirty patch embedded in the binary
cannot be reconstructed from the ELF alone. At report time the repository was
still dirty, including a local change in
`Main/clmlib/clm4.5/mod_clm_urban.F90`, but this does not prove that every
current worktree modification was present when the executable was linked.

The executable is the CPU CLM4.5 MPI target. It is distinct from the repository's
OpenACC/stdpar GPU executables. Runtime dependency inspection in the matching
environment showed MPI, NVHPC CPU runtime, NetCDF, Parallel-NetCDF, and HDF5
libraries, with no CUDA runtime dependency in this executable.

## 4. Compiler and software environment

Every job sourced:

```text
/leonardo/home/userexternal/ctica000/MS_thesis/RegCM/environment_loaders/regcm5_leonardo_nvhpc_hpcx.sh
```

The loader begins from `module purge` and loads:

| Component | Version or setting |
|---|---|
| Spack module | `spack/0.22-06` |
| Binutils | `2.42` |
| NVIDIA HPC SDK | `25.11` |
| CUDA module | `12.2` |
| C compiler | `nvc` |
| C++ compiler | `nvc++` |
| Fortran compiler | `nvfortran 25.11-0` |
| MPI wrappers | `mpicc`, `mpifort` |
| MPI distribution | HPC-X 2.25.1 |
| Open MPI version reported by `mpirun` | `4.1.9a1` |
| NetCDF-C | `4.9.2` |
| NetCDF-Fortran | `4.6.1` |
| Parallel-NetCDF | `1.12.3` |
| HDF5 | `1.14.3` |

The active `nvfortran` reports an x86-64 `icelake-server` target. CUDA is
loaded because this is the shared NVHPC environment, but these benchmark jobs
run on CPU-only DCGP nodes and the selected executable is not a GPU target.

The matching Spack environment and MPI shim are:

```text
REGCM_SPACK_ENV=/leonardo_work/ICT26_ESP_0/christian/spack-envs/regcm5-leonardo-nvhpc-hpcx
REGCM_SPACK_VIEW=/leonardo_work/ICT26_ESP_0/christian/spack-envs/regcm5-leonardo-nvhpc-hpcx/.spack-env/view
MPI_SHIM=/leonardo_work/ICT26_ESP_0/christian/externals/hpcx-mpi-2.25.1-ompi-shim
```

Important runtime environment behavior:

- The MPI shim's `bin` and `lib` paths are placed before other MPI paths.
- `OMPI_MCA_coll=^ucc` disables UCC collectives in the loader.
- The jobs export `OPAL_PREFIX="$MPI_SHIM"`.
- The jobs suppress the irrelevant missing-libcuda warning with
  `OMPI_MCA_opal_warn_on_missing_libcuda=0`.
- The rank wrapper sets `OMP_NUM_THREADS` from `SLURM_CPUS_PER_TASK`; this was
  one for all runs.
- The jobs set `ulimit -s unlimited` before launch.

### 4.1 Build-provenance limitation

The exact original configure command and complete CPU compiler/link flags for
`bin/clm45/regcmMPICLM45` were not retained in a dedicated immutable build
record. The current top-level `config.log` contains
`./configure --enable-clm45 --enable-openacc-stdpar`; it belongs to a later GPU
configuration and must not be presented as the configuration of this CPU
benchmark executable. The executable hash, embedded revision/time, compiler
family, and dynamically resolved runtime libraries above are verified; more
specific CPU build flags would be speculation.

## 5. Leonardo DCGP hardware and Slurm

The jobs ran in the `dcgp_usr_prod` partition under account `ICT26_MHPC`.
A representative allocated DCGP node reported:

| Node property | Value |
|---|---|
| Architecture | x86-64 |
| Sockets | 2 |
| Cores per socket | 56 |
| Hardware threads per core | 1 |
| Slurm CPUs per node | 112 |
| Configured memory | 514,000 MiB |
| Allocatable memory observed | 492,800 MiB |
| Configured tmpfs GRES | 3 TiB |
| Operating system | RHEL 8 family, Linux 4.18.0-477.27.1.el8_8 |

Each benchmark requested 100 MPI ranks per node, leaving 12 physical cores per
node unused by MPI. Nodes were requested exclusively, so Slurm accounting shows
112 allocated CPUs per node even though only 100 MPI tasks were launched.

Relevant Slurm configuration observed during the experiment:

| Setting | Value |
|---|---|
| Cluster | `leonardo` |
| Slurm | `24.05.7-BullSequana.1.1` |
| Default MPI plugin | `pmix_v3` |
| PMIx ports | `13000-18000` |
| Task plugins | `task/cgroup,task/affinity` |
| Resource selection | `CR_CORE_MEMORY,CR_CORE_DEFAULT_DIST_BLOCK` |

## 6. Simulation configuration

All production directories used the same namelist content. The SHA-256 of the
200-rank copy is:

```text
f25ac697748a93ca43f9a7d6ae759de559173639621bb7cfaf89b14a543f4870
```

The canonical namelist is `200proc/EURR-3_namelist.in`; the other rank
directories were created as identical copies.

### 6.1 Domain and integration

| Parameter | Value |
|---|---|
| Domain | `EURR-3` |
| Horizontal dimensions | 1003 x 1003 |
| Vertical levels | 50 |
| Projection | `ROTLLR` |
| Grid spacing | `ds = -0.03` |
| Dynamics | `idynamic = 3` |
| Time step | 45 seconds |
| Calendar | Gregorian |
| Initial time | 2009-10-01 00:00 |
| Final time | 2009-10-08 00:00 |
| Restart mode | Disabled for initial launch |

The forcing configuration uses ERA5 (`dattyp='ERA5'`) and daily ERA5 SST
(`ssttyp='ERA5D'`), with six-hour boundary forcing (`ibdyfrq=6`). The forcing
and radiation-climatology paths point under:

```text
/leonardo_work/ICT26_ESP/RCMDATA
```

The scenario is `SSP585`. CLM4.5 uses the specified PFT physiology, SNICAR
optics, and snow-aging files. Urban waste heat is enabled with
`urban_hac='ON_WASTEHEAT'`.

Other fixed physics and boundary settings included:

| Setting | Value |
|---|---:|
| Boundary scheme (`iboudy`) | 5 |
| Boundary-layer scheme (`ibltyp`) | 1 |
| Land/ocean convection (`icup_lnd`, `icup_ocn`) | 0 / 0 |
| Resolved precipitation (`ipptls`) | 2 |
| Wave coupling (`iwavcpl`) | 0 |
| Ocean flux (`iocnflx`) | 2 |
| Ocean roughness (`iocnrough`) | 1 |
| Sea ice (`iseaice`) | 1 |
| Convective liquid-water path (`iconvlwp`) | 1 |
| Cloud fraction (`icldfrac`) | 0 |
| Climatological ozone (`iclimao3`) | 1 |
| Climatological aerosol (`iclimaaer`) | 2 |
| Cloud parameter (`ncld`) | 0 |
| Spectral boundary widths (`nspgx`, `nspgd`) | 31 / 31 |
| High/medium/low nudging | 6.0 / 4.0 / 2.0 |
| CLM surface-water flag (`h2osfcflag`) | 1 |
| CLM original hydrology flags (`origflag`, `oldfflag`) | 0 / 0 |

### 6.2 I/O behavior

This is an I/O-inclusive benchmark, not a compute-only microbenchmark.
Important namelist settings are:

| Setting | Value |
|---|---|
| CORDEX output | Enabled |
| ATM output frequency | 24 hours |
| RAD output frequency | 24 hours |
| SRF output frequency | 24 hours |
| STS output | Enabled |
| Save/restart output | Enabled |
| Parallel NetCDF input | Enabled |
| Parallel NetCDF output | Disabled |
| Output synchronization | `lsync=.false.` |

Therefore, input can use parallel NetCDF, but the requested output mode is
sequential NetCDF. A successful seven-day run produced 40 entries: seven each
for ATM, RAD, SRF, STS, and timing text; one atmospheric save file; one CLM
history file; and three CLM restart/history-restart files.

## 7. Input and output layout

All rank counts shared the same approximately 104 GiB input tree. Their
`input` symlinks point through the legacy 800-rank input:

```text
CLM45_production/<rank>proc/input -> ../../800proc/input
```

This avoids copying the forcing and preprocessed domain files. Each launch
verified at least these required files before starting:

```text
input/EURR-3_DOMAIN000.nc
input/EURR-3_ICBC.2009100100.nc
input/EURR-3_CLM45_surface.nc
```

Each rank count had an independent output symlink to the scratch-output root.
Submission scripts refused to run when their output directory was non-empty,
preventing accidental overwrite. Scheduler stdout and stderr remained in each
rank directory's `production` directory rather than in scratch output.

## 8. MPI and launch method

The shared rank wrapper is:

```text
CLM45_production/run_regcm_rank.sh
```

It validates the Slurm rank variables, sets one OpenMP thread, and replaces
itself with the model process:

```bash
exec /leonardo/home/userexternal/ctica000/MS_thesis/RegCM/bin/clm45/regcmMPICLM45 EURR-3_namelist.in
```

The submission scripts launch with:

```bash
srun --mpi=pmix_v3 \
  --ntasks=<rank-count> \
  --ntasks-per-node=100 \
  --kill-on-bad-exit=1 \
  "$RUN_ROOT/run_regcm_rank.sh"
```

Using `--mpi=none` would not be a valid substitute for this MPI application.
Simply omitting `--mpi=pmix_v3` would still select PMIx v3 because that is the
cluster default. Keeping the option explicit records the launch protocol and
improves reproducibility.

## 9. Requested resources

Common requests were one CPU per task, 100 tasks per node, exclusive nodes,
all node memory (`--mem=0`), and `tmpfs:10g` per node.

| MPI ranks | Nodes | Tasks/node | Requested wall time |
|---:|---:|---:|---:|
| 200 | 2 | 100 | 24:00:00 |
| 400 | 4 | 100 | 12:00:00 |
| 800 | 8 | 100 | 06:00:00 |
| 1200 | 12 | 100 | 04:00:00 |
| 1600 | 16 | 100 | 03:00:00 |

## 10. Validation run

Before the seven-day campaign, one simulated day was tested at 800 ranks:

| Item | Value |
|---|---|
| Job ID | `49933820` |
| Job name | `clm45_800test` |
| State | `COMPLETED` |
| MPI-step elapsed | `00:39:57` |
| Whole allocation elapsed | `00:40:05` |
| Nodes/ranks | 8 / 800 |
| Exit code | `0:0` |

The successful MPI step established that the executable, CLM4.5 inputs,
NVHPC/HPC-X environment, PMIx v3 launch, and 100-rank-per-node layout worked at
800 ranks before longer jobs were submitted.

## 11. Seven-day job accounting

| Ranks | Job ID | Slurm state | Scheduler elapsed | Internal model time | Exit | Interpretation |
|---:|---:|---|---:|---:|---:|---|
| 200 | `49996848` | `COMPLETED` | `19:07:02` | `19:06:38.394` | `0:0` | Valid full run |
| 400 | `49996845` | `COMPLETED` | `08:18:36` | `08:18:13.698` | `0:0` | Valid full run |
| 800 | `49996844` | `COMPLETED` | `04:02:37` | `04:02:13.082` | `0:0` | Valid full run |
| 1200 | `50034948` | `FAILED` | `01:28:40` | Partial only | `1:0` | CLM urban `NaN` in day four |
| 1200 | `50041522` | `FAILED` | `01:28:53` | Partial only | `1:0` | Reproduced same CLM failure |
| 1600 | `50029747` | `CANCELLED` | `02:20:53` | `02:14:13.3583` | cancelled | Model finished; PMIx finalization stalled |

The internal model times are sums of the seven daily
`EURR-3.YYYYMMDDHH.txt` values written by RegCM. Scheduler elapsed includes
batch startup, environment setup, and process teardown. For the clean runs the
difference between scheduler and internal time was only about 22-24 seconds.

### 11.1 Daily internal timings

| Simulated day | 200 ranks (s) | 400 ranks (s) | 800 ranks (s) | 1600 ranks (s) |
|---:|---:|---:|---:|---:|
| 1 | 10105.660 | 4472.282 | 2203.814 | 1298.029 |
| 2 | 9865.102 | 4209.155 | 2056.428 | 1019.672 |
| 3 | 9768.664 | 4224.586 | 2071.431 | 1025.953 |
| 4 | 9723.258 | 4212.900 | 2115.924 | 994.4783 |
| 5 | 9758.941 | 4223.068 | 2071.778 | 1044.081 |
| 6 | 9791.023 | 4246.078 | 1978.312 | 1034.193 |
| 7/final | 9785.746 | 4305.629 | 2035.395 | 1636.952 |
| **Total** | **68798.394** | **29893.698** | **14533.082** | **8053.3583** |

The 1600-rank final slice was noticeably slower than its middle slices and
included final output/restart work. Its total is useful for model-integration
performance, but the run is not a clean scheduler-level completion.

### 11.2 Strong-scaling indicators

Using the valid 200-rank internal time as the reference:

| Ranks | Internal time (s) | Speedup vs. 200 | Parallel efficiency vs. 200 |
|---:|---:|---:|---:|
| 200 | 68798.394 | 1.0000 | 100.00% |
| 400 | 29893.698 | 2.3014 | 115.07% |
| 800 | 14533.082 | 4.7339 | 118.35% |
| 1600 | 8053.3583 | 8.5428 | 106.79% |

The apparent superlinear efficiency at 400 and 800 ranks should not be read as
pure compute scaling. This benchmark includes sequential output, filesystem
effects, changing per-rank working-set sizes, cache effects, and potentially
rank-decomposition-dependent behavior. The 1600 value is additionally marked
provisional because final MPI teardown did not complete.

## 12. 1200-rank failure

### 12.1 First attempt

Job `50034948` ran from 2026-07-21 15:39:33 to 17:08:13 and failed after
`01:28:40`. It completed three timing periods:

```text
Day 1: 1656.462 s
Day 2: 1290.709 s
Day 3: 1277.172 s
Total recorded complete periods: 4224.343 s
```

It had begun writing day-four stream files when the model aborted.

### 12.2 Reproduction

The failed output was moved aside, a fresh empty scratch directory was created,
and the unchanged job was resubmitted as `50041522`. It ran on a different set
of compute nodes from 2026-07-21 22:58:42 to 2026-07-22 00:27:35 and failed
after `01:28:53`. Its first three periods were:

```text
Day 1: 1570.729 s
Day 2: 1350.615 s
Day 3: 1311.072 s
Total recorded complete periods: 4232.416 s
```

Both attempts stopped with the same model fatal error:

```text
urban net longwave radiation error: no convergence
Critical = NaN > 0.001 !
Fatal in file: mod_clm_urban.F90 at line: 2712
clm now stopping
```

At the reported source location, CLM checks `found(1)` after the iterative
urban longwave calculation and calls `fatal` when convergence failed. The
reported critical value was already `NaN`, so this was not merely a small
tolerance exceedance.

Because the same failure occurred at effectively the same simulation point on
different nodes, it is reproducible for this 1200-rank decomposition. The
available evidence does not establish the first operation that generated the
`NaN`; it only establishes where CLM detected it. The two failed jobs are not
valid seven-day benchmark measurements.

## 13. 1600-rank finalization failure

The 1600-rank model reached 2009-10-08 00:00 and produced the complete expected
40-entry output set, including the final atmospheric save and CLM restart
files. The seven internal timing files summed to `8053.3583` seconds
(`02:14:13.3583`).

After final output, the Slurm step remained `RUNNING` while stderr accumulated
messages such as:

```text
mpi/pmix_v3: pmixp_coll_tree_reset_if_to: collective timeout seq=1
mpi/pmix_v3: pmixp_coll_log: Dumping collective state
```

The PMIx diagnostics showed an incomplete collective contribution across the
16 nodes. Model output stopped changing while PMIx errors continued, indicating
that the simulation work was complete but not all ranks/nodes completed the
launcher's final collective. Job `50029747` was manually cancelled at
`02:20:53` to release the allocation and allow later work to proceed.

The 1600-rank internal total can be used as a qualified model-integration
timing, but the run must be labelled as not having completed MPI finalization.
It must not be represented as a clean successful production job.

This incident does not establish that explicit `--mpi=pmix_v3` is generally
incorrect: the one-day test and the 200-, 400-, and 800-rank runs all used the
same PMIx v3 method successfully. PMIx reported the incomplete final collective;
the present evidence does not prove whether the initiating condition was a
rank delayed in final file closure, a rank-specific failure, or a PMIx/Slurm
issue at this scale.

## 14. Output retention and cleanup

After all timing and failure evidence was recorded, scratch output contents
were deleted at user request for every rank count except 200 and 400.

Current state:

| Scratch directory | State |
|---|---|
| `200proc` | Complete 40-entry output retained |
| `400proc` | Complete 40-entry output retained |
| `800proc` | Empty |
| `1200proc_failed_50034948` | Empty |
| `1200proc` | Empty |
| `1600proc` | Empty |

Only scratch model outputs were deleted. Namelists, submission scripts, shared
inputs, environment scripts, production stdout/stderr logs, scheduler
accounting records, and this report were preserved. The detailed 800-, 1200-,
and 1600-rank timing values in this report were captured before deletion.

## 15. Evidence map

| Evidence | Location |
|---|---|
| Environment loader | `environment_loaders/regcm5_leonardo_nvhpc_hpcx.sh` |
| Model executable | `bin/clm45/regcmMPICLM45` |
| Shared rank launcher | `CLM45_production/run_regcm_rank.sh` |
| Namelists | `CLM45_production/<rank>proc/EURR-3_namelist.in` |
| Submission scripts | `CLM45_production/<rank>proc/submit_<rank>task.job` |
| Scheduler logs | `CLM45_production/<rank>proc/production/` |
| Retained model output | scratch `200proc/` and `400proc/` |
| First 1200 failure log | `1200proc/production/LOG_clm45_7d_1200_50034948.err` |
| Second 1200 failure log | `1200proc/production/LOG_clm45_7d_1200_50041522.err` |
| 1600 PMIx log | `1600proc/production/LOG_clm45_7d_1600_50029747.err` |

Paths shown as `CLM45_production/...` are relative to the production root in
Section 2. Scheduler records can be queried with `sacct` using the job IDs in
Section 11 while they remain in the site's accounting retention window.

## 16. Interpretation and next steps

The clean 200/400/800 results establish strong scaling through eight DCGP
nodes for this I/O-inclusive configuration. The 1200-rank point cannot be added
to the scaling curve without resolving the reproducible CLM numerical failure.
The 1600-rank point is informative but provisional because its MPI step did not
terminate cleanly.

For a defensible continuation of the study:

1. Preserve the current executable by hash; do not silently replace it between
   rank-count tests.
2. Produce an immutable CPU build manifest containing the exact configure
   command, compiler flags, dependency hashes, source diff, and executable hash.
3. Reproduce the 1200-rank failure with floating-point exception trapping or
   targeted diagnostics before changing the convergence check.
4. Test whether the 1200-rank failure follows the automatic domain
   decomposition rather than node placement.
5. If rerunning 1600 ranks, add rank-level finalization diagnostics and monitor
   final NetCDF closure separately from `MPI_Finalize`/PMIx teardown.
6. Report clean scheduler elapsed times and internal model times separately.
