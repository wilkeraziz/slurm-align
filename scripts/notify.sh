#!/bin/bash
#
#SBATCH --job-name=notify
#SBATCH --output=slurm-notify-%j.o
#SBATCH --time=5
#SBATCH --mem-per-cpu=10
#SBATCH --cpus-per-task=1

if [[ -z $2 ]]; then
    echo "USage: $0 CONFIG MODELTYPE"
    exit
fi

source $1
MODELTYPE=$2

cat $USERSPACE/experiments/$CORPUS/$ALIGNER/$SRC-$TGT/$MODELTYPE/mert-*/results/*.bleu  | mail -s "results: $CORPUS $SRC $TGT $ALIGNER $MODELTYPE" "$EMAIL"
