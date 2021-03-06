#!/bin/bash

# Scores sentence pairs. Assumptions:
# - you have a model directory with a "score.sh" script that takes two arguments: the raw source and the raw target,
#   and which prints scores to STDOUT.
#
# Usage.
#
#     score.sh RAW_SOURCE_FILE RAW_TARGET_FILE MODEL_DIR OUT_PREFIX
#
# RAW_SOURCE_FILE and RAW_TARGET_FILE are of two types:
# (1) actual files that exist, in which case this script will score them entirely
# (2) the files don't exist but are prefixes, and the environment variable SGE_TASK_ID is set,
#     in which case the script will look for RAW_SOURCE_FILE.$SGE_TASK_ID, etc.
#
# Use case 2 enables parallelization via "qsub -t START:STOP".
#
# A good size for files is 100k lines, which takes about 20 minutes to score on a single GPU.

#$ -S /bin/bash -V
#$ -cwd
#$ -q gpu.q@@1080 -l gpu=1,h_rt=1:00:00,num_proc=1,mem_free=20G
#$ -j y

env | grep CUDA
env | grep SGE
hostname

source /opt/anaconda3/etc/profile.d/conda.sh
source deactivate
conda activate sockeye

nvidia-smi

set -eu

: ${SGE_TASK_ID=""}

src_prefix=$1
trg_prefix=$2
modeldir=$(abspath $3)
out_prefix=$4

srcfile=$(abspath $src_prefix)
trgfile=$(abspath $trg_prefix)
outfile=$(abspath $out_prefix)
if [[ ! -z $SGE_TASK_ID ]]; then
    num=$(printf %05d $SGE_TASK_ID)
    srcfile=$(abspath $src_prefix).$num
    trgfile=$(abspath $trg_prefix).$num
    outfile=$(abspath $out_prefix).$num
fi

outdir=$(dirname $outfile)
[[ ! -d $outdir ]] && mkdir -p $outdir

if [[ -s $outfile ]]; then
  echo "$outfile already exists and is nonempty, skipping."
  exit
fi

export SOCKEYE=/home/hltcoe/mpost/code/sockeye
export PYTHONPATH=$SOCKEYE

unset CUDA_VISIBLE_DEVICES
device=$SGE_HGR_gpu

$modeldir/score.sh $srcfile $trgfile --device-ids $device --disable-device-locking > $outfile
