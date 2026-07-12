# Discoverer+ Node Introspection

This directory contains Discoverer+ compute-node topology and `mem:unified` probe artifacts.

## Completed Runs

- `179466`: completed on `dgx1` with an 8-GPU request. Generated the root-level introspection files and showed `MEM_UNIFIED_RUNTIME_PROBE=PASS` for the initial OpenACC-based `mem:unified` probe.

## Pending Strict-Probe Runs

- `179509`: submitted for `dgx1` with an 8 normal-GPU request.
- `179510`: submitted for `dgx2` with a 7 normal-GPU request, because an 8 normal-GPU request on `dgx2` was rejected by Slurm.

New probe runs write job-specific outputs under:

```text
introspection/${SLURM_JOB_ID}_${SLURM_JOB_NAME}/
```

## Probe Notes

The initial `179466` OpenACC probe compiled and ran with `-gpu=cc90,lineinfo,mem:unified`, but the compiler reported an implicit copy for the test array. The updated script also includes a stricter CUDA pageable host-memory probe to better exercise HMM-style access without OpenACC data-management inference.
