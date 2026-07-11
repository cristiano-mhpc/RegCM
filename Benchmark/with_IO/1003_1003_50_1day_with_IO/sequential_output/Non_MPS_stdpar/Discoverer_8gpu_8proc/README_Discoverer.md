# Discoverer+ EURR-3 8 GPU Production Run

This folder adapts the Leonardo `Production_8gpu_8proc` benchmark for Discoverer+.

Relevant local Discoverer documentation checked:

- `pages_md/job_control.md`: `sbatch` submission and `squeue` monitoring.
- `pages_md/gpu-login-node-resource-limits.md`: login node is for submission, monitoring, and file management only; substantial work should run under Slurm.
- `pages_md/gromacs.md`: Discoverer+ GPU nodes are DGX H200 systems and GPU jobs should request GPU resources explicitly.

## Files

- `submit_8gpu_task.job`: production run job for 1 node, 8 MPI ranks, 8 GPUs.
- `STD_launch_per_rank.sh`: maps each local MPI rank to one GPU using `CUDA_VISIBLE_DEVICES=$SLURM_LOCALID`.
- `EURR-3_namelist.in`: Leonardo namelist with Discoverer-local input/output paths and absolute `RCMDATA` paths.
- `download_eurr3_data.sbatch`: Slurm wrapper for downloading input data.
- `download_eurr3_data.sh`: recursive download script for `input` and `RCMDATA`.
- `input/`: symlink to `/valhalla/projects/ehpc-ben-2026b06-085/tchristian/scratch/EURR3/input`.
- `/valhalla/projects/ehpc-ben-2026b06-085/tchristian/scratch/EURR3/RCMDATA`: expected RegCM data files.
- `output/`: symlink to `/valhalla/projects/ehpc-ben-2026b06-085/tchristian/scratch/EURR3/output`.
- `production/`: Slurm logs.

## Data Sources

- `input`: `http://clima-dods.ictp.it/Users/ggiulian/transfer/EURR3/input/`
- `RCMDATA`: `http://clima-dods.ictp.it/Users/ggiulian/transfer/EURR3/RCMDATA/`

## Usage

Download data first:

```bash
sbatch download_eurr3_data.sbatch
```

After the RegCM Discoverer+ build has installed `bin/regcmMPICLM45` and the data download is complete, submit the production run:

```bash
sbatch submit_8gpu_task.job
```
