# Discoverer+ Production Run: EURR-3 1 Day, 8 GPUs, With IO

This directory is separate from the benchmark ablation/reference directories. It reuses the validated Discoverer+ loader and 8-rank GPU mapping from successful job `178785`.

## Paths

- Loader: `/valhalla/projects/ehpc-ben-2026b06-085/tchristian/work/RegCM/environment_loader/regcm5_discoverer_nvhpc25_1_hpcx_cuda12.sh`
- Executable: `/valhalla/projects/ehpc-ben-2026b06-085/tchristian/work/RegCM/bin/regcmMPICLM45`
- Input symlink: `input -> /valhalla/projects/ehpc-ben-2026b06-085/tchristian/scratch/EURR3/input`
- Output symlink: `output -> /valhalla/projects/ehpc-ben-2026b06-085/tchristian/scratch/EURR3/output_from_runs/production_1day_8gpus/output`
- RCMDATA: `/valhalla/projects/ehpc-ben-2026b06-085/tchristian/scratch/EURR3/RCMDATA`
- Logs: `production/LOG_%x_%j.{out,err}`

## Submit

```bash
sbatch submit_8gpu_task.job
```
