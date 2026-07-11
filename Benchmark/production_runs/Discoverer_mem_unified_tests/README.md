# Discoverer+ mem:unified tests

Isolated production-style tests for a RegCM build compiled with NVHPC `-gpu=cc90,lineinfo,mem:unified`.

- Build copy: `/valhalla/projects/ehpc-ben-2026b06-085/tchristian/work/RegCM_mem_unified_build`
- Executable: `/valhalla/projects/ehpc-ben-2026b06-085/tchristian/work/RegCM/bin/mem_unified/regcmMPICLM45`
- Existing `mem:managed` executable is left unchanged at `/valhalla/projects/ehpc-ben-2026b06-085/tchristian/work/RegCM/bin/regcmMPICLM45`
- Environment loader: `/valhalla/projects/ehpc-ben-2026b06-085/tchristian/work/RegCM/environment_loader/regcm5_discoverer_nvhpc25_1_hpcx_cuda12.sh`

Prepared tests:

- `1day_with_IO/8gpu_8proc`: completed first 8-GPU compatibility test shape. Shares `1day_with_IO/EURR-3_namelist.in`.
- `3day_with_IO/{1gpu_1proc,2gpu_2proc}`: 3-day comparator tests. These share `3day_with_IO/EURR-3_namelist.in`.
- `7day_with_IO/{2gpu_2proc,4gpu_4proc,8gpu_8proc,12gpu_12proc,14gpu_14proc}`: production-style 7-day stability/performance tests for the `mem:unified` executable. These share `7day_with_IO/EURR-3_namelist.in`.

Unique output targets:

- `1day_with_IO/8gpu_8proc/output -> /valhalla/projects/ehpc-ben-2026b06-085/tchristian/scratch/EURR3/output_from_runs/mem_unified_1day_8gpu/output`
- `3day_with_IO/1gpu_1proc/output -> /valhalla/projects/ehpc-ben-2026b06-085/tchristian/scratch/EURR3/output_from_runs/mem_unified_3day_1gpu/output`
- `3day_with_IO/2gpu_2proc/output -> /valhalla/projects/ehpc-ben-2026b06-085/tchristian/scratch/EURR3/output_from_runs/mem_unified_3day_2gpu/output`
- `7day_with_IO/2gpu_2proc/output -> /valhalla/projects/ehpc-ben-2026b06-085/tchristian/scratch/EURR3/output_from_runs/mem_unified_7day_2gpu/output`
- `7day_with_IO/4gpu_4proc/output -> /valhalla/projects/ehpc-ben-2026b06-085/tchristian/scratch/EURR3/output_from_runs/mem_unified_7day_4gpu/output`
- `7day_with_IO/8gpu_8proc/output -> /valhalla/projects/ehpc-ben-2026b06-085/tchristian/scratch/EURR3/output_from_runs/mem_unified_7day_8gpu/output`
- `7day_with_IO/12gpu_12proc/output -> /valhalla/projects/ehpc-ben-2026b06-085/tchristian/scratch/EURR3/output_from_runs/mem_unified_7day_12gpu/output`
- `7day_with_IO/14gpu_14proc/output -> /valhalla/projects/ehpc-ben-2026b06-085/tchristian/scratch/EURR3/output_from_runs/mem_unified_7day_14gpu/output`

Submit manually after review:

```bash
cd /valhalla/projects/ehpc-ben-2026b06-085/tchristian/work/RegCM/Benchmark/production_runs/Discoverer_mem_unified_tests/1day_with_IO/8gpu_8proc
sbatch submit.job
cd ../../3day_with_IO/1gpu_1proc
sbatch submit.job
cd ../2gpu_2proc
sbatch submit.job
cd ../../7day_with_IO/2gpu_2proc
sbatch submit.job
cd ../4gpu_4proc
sbatch submit.job
cd ../8gpu_8proc
sbatch submit.job
cd ../12gpu_12proc
sbatch submit.job
cd ../14gpu_14proc
sbatch submit.job
```
