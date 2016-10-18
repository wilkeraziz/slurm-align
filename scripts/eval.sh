#!/bin/bash
#
#SBATCH --job-name=eval
#SBATCH --output=slurm-eval-%j.o
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

MERTDIR=$USERSPACE/experiments/$CORPUS/$ALIGNER/$SRC-$TGT/$MODELTYPE/mert-$SLURM_ARRAY_TASK_ID
if [[ ! -f $MERTDIR/moses.ini ]]; then
   echo "Missing moses.ini: $MERTDIR/moses.ini" 
   exit 1
fi

module load moses/3.0
module load mgiza
cd $WORKSPACE

echo "Evaluating $SLURM_ARRAY_TASK_ID ($ALIGNER - $MODELTYPE - $TESTSET) - BEGIN: `date`" 

mkdir -p $WORKSPACE/results

$MOSES_HOME/bin/moses $DECODERFLAGS -f $MERTDIR/moses.ini < $TESTDIR/$TESTSET.$SRC-$TGT.$SRC > $WORKSPACE/results/$TESTSET.$SRC-$TGT.translation 2> $WORKSPACE/results/translation.out 
$MOSES_HOME/scripts/generic/multi-bleu.perl -lc $TESTDIR/$TESTSET.$SRC-$TGT.$TGT < $WORKSPACE/results/$TESTSET.$SRC-$TGT.translation > $WORKSPACE/results/$TESTSET.$SRC-$TGT.bleu 

echo "Evaluating $SLURM_ARRAY_TASK_ID ($ALIGNER - $MODELTYPE - $TESTSET) - END: `date`" 

# ARCHIVE RESULTS

echo "syncing results..."
rsync -vah $CHOWN $CHMOD $WORKSPACE/results $MERTDIR/ 
# cleanup node
if [[ $CLEANUP == 1 ]]; then
    rm -fr $WORKSPACE
fi

