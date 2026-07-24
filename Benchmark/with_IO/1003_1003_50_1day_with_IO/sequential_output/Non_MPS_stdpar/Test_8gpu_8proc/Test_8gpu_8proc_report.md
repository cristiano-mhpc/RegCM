# RegCM 8-GPU Test Bring-Up and Validation Report

## Scope

This report documents the changes and troubleshooting stages required to build
and run the 1003 x 1003 x 50, one-day RegCM test with CLM 4.5 on eight NVIDIA
A100 GPUs. The final test used eight MPI ranks on two Leonardo Booster nodes,
with four ranks and four GPUs per node.

Test directory:

```text
/leonardo/home/userexternal/ctica000/MS_thesis/RegCM/Benchmark/with_IO/1003_1003_50_1day_with_IO/sequential_output/Non_MPS_stdpar/Test_8gpu_8proc
```

## Final Result

Slurm job `50035448` completed the full 24-hour simulation successfully.

| Item | Result |
| --- | --- |
| Slurm state | `COMPLETED` |
| Exit code | `0:0` |
| Nodes | `lrdn[0685,0757]` |
| MPI ranks | 8 |
| GPUs | 8 A100 GPUs |
| Slurm elapsed time | 00:16:34, or 994 seconds |
| RegCM model elapsed time | 897.4796 seconds |
| Model final time | 2009-10-02 00:00:00 UTC |
| Stderr | Empty |
| Final marker | `RegCM V5 simulation successfully reached end` |

The 96.5-second difference between Slurm elapsed time and model elapsed time is
outside the RegCM model timer. It includes module and Spack setup, dependency
checks, GPU discovery, Slurm/MPI process startup, and shutdown. The model did
not stall: its logged start and stop times were 21:34:03 and 21:49:01.

The successful output log is:

```text
production/newest/LOG_1d_8gpu_wIO_test_50035448.out
```

The successful, empty error log is:

```text
production/newest/LOG_1d_8gpu_wIO_test_50035448.err
```

## Build Configuration

The working build uses:

- NVHPC 25.11
- CUDA 12.2
- HPC-X/OpenMPI 2.25.1 through the user MPI shim
- NVHPC-built NetCDF-C, NetCDF-Fortran, PnetCDF, and HDF5
- OpenACC and Fortran standard parallelism
- NVIDIA A100 target architecture `cc80`
- CUDA managed memory and relocatable device code

The relevant compiler options are:

```text
-acc -stdpar=gpu -gpu=cc80,lineinfo,mem:managed,rdc
```

The final build is recorded in:

```text
/leonardo/home/userexternal/ctica000/MS_thesis/RegCM/build_urban_serial_nvhpc.log
```

The log ends normally without compiler, NVLink, linker, or `make` errors. It
shows that `mod_clm_urban.F90` was recompiled and that `regcm` and `clmsa` were
linked with the required OpenACC, stdpar, managed-memory, and RDC flags.

The final executable copies are byte-identical:

| Executable | Size | SHA-256 |
| --- | ---: | --- |
| `Main/regcm` | 114077976 bytes | `716830495962f52474cda4cb0c09529b5f854988eebf8881c7454b8137f12fc9` |
| `bin/regcmMPICLM45_OPENACC_STDPAR` | 114077976 bytes | `716830495962f52474cda4cb0c09529b5f854988eebf8881c7454b8137f12fc9` |

The executable contains an `sm_80` CUDA image for the Leonardo A100 GPUs.

## Troubleshooting Stages

### 1. Build and Device-Link Fixes

The OpenACC/stdpar configuration was made consistent by adding `-acc`, using
the fixed A100 target `cc80`, and adding `rdc` to the GPU options.

The RDC build exposed missing OpenACC device definitions for microphysics
module scalars. The affected coefficients were declared as device variables and
updated after host initialization. Eleven scalar values are transferred once
during initialization, so these updates have negligible steady-state runtime
cost.

After these changes, the full executable linked successfully.

### 2. Job 49885855: Direct srun MPI Initialization Failure

| Item | Result |
| --- | --- |
| State | `FAILED` |
| Exit code | `1:0` |
| Elapsed | 00:00:05 |

The initial direct `srun` launch mapped local ranks to GPUs correctly, but all
ranks failed in `MPI_Init_thread`. OpenMPI attempted to use its original NVHPC
installation prefix under `/proj/nv/...`, which is not available on Leonardo.

The test job was changed to export:

```bash
export OPAL_PREFIX="$MPI_SHIM"
```

This makes OpenMPI use the accessible user-owned HPC-X shim prefix.

### 3. Job 50022898: mpirun Rank Mapping and CLM Coordinate Failure

| Item | Result |
| --- | --- |
| State | `FAILED` |
| Exit code | `1:0` |
| Elapsed | 00:00:47 |

Launching with `mpirun` allowed MPI initialization to complete, but every
process inherited batch-level `SLURM_LOCALID=0` and `SLURM_PROCID=0`. The
wrapper preferred those variables over the OpenMPI rank variables, so all eight
processes selected `CUDA_VISIBLE_DEVICES=0`.

The run then aborted while comparing CLM domain and surface-file coordinates,
producing many `ERROR coordinates at n` messages. This coordinate failure
disappeared after returning to the known working Slurm launch method.

The test retained `OPAL_PREFIX` and changed the launch back to:

```bash
srun ./STD_launch_per_rank.sh
```

This restored correct Slurm global and local ranks and one MPI rank per GPU.

### 4. Job 50032177: CUDA Error in UrbanFluxes

| Item | Result |
| --- | --- |
| State | `FAILED` |
| Exit code | `1:0` |
| Elapsed | 00:01:39 |

This run established that the launcher and input path were correct:

- Ranks 0-3 selected GPUs 0-3 on the first node.
- Ranks 4-7 selected GPUs 0-3 on the second node.
- MPI initialized successfully.
- CLM printed `Checked LAT/LON compliance`.
- CLM completed land-model initialization.
- Initial output files were opened and written.

All ranks then failed in the first model timestep with CUDA error 719:

```text
Accelerator Fatal Error: call to cuStreamSynchronize returned error 719
File: Main/clmlib/clm4.5/mod_clm_urban.F90
Function: urbanfluxes
Line: 3353
```

The failing statement was a `do concurrent` loop that the source already
identified as failing on some NVHPC GPU builds and already provided a serial
fallback for. The preprocessor condition was changed to select that fallback.

### 5. Rebuild and Job 50035448: Successful Validation

After rebuilding and copying the verified executable into `bin`, job
`50035448` completed successfully in 00:16:34.

Validation evidence includes:

- Correct one-rank-per-GPU mapping on both nodes
- Successful MPI initialization
- Successful CLM latitude/longitude compliance check
- Successful CLM land-model initialization
- Hourly ATM, SRF, and RAD output through 2009-10-02 00:00 UTC
- Successful CLM restart-file output
- Final SAV, ATM, SRF, STS, and RAD output
- Empty stderr
- Slurm exit code `0:0`
- RegCM successful-end marker

## Edited RegCM Source Files

The following source and build-configuration files were edited to make the
rebuild link and run successfully.

### `configure.ac`

- Set the NVIDIA GPU architecture to `cc80` for Leonardo A100 GPUs.
- Added `-acc` to the OpenACC/stdpar compiler flags.
- Added `rdc` to the GPU flags for relocatable device code.
- Applied the same options to normal and no-optimization Fortran flags.

### `Main/microlib/mod_micro_wsm5.F90`

- Added an OpenACC device declaration for `pidn0r` and `pidn0s`.
- Added an initialization-time device update for those values.

### `Main/microlib/mod_micro_wsm7.F90`

- Added an OpenACC device declaration for `pidn0r`, `pidn0s`, `pidn0g`, and
  `pidn0h`.
- Added an initialization-time device update for those values.

### `Main/microlib/mod_micro_wdm7.F90`

- Added an OpenACC device declaration for `pidnc`, `pidnr`, `pidn0s`, `pidn0g`,
  and `pidn0h`.
- Added an initialization-time device update for those values.

### `Main/clmlib/clm4.5/mod_clm_urban.F90`

- Selected the existing serial fallback for the `UrbanFluxes` loop that caused
  CUDA error 719 when offloaded as a stdpar `do concurrent` loop.

## Edited Test Files

### `submit_8gpu_task.job`

- Sources the NVHPC/HPC-X environment loader.
- Exports `OPAL_PREFIX="$MPI_SHIM"` for the relocated OpenMPI installation.
- Selects the rebuilt `Main/regcm` executable.
- Uses direct `srun`, which provides the correct Slurm rank variables.
- Records toolchain, binary dependency, and GPU information in each job log.

### `STD_launch_per_rank.sh`

- Selects a local rank from Slurm, with an OpenMPI fallback.
- Sets `CUDA_VISIBLE_DEVICES` to the local rank.
- Sets `ACC_DEVICE_TYPE=nvidia` and `ACC_DEVICE_NUM=0` within the restricted GPU
  view.
- Verifies that the selected RegCM executable exists and is executable.
- Records global rank, local rank, host, and selected GPU before launching.

## Environment Loader

The shared loader used by this test is:

```text
/leonardo/home/userexternal/ctica000/MS_thesis/RegCM/environment_loaders/regcm5_leonardo_nvhpc_hpcx.sh
```

It selects NVHPC 25.11, CUDA 12.2, the NVHPC-built NetCDF stack, and the HPC-X
MPI shim. It activates the Spack environment without its broken generated view
exports and adds the unified view explicitly. Its runtime library path is kept
minimal because adding the sibling HPC-X UCX/UCC/HCOLL libraries previously
reintroduced the CLM coordinate abort.

The loader was not modified while applying the final launcher and
`mod_clm_urban.F90` fixes or while submitting the successful validation job.

## Remaining Nonfatal Warning

The successful run printed an HPC-X/UCX warning that OpenMPI required a newer
UCP API while `/lib64/libucp.so.0` supplied version 1.15. This did not prevent
the run from completing and did not produce stderr output. Changing the shared
loader to remove this warning is not recommended without a separate controlled
test, because using the sibling HPC-X component paths previously caused CLM
coordinate failures.

## Performance Context

The model elapsed time was 897.4796 seconds, or 14 minutes 57.5 seconds. The
full Slurm allocation lasted 16 minutes 34 seconds. This is about 87 times
faster than real time when job setup is included.

A previous successful reference run reported 869.4451 model seconds. The new
run was 28.03 seconds, or approximately 3.2 percent, slower. One run is not
enough to separate normal node-to-node variability from effects of the serial
urban-loop fallback or RDC. Repeated runs or a profile are required for a firm
performance attribution.

## Reproduction

From this test directory, submit with:

```bash
sbatch submit_8gpu_task.job
```

Check the final Slurm result with:

```bash
sacct -j JOB_ID --format=JobID,JobName,State,ExitCode,Elapsed,NodeList
```

A valid full run must have exit code `0:0`, empty stderr, the requested final
simulation time, and the `RegCM V5 simulation successfully reached end` marker.
