# Discoverer+ Production Runs: EURR-3 3 Days, With IO

This tree mirrors the 7-day production layout and is separate from all 1-day and 7-day production outputs.

Each GPU-count subdirectory has its own Slurm logs and a unique scratch output symlink.

## Shared Files

- Loader: `/valhalla/projects/ehpc-ben-2026b06-085/tchristian/work/RegCM/environment_loader/regcm5_discoverer_nvhpc25_1_hpcx_cuda12.sh`
- Executable: `/valhalla/projects/ehpc-ben-2026b06-085/tchristian/work/RegCM/bin/regcmMPICLM45`
- Namelist: `EURR-3_namelist.in`
- Launcher: `STD_launch_per_rank.sh`
- Common job body: `run_discoverer_common.sh`

## Run Directories

- `1gpu_1proc`: output to `scratch/EURR3/output_from_runs/production_3day_1gpu/output`
- `2gpu_2proc`: output to `scratch/EURR3/output_from_runs/production_3day_2gpu/output`
- `4gpu_4proc`: output to `scratch/EURR3/output_from_runs/production_3day_4gpu/output`
- `8gpu_8proc`: output to `scratch/EURR3/output_from_runs/production_3day_8gpu/output`
- `16gpu_16proc`: output to `scratch/EURR3/output_from_runs/production_3day_16gpu/output`
- `32gpu_32proc`: output to `scratch/EURR3/output_from_runs/production_3day_32gpu/output`

Submit from the desired subdirectory with:

```bash
sbatch submit.job
```
