#!/bin/bash
#
#SBATCH --job-name=tuning
#SBATCH --output=slurm-tuning-%j.o
#SBATCH --cpus-per-task=5
set -e 
set -o pipefail

if [[ -z $2 ]]; then
    echo "Usage: $0 CONFIG MODELTYPE"
    exit 1
fi

source $1
MODELTYPE=$2

# need this workaround because not all LACOs map scratch to the same name
if [[ -d /scratch ]]; then
    SCRATCH=/scratch/`whoami`/$PROJECT
else
    SCRATCH=/datastore/`whoami`/$PROJECT
fi
mkdir -p $SCRATCH 

# create a unique directory for the experiment
WORKSPACE=`mktemp -d -p $SCRATCH $CORPUS.XXX`
echo "hostname=`hostname`"
echo "workspace=$WORKSPACE"

# sanity checks

MODELDIR=$USERSPACE/experiments/$CORPUS/$ALIGNER/$SRC-$TGT/$MODELTYPE
if [[ ! -d $MODELDIR ]]; then
   echo "Missing $MODELTYPE: $MODELDIR" 
   exit 1
fi

module load moses/3.0
module load mgiza

echo "Tuning $SLURM_ARRAY_TASK_ID ($ALIGNER - $MODELTYPE - $DEVSET) - BEGIN: `date`" 

MERTDIR="$WORKSPACE/mert-$SLURM_ARRAY_TASK_ID"
mkdir -p $MERTDIR
cd $MERTDIR
echo "MERT $SLURM_ARRAY_TASK_ID @ $MERTDIR"

$MOSES_HOME/scripts/training/mert-moses.pl $DEVDIR/$DEVSET.$SRC-$TGT.$SRC $DEVDIR/$DEVSET.$SRC-$TGT.$TGT $MOSES_HOME/bin/moses $MODELDIR/moses.ini --mertdir $MOSES_HOME/bin/ --working-dir $MERTDIR --decoder-flags " $DECODERFLAGS " &> $MERTDIR/mert-$SLURM_ARRAY_TASK_ID.out 

echo "Tuning $SLURM_ARRAY_TASK_ID ($ALIGNER - $MODELTYPE - $DEVSET) - END: `date`" 

# ARCHIVE RESULTS

echo "syncing results..."
rsync -vah $CHOWN $CHMOD $MERTDIR $USERSPACE/experiments/$CORPUS/$ALIGNER/$SRC-$TGT/$MODELTYPE/
# cleanup node
if [[ $CLEANUP == 1 ]]; then
    rm -fr $WORKSPACE
fi
