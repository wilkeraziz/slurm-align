if [[ -z $1 ]]; then
    echo "Usage: $0 CONFIG"
    exit
fi

CONFIGFILE=`readlink -f $1`
source $CONFIGFILE

# Determine where the pipeline scripts lives in order to determine the location of its sub-scripts
MYPATH=`readlink -f $0`
MYDIR=`dirname $MYPATH`
MYSCRIPTS=$MYDIR/scripts

echo "CONFIG=$CONFIGFILE"
echo "CORPUS=$CORPUS"
echo "PAIR=$SRC-$TGT"
echo "ALIGNER=$ALIGNER"

jalign=
jbuild=
jtunedir=
jtunesym=
jevaldir=
jevalsym=

waitalign=
waitbuild=
waittunedir=
waittunesym=

mkdir -p $USERSPACE/experiments/$CORPUS/$ALIGNER/$SRC-$TGT

if [[ $DO_ALIGN == 1 ]]; then
    # Determine which aligner script to run and what resources to allocate
    if [[ "$ALIGNER" == "fastalign" ]]; then
        ALIGNMENTSCRIPT="fastalign.sh"
    elif [[ "$ALIGNER" == "giza" ]]; then
        ALIGNMENTSCRIPT="giza.sh"
    elif [[ ! -z `echo "$ALIGNER" | egrep '^balign-'` ]]; then
        ALIGNMENTSCRIPT="balign.sh"
    else
        echo "I do not recognise this aligner: $ALIGNER"
        exit 1
    fi

    ALIGN_JOB_NAME="$ALIGNER-$CORPUS-$SRC-$TGT"
    jalign=`sbatch $SBATCH_GENERAL ${SBATCH_ALIGN["$ALIGNER"]} --job-name=$ALIGN_JOB_NAME $MYSCRIPTS/$ALIGNMENTSCRIPT $CONFIGFILE  | egrep -o "[0-9]+$"`
    waitalign="afterok:$jalign"
    echo "$ALIGNER: $jalign"
fi

if [[ $DO_BUILD == 1 ]]; then
    BUILD_JOB_NAME="build-$CORPUS-$SRC-$TGT-$ALIGNER"
    jbuild=`sbatch $SBATCH_GENERAL $SBATCH_BUILD --job-name=$BUILD_JOB_NAME --dependency=$waitalign $MYSCRIPTS/build-model.sh $CONFIGFILE  | egrep -o "[0-9]+$"`
    waitbuild="afterok:$jbuild"
    echo "building: $jbuild ($waitalign)"
fi

if [[ $DO_TUNE == 1 ]]; then
    # dirmodel
    if [[ $DO_DIRMODEL == 1 ]]; then
        TUNING_JOB_NAME_DIR="tuning-$CORPUS-$SRC-$TGT-$ALIGNER-DIR"
        jtunedir=`sbatch $SBATCH_GENERAL $SBATCH_TUNING --job-name=$TUNING_JOB_NAME_DIR --dependency=$waitbuild $MYSCRIPTS/tuning.sh $CONFIGFILE dirmodel  | egrep -o "[0-9]+$"`
        waittunedir="afterok:$jtunedir"
        echo "tuning dirmodel: $jtunedir ($waitbuild)"
    fi
    # symmodel
    if [[ $DO_SYMMODEL == 1 ]]; then
        TUNING_JOB_NAME_SYM="tuning-$CORPUS-$SRC-$TGT-$ALIGNER-SYM"
        jtunesym=`sbatch $SBATCH_GENERAL $SBATCH_TUNING --job-name=$TUNING_JOB_NAME_SYM --dependency=$waitbuild $MYSCRIPTS/tuning.sh $CONFIGFILE symmodel  | egrep -o "[0-9]+$"`
        waittunesym="afterok:$jtunesym"
        echo "tuning symmodel: $jtunesym ($waitbuild)"
    fi
fi

if [[ $DO_EVAL == 1 ]]; then
    
    if [[ $DO_DIRMODEL == 1 ]]; then
        EVAL_JOB_NAME_DIR="eval-$CORPUS-$SRC-$TGT-$ALIGNER-DIR"
        jevaldir=`sbatch $SBATCH_GENERAL $SBATCH_EVAL --job-name=$EVAL_JOB_NAME_DIR --dependency=$waittunedir $MYSCRIPTS/eval.sh $CONFIGFILE dirmodel  | egrep -o "[0-9]+$"`
        echo "eval dirmodel: $jevaldir ($waittunedir)"
        # notify results
        sbatch --dependency=afterok:$jevaldir $MYSCRIPTS/notify.sh $CONFIGFILE dirmodel
    fi

    if [[ $DO_SYMMODEL == 1 ]]; then
        EVAL_JOB_NAME_SYM="eval-$CORPUS-$SRC-$TGT-$ALIGNER-SYM"
        jevalsym=`sbatch $SBATCH_GENERAL $SBATCH_EVAL --job-name=$EVAL_JOB_NAME_SYM --dependency=$waittunesym $MYSCRIPTS/eval.sh $CONFIGFILE symmodel  | egrep -o "[0-9]+$"`
        echo "eval symmodel: $jevalsym ($waittunesym)"
        # notify results
        sbatch --dependency=afterok:$jevalsym $MYSCRIPTS/notify.sh $CONFIGFILE symmodel
    fi
    
fi
    
