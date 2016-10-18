#!/bin/bash
#
#SBATCH --job-name=balign
#SBATCH --output=slurm-balign-%j.o
#SBATCH --cpus-per-task=2   
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

cd $WORKSPACE
echo "Aligning ($ALIGNER) - BEGIN: `date`" 
# e2f is used for PBSMT in translation direction src-tgt
# Philip's code produces i-j links mapping src-tgt
echo "Directional alignments"
mkdir -p e2f
cd e2f
java -jar -Xmx80G $BALIGN/BayesianAligner.jar ${BALIGNFLAGS["$ALIGNER"]} --aux $TRAININGDIR/$CORPUS/$SRC-$TGT/$TGT-$SRC-int-train.snt &> balign.log &
cd ..
# f2e is used for PBSMT with symmetrised alignments
# Philip's code produces i-j links mapping tgt-src
mkdir -p f2e
cd f2e
java -jar -Xmx80G $BALIGN/BayesianAligner.jar ${BALIGNFLAGS["$ALIGNER"]} --aux $TRAININGDIR/$CORPUS/$SRC-$TGT/$SRC-$TGT-int-train.snt &> balign.log &
cd ..
wait
cp -fs e2f/alignments aligned.tgttosrc
echo "Symmetrisation"
# symmetrisation: has to be done with Philip's code
# the output contains i-j links mapping src-tgt
python $BALIGN/mergeAlignments.py --filename aligned --grow-diag-final-and --format moses e2f/alignments f2e/alignments &> merger.out
echo "Aligning ($ALIGNER) - END: `date`" 


# ARCHIVE RESULTS

echo "syncing results..."
# sync back from node
rsync -vah $CHOWN $CHMOD $WORKSPACE/ $USERSPACE/experiments/$CORPUS/$ALIGNER/$SRC-$TGT/
# cleanup node
if [[ $CLEANUP == 1 ]]; then
    rm -fr $WORKSPACE
fi
