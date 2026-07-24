# Seven-day CLM45 DCGP production runs

These runs use the CPU-only `regcmMPICLM45` executable and the corrected
`/leonardo_work/ICT26_ESP/RCMDATA` forcing paths. They do not replace the
legacy `200proc`, `400proc`, or `800proc` directories.

## Timing basis

The one-day 800-rank job `49933820` completed successfully in 39 minutes 57
seconds. Multiplying by seven and assuming ideal strong scaling gives:

| MPI ranks | Nodes | Ideal seven-day estimate | Scheduler limit |
|----------:|------:|-------------------------:|----------------:|
| 800 | 8 | 04:39:39 | 06:00:00 |
| 400 | 4 | 09:19:18 | 12:00:00 |
| 200 | 2 | 18:38:36 | 24:00:00 |

The estimates assume elapsed time is inversely proportional to rank count.
Real scaling will be less than ideal. However, this seven-day namelist writes
ATM, RAD, and SRF streams every 24 hours rather than every hour as in the
one-day timing run, so the estimates are expected to be conservative.

The completed seven-day 800-rank run took 04:02:37. A subsequent 1600-rank
test uses 16 nodes and a 03:00:00 limit; ideal scaling from that measured
seven-day result predicts 02:01:19.

An intermediate 1200-rank test uses 12 nodes and a 04:00:00 limit. Ideal
scaling from the completed 800-rank result predicts approximately 02:41:45.

## Layout

Each rank directory has an unchanged seven-day namelist, a shared input
symlink, an independent scratch output directory, and a local production log
directory. Every submission script refuses to start if its output directory
is non-empty.

The production campaign has finished. See `CLM45_SCALING_REPORT.md` for the
complete setup, job accounting, scaling results, failures, and output-retention
status.
