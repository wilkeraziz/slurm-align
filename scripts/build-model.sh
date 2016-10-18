#!/bin/bash
#
#SBATCH --job-name=build-model
#SBATCH --output=slurm-build-model-%j.o
#SBATCH --cpus-per-task=4
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

# sanity checks

if [[ ! -f $USERSPACE/experiments/$CORPUS/$ALIGNER/$SRC-$TGT/aligned.grow-diag-final-and ]]; then
   echo "Missing gdfa file: $USERSPACE/experiments/$CORPUS/$ALIGNER/$SRC-$TGT/aligned.grow-diag-final-and" 
   exit 1
fi

if [[ ! -f $USERSPACE/experiments/$CORPUS/$ALIGNER/$SRC-$TGT/aligned.tgttosrc ]]; then
    echo "Missing tgttosrc file: $USERSPACE/experiments/$CORPUS/$ALIGNER/$SRC-$TGT/aligned.tgttosrc"
    exit 1
fi

## DO NOT TOUCH ANYTHING BETWEEN THIS LINE AND ARCHIVING!
module load moses/3.0
module load mgiza
cd $WORKSPACE
# rsync requirements
rsync -vaLhp $USERSPACE/experiments/$CORPUS/$ALIGNER/$SRC-$TGT/aligned.grow-diag-final-and .
rsync -vaLhp $USERSPACE/experiments/$CORPUS/$ALIGNER/$SRC-$TGT/aligned.tgttosrc .
echo "Building model ($ALIGNER) - BEGIN: `date`" 
echo "Directional model"
mkdir -p dirmodel
cd dirmodel
cp -fs ../aligned.tgttosrc .
cd ..
$MOSES_HOME/scripts/training/train-model.perl -model-dir `pwd`/dirmodel -corpus $TRAININGDIR/$CORPUS/$SRC-$TGT/training -e $TGT -f $SRC --parallel -root-dir . -external-bin-dir $MGIZA -mgiza -mgiza-cpus 2 -alignment tgttosrc -reordering msd-bidirectional-fe -lm 0:5:$LMDIR/news.all.$TGT.binary -first-step 4 &> dirmodel/errors.txt &

echo "Symmetrised model"
mkdir -p symmodel
cd symmodel
cp -fs ../aligned.grow-diag-final-and .
cd ..
$MOSES_HOME/scripts/training/train-model.perl -model-dir `pwd`/symmodel -corpus $TRAININGDIR/$CORPUS/$SRC-$TGT/training -e $TGT -f $SRC --parallel -root-dir . -external-bin-dir $MGIZA -mgiza -mgiza-cpus 2 -alignment grow-diag-final-and -reordering msd-bidirectional-fe -lm 0:5:$LMDIR/news.all.$TGT.binary -first-step 4 &> symmodel/errors.txt &

wait

sed -i 's/SRILM/KENLM/;' dirmodel/moses.ini
sed -i 's/SRILM/KENLM/;' symmodel/moses.ini

echo "Building model ($ALIGNER) - END: `date`" 


# ARCHIVE RESULTS

echo "syncing results..."
remotedir=$WORKSPACE/dirmodel
remotesym=$WORKSPACE/symmodel
localdir=$USERSPACE/experiments/$CORPUS/$ALIGNER/$SRC-$TGT/dirmodel
localsym=$USERSPACE/experiments/$CORPUS/$ALIGNER/$SRC-$TGT/symmodel
rsync -vah $CHOWN $CHMOD $WORKSPACE/dirmodel $USERSPACE/experiments/$CORPUS/$ALIGNER/$SRC-$TGT/
rsync -vah $CHOWN $CHMOD $WORKSPACE/symmodel $USERSPACE/experiments/$CORPUS/$ALIGNER/$SRC-$TGT/
sed -i "s%$remotedir%$localdir%g" $localdir/moses.ini
sed -i "s%$remotesym%$localsym%g" $localsym/moses.ini
# cleanup node
if [[ $CLEANUP == 1 ]]; then
    rm -fr $WORKSPACE
fi
