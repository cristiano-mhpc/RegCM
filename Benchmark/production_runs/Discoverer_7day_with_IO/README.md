# Discoverer+ Production Runs: EURR-3 7 Days, With IO

This tree mirrors the current 3-day production layout and is separate from all 1-day and 3-day production outputs.

Each GPU-count subdirectory has its own Slurm logs and a unique scratch output symlink, so outputs do not coincide with any other production run.

## Shared Files

- Loader: `/valhalla/projects/ehpc-ben-2026b06-085/tchristian/work/RegCM/environment_loader/regcm5_discoverer_nvhpc25_1_hpcx_cuda12.sh`
- Executable: `/valhalla/projects/ehpc-ben-2026b06-085/tchristian/work/RegCM/bin/regcmMPICLM45`
- Namelist: `EURR-3_namelist.in`
- Launcher: `STD_launch_per_rank.sh`
- Common job body: `run_discoverer_common.sh`

## Run Directories

- `1gpu_1proc`: output to `scratch/EURR3/output_from_runs/production_7day_1gpu/output`
- `2gpu_2proc`: output to `scratch/EURR3/output_from_runs/production_7day_2gpu/output`
- `4gpu_4proc`: output to `scratch/EURR3/output_from_runs/production_7day_4gpu/output`
- `8gpu_8proc`: output to `scratch/EURR3/output_from_runs/production_7day_8gpu/output`
- `12gpu_12proc`: output to `scratch/EURR3/output_from_runs/production_7day_12gpu/output`
- `14gpu_14proc`: output to `scratch/EURR3/output_from_runs/production_7day_14gpu/output`

The `16gpu` and `32gpu` cases are intentionally omitted: 16 normal GPUs cannot currently be requested because `dgx2` exposes only 7 normal `gpu` GRES plus one separate `gpu_biz`, and 32 GPUs exceeds the two-node Discoverer+ allocation.

Submit from the desired subdirectory with:

```bash
sbatch submit.job
```
