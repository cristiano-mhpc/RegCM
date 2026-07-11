# Discoverer+ RegCM Runtime Ablation

This directory isolates runtime-environment tests from production runs.

The successful production reference is:

`../Discoverer_8gpu_8proc/production/LOG_1d_8gpu_wIO_discoverer_178785.out`

That run completed in about 534 seconds with:

- MPI shim enabled
- `OMPI_MCA_coll=^ucc`
- CUDA stubs in `LIBRARY_PATH`, not `LD_LIBRARY_PATH`

## Cases

- `case00_working_shim_ucc_off_stubs_always`: known-good reference.
- `case01_no_shim_ucc_off_stubs_always`: tests the effect of the MPI shim alone.
- `case02_shim_ucc_on_stubs_always`: tests the effect of UCC alone while keeping the shim.
- `case03_site_hpcx_original_runtime_stubs_auto`: approximates the original runtime.

Each case has its own output directory under:

`/valhalla/projects/ehpc-ben-2026b06-085/tchristian/scratch/EURR3/output_from_runs/ablation/<case>/output`

## Submit One Case

From inside a case directory:

```bash
sbatch submit_ablation_case.job
```

Run one case at a time and compare total elapsed seconds plus whether the run reaches:

`RegCM V5 simulation successfully reached end`
