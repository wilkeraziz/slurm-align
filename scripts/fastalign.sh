#!/bin/bash
#
#SBATCH --job-name=fastalign
#SBATCH --output=slurm-fastalign-%j.o
#SBATCH --time=30           # at the time of Coling's submission aligning newsco took less than 10 minutes
#SBATCH --mem-per-cpu=2000
#SBATCH --cpus-per-task=2   # all alignment steps require 2 cores
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
cd $WORKSPACE
echo "Aligning ($ALIGNER) - BEGIN: `date`" 
echo "Directional alignments"
# the documentation for -r reads: condition on target and predict source
# f2e or srctotgt: p(tgt|src) is used for PBSMT with symmetrised alignments
# Dyer's code produces i-j links mapping src-tgt
$FASTALIGN/fast_align $FASTALIGNFLAGS -i $TRAININGDIR/$CORPUS/$SRC-$TGT/training > aligned.srctotgt 2> fastalign-srctotgt.log &
# e2f or tgttosrc: p(src|tgt) is used for PBSMT with directional alignments only 
# Dyer's code produces i-j links mapping src-tgt
$FASTALIGN/fast_align $FASTALIGNFLAGS -i $TRAININGDIR/$CORPUS/$SRC-$TGT/training -r > aligned.tgttosrc 2> fastalign-tgttosrc.log &
wait
echo "Symmetrisation"
# symmetrisation: I am symmetrising with Dyer's code for consistency with fast_align output format
# here -i takes the p(tgt|src) distribution and -j takes the p(src|tgt) distribution, that is, -i takes the normal file and -j takes the file generated with option -r
# the output contains i-j links mapping src-tgt
$FASTALIGN/atools -c grow-diag-final-and -i aligned.srctotgt -j aligned.tgttosrc > aligned.grow-diag-final-and 2> atools.log
echo "Aligning ($ALIGNER) - END: `date`" 


# ARCHIVE RESULTS

echo "syncing results..."
# sync back from node
rsync -vah $CHOWN $CHMOD $WORKSPACE/ $USERSPACE/experiments/$CORPUS/$ALIGNER/$SRC-$TGT/
# cleanup node
if [[ $CLEANUP == 1 ]]; then
    rm -fr $WORKSPACE
fi
