#!/bin/bash
#
#SBATCH --job-name=giza
#SBATCH --output=slurm-giza-%j.o
#SBATCH --time=400          # at the time of Coling's submission aligning newsco took 200 minutes on average (with 2 cpus per direction)
#SBATCH --mem-per-cpu=4000
#SBATCH --cpus-per-task=4   # mgiza uses 2 cores per direction
set -e 
set -o pipefail

if [[ -z $1 ]]; then
    echo "Usage: $0 CONFIG"
    exit 1
fi

source $1

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

## ALIGNING: DO NOT TOUCH ANYTHING BETWEEN THIS LINE AND ARCHIVING!
module load moses/3.0
module load mgiza
cd $WORKSPACE
echo "Aligning ($ALIGNER) - BEGIN: `date`" 
# This aligns in both directions and symmetrises
$MOSES_HOME/scripts/training/train-model.perl -model-dir . -corpus $TRAININGDIR/$CORPUS/$SRC-$TGT/training -e $TGT -f $SRC --parallel -root-dir . -external-bin-dir $MGIZA -mgiza -mgiza-cpus 2 -alignment grow-diag-final-and -last-step 3 $GIZAFLAGS &> giza-gdfa.log
# This just compiles tgttosrc alignments from the files produced before
$MOSES_HOME/scripts/training/train-model.perl -model-dir . -corpus $TRAININGDIR/$CORPUS/$SRC-$TGT/training -e $TGT -f $SRC --parallel -root-dir . -external-bin-dir $MGIZA -mgiza -mgiza-cpus 2 -alignment tgttosrc -first-step 3 -last-step 3 $GIZAFLAGS &> giza-tgttosrc.log
echo "Aligning ($ALIGNER) - END: `date`" 


# ARCHIVE RESULTS

echo "syncing results..."
# sync back from node
rsync -vah $CHOWN $CHMOD $WORKSPACE/ $USERSPACE/experiments/$CORPUS/$ALIGNER/$SRC-$TGT/
# cleanup node
if [[ $CLEANUP == 1 ]]; then
    rm -fr $WORKSPACE
fi
