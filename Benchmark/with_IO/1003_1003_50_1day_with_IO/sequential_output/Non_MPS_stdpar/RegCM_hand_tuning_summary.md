# RegCM Non-MPS stdpar Performance and Hand-Tuning Summary

This note summarizes the RegCM 1-day benchmark runs under `Benchmark/with_IO/1003_1003_50_1day_with_IO/sequential_output/Non_MPS_stdpar`. The case uses sequential output with I/O enabled, the `1003 x 1003 x 50` domain, and one MPI rank per GPU on Leonardo Booster nodes.

## Main Findings

The best 8-GPU hand-tuned configuration was Level 3, with a best runtime of `1417.55 s` and an average of `1419.72 s` across two completed runs.

Compared with the current 8-GPU baseline using the bundled CUDA environment, Level 3 improved runtime from `1660.78 s` to `1417.55 s`, a `14.6%` reduction in elapsed time and a `1.17x` speedup.

The Level 2 tuning step was beneficial, reducing the 8-GPU runtime to about `1478.42 s` on average. Enabling UCX rendezvous tuning in Level 3 gave the best result. Enabling the NVHPC OpenACC memory pool in Level 4 made performance worse, increasing the average runtime to about `1537.60 s`.

The 16-GPU configuration remained the fastest overall, with a best runtime of `748.32 s`. Relative to the best 8-GPU hand-tuned runtime, this is a `1.89x` speedup, but it also uses twice as many GPUs.

## Performance Results

| Strategy | GPUs / MPI ranks | Nodes | Representative settings | Completed runs | Best total elapsed time (s) | Average total elapsed time (s) | Notes |
| --- | ---: | ---: | --- | ---: | ---: | ---: | --- |
| 4-GPU baseline, less frequent output | 4 / 4 | 1 | `CUDA_LAUNCH_BLOCKING=1`, simple rank-to-GPU mapping, `modules_cuda` | 2 | `3456.45` | `3462.41` | Slowest successful configuration. |
| 8-GPU baseline, older run | 8 / 8 | 2 | simple rank-to-GPU mapping | 1 | `5987.66` | `5987.66` | Much slower than later 8-GPU runs; kept as historical reference. |
| 8-GPU baseline, current environment | 8 / 8 | 2 | simple rank-to-GPU mapping, bundled CUDA or modules CUDA | 2 | `1660.78` | `1660.79` | Bundled CUDA and modules CUDA were effectively identical. |
| 8-GPU hand-tuned, Level 2 early | 8 / 8 | 2 | topology-aware CPU/GPU binding, no NIC pinning (`UCX_NET_DEVICES=auto`) | 1 | `1595.21` | `1595.21` | First binding experiment. |
| 8-GPU hand-tuned, Level 2 | 8 / 8 | 2 | CPU/NUMA binding, GPU-local NIC pinning, UCX PML, no UCX rendezvous tuning | 2 | `1476.34` | `1478.42` | Strong improvement over 8-GPU baseline. |
| 8-GPU hand-tuned, Level 3 | 8 / 8 | 2 | Level 2 plus UCX rendezvous tuning | 2 | `1417.55` | `1419.72` | Best 8-GPU result. |
| 8-GPU hand-tuned, Level 4 | 8 / 8 | 2 | Level 3 plus NVHPC OpenACC memory pool | 3 | `1526.94` | `1537.60` | Regressed versus Level 3. |
| 16-GPU baseline, less frequent output | 16 / 16 | 4 | `CUDA_LAUNCH_BLOCKING=1`, simple rank-to-GPU mapping, `modules_cuda` | 2 | `748.32` | `782.21` | Best absolute runtime. |

## Individual Run Times

| Folder | Log file | Total elapsed time (s) | Final timeslice time (s) | Status |
| --- | --- | ---: | ---: | --- |
| `Production_4gpu_4proc_less_freq` | `production/LOG_1d_4gpu_wIO_37987683.out` | `3456.45` | `3454.38` | Completed |
| `Production_4gpu_4proc_less_freq` | `production/LOG_1d_4gpu_wIO_39782594.out` | `3468.37` | `3466.35` | Completed |
| `Production_8gpu_8proc` | `production/LOG_1d_8gpu_wIO_42783522.out` | `5987.66` | `5976.15` | Completed, historical slow run |
| `Production_8gpu_8proc` | `production/LOG_1d_8gpu_wIO_bundledCUDA_44031882.out` | `1660.78` | `1658.97` | Completed |
| `Production_8gpu_8proc` | `production/LOG_1d_8gpu_wIO_modules_cuda_43940816.out` | `1660.80` | `1658.97` | Completed |
| `Production_8gpu_8proc_hand_tuned` | `production/debugging/LOG_1d_8gpu_level2_44060390.out` | `1595.21` | `1593.39` | Completed |
| `Production_8gpu_8proc_hand_tuned_level2` | `production/debugging/LOG_1d_8gpu_level2_ucx_nvhpc_25_11_45052495.out` | `1476.34` | `1474.60` | Completed |
| `Production_8gpu_8proc_hand_tuned_level2` | `production/debugging/LOG_1d_8gpu_level2_ucx_nvhpc_25_11_45746479.out` | `1480.49` | `1478.81` | Completed |
| `Production_8gpu_8proc_hand_tuned_level3` | `production/debugging/LOG_1d_8gpu_level3_ucx_nvhpc_25_11_45052785.out` | `1421.90` | `1420.25` | Completed |
| `Production_8gpu_8proc_hand_tuned_level3` | `production/debugging/LOG_1d_8gpu_level3_ucx_nvhpc_25_11_45746518.out` | `1417.55` | `1415.81` | Completed |
| `Production_8gpu_8proc_hand_tuned_level4` | `production/debugging/LOG_1d_8gpu_level4_ucx_nvhpc_25_11_44819781.out` | `1526.94` | `1525.31` | Completed |
| `Production_8gpu_8proc_hand_tuned_level4` | `production/debugging/LOG_1d_8gpu_level4_ucx_nvhpc_25_11_45053423.out` | `1553.73` | `1552.11` | Completed |
| `Production_8gpu_8proc_hand_tuned_level4` | `production/debugging/LOG_1d_8gpu_level4_ucx_nvhpc_25_11_45746530.out` | `1532.12` | `1530.56` | Completed |
| `Production_16gpu_16proc_less_freq` | `production/LOG_stdpar_16gpu_16task_34055996.out` | `816.10` | `814.56` | Completed |
| `Production_16gpu_16proc_less_freq` | `production/LOG_stdpar_16gpu_16task_39782403.out` | `748.32` | `746.84` | Completed |

## Hand-Tuning Strategy

| Level | Files | Tuning applied | Result |
| --- | --- | --- | --- |
| Baseline | `Production_8gpu_8proc/STD_launch_per_rank.sh`, `submit_8gpu_task.job` | One MPI rank per GPU using `CUDA_VISIBLE_DEVICES=$SLURM_LOCALID`, `ACC_DEVICE_TYPE=nvidia`, `ACC_DEVICE_NUM=0`; no CPU, NUMA, NIC, UCX, or memory-pool tuning. | Current reproducible runtime is about `1661 s`. |
| Early Level 2 | `Production_8gpu_8proc_hand_tuned/run_app_leonardo_L2` | Added topology-aware per-rank wrapper with explicit GPU assignment and CPU/NUMA binding; NIC pinning was optional and early successful run used `UCX_NET_DEVICES=auto`. | Runtime improved to `1595 s`. |
| Level 2 | `Production_8gpu_8proc_hand_tuned_level2/run_app_leonardo_L2`, `submit_8gpu_8task_leonardo_L3.job` | Added `--cpus-per-task=8`, `srun --cpu-bind=none`, `numactl --physcpubind`, `numactl --membind`, GPU-local `UCX_NET_DEVICES=mlx5_<local_gpu>:1`, `OMPI_MCA_pml=ucx`, `OMPI_MCA_osc=ucx`, and `OMPI_MCA_btl='^openib,smcuda'`. | Runtime improved to about `1478 s` average. |
| Level 3 | `Production_8gpu_8proc_hand_tuned_level3/run_app_leonardo_L2`, `submit_8gpu_8task_leonardo_L3.job` | Kept Level 2 settings and enabled UCX rendezvous tuning with `UCX_RNDV_THRESH=128`, `UCX_RNDV_FRAG_MEM_TYPE=cuda`, and `UCX_RNDV_FRAG_SIZE=cuda:32M`. | Best 8-GPU result, about `1420 s` average. |
| Level 4 | `Production_8gpu_8proc_hand_tuned_level4/run_app_leonardo_L2`, `submit_8gpu_8task_leonardo_L4.job` | Kept Level 3 settings and enabled NVHPC OpenACC memory-pool knobs: `NVCOMPILER_ACC_POOL_SIZE=48GB`, `NVCOMPILER_ACC_POOL_THRESHOLD=95`, and `NVCOMPILER_ACC_POOL_ALLOC_MAXSIZE=1500MB`. | Regressed to about `1538 s` average. |

## Scaling Observations

| Comparison | Runtime basis | Speedup | Runtime reduction |
| --- | --- | ---: | ---: |
| 8-GPU current baseline to 8-GPU Level 2 | `1660.78 s` to `1476.34 s` | `1.12x` | `11.1%` |
| 8-GPU current baseline to 8-GPU Level 3 | `1660.78 s` to `1417.55 s` | `1.17x` | `14.6%` |
| 8-GPU Level 3 to 8-GPU Level 4 | `1417.55 s` to `1526.94 s` | `0.93x` | `7.7%` slower |
| 4-GPU best to 8-GPU Level 3 best | `3456.45 s` to `1417.55 s` | `2.44x` | `59.0%` |
| 8-GPU Level 3 best to 16-GPU best | `1417.55 s` to `748.32 s` | `1.89x` | `47.2%` |

## Failed or Diagnostic Runs

Level 1 runs in `Production_8gpu_8proc_hand_tuned` with job IDs `45053062` and `45746447` did not complete. The error logs show `libaccdevaux118.so: undefined symbol: __acc_compiled` from the NVHPC runtime and `srun` exit code `127` across all ranks. These runs are excluded from performance comparisons.

The newer HPCX/NVHPC runs produced repeated Spack setup warnings like `export: {name}_LIB: not a valid identifier` and `Failed to initialize repository: '$SPACK_REPO_DIR_01'` in `.err` files. Despite those warnings, Level 2, Level 3, and Level 4 completed successfully and printed normal RegCM completion summaries.

## Conclusion

For 8 GPUs, the best tuning point is Level 3: CPU/NUMA binding, GPU-local NIC pinning, OpenMPI over UCX, and UCX rendezvous tuning. The NVHPC OpenACC memory-pool settings tested in Level 4 should not be kept for this case because they consistently slowed the run relative to Level 3.

For absolute time-to-solution, the 16-GPU setup is still fastest. For hand-tuned 8-GPU production runs, Level 3 is the recommended configuration from this benchmark set.
