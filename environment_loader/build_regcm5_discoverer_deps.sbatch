#!/bin/bash
#SBATCH --partition=common
#SBATCH --job-name=build-regcm-deps
#SBATCH --time=02:00:00
#SBATCH --account=ehpc-ben-2026b06-085
#SBATCH --qos=ehpc-ben-2026b06-085
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=32G
#SBATCH --gres=gpu:1
#SBATCH --output=/valhalla/projects/ehpc-ben-2026b06-085/tchristian/logs/%x-%j.out
#SBATCH --error=/valhalla/projects/ehpc-ben-2026b06-085/tchristian/logs/%x-%j.err

set -euo pipefail

cd /valhalla/projects/ehpc-ben-2026b06-085/tchristian/work/RegCM

# Discoverer docs say compilation should run on compute nodes. This wrapper is
# intentionally small and requests the minimum GPU GRES required by this QOS,
# although this dependency stack does not perform GPU execution.
module purge
module load cmake/3/3.31.4

export MAKE_JOBS="${SLURM_CPUS_PER_TASK:-8}"
export REGCM_OFFLINE_BUILD=1

./environment_loader/build_regcm5_discoverer_deps.sh
