# Requirements


Under `$ARCHIVE` (which you can configure in your .ini file) you need to have

* data/{training,test,dev}: see the example
* lm
* tools: which should include `fast_align`, `mgiza` and `BayesianAligner`

This is my own directory:

    $ ls data/
    README.md dev       test      training

    $ ls lm/
    news.all.cs.binary news.all.de.binary news.all.en.binary news.all.fr.binary news.all.ru.binary

    $ ls tools/
    BayesianAligner.jar fast_align/             mergeAlignments.py     mgiza/


# How to use

Create a local copy of `config.ini` and change the variables that are relevant to your experiment.

In section (1)

* ALIGNER: one of mgiza, fastalign, balign-VARIANT
* SRC: source language (translation direction)
* TGT: target language (translation direction)
* CORPUS: folder under `$ARCHIVE/data/training` containing the training data
* DEVSET: stem under `$ARCHIVE/data/dev`
* TESTSET: stem under `$ARCHIVE/data/test`
* PROJECT: name of output folder 
* USERSPACE: by default points to `/workspace/YOU/PROJECT`
* EMAIL: who gets notified by SLURM

In section (2), control what gets executed

* DO\_ALIGN: align the training data in both directions
* DO\_BUILD: build a phrase table and a lexicalised reordering table
* DO\_TUNE: MERT tuning using devset
* DO\_EVAL: decode and run BLEU

Tuning and evaluation happens at least twice, once for directional alignments (condition on target and generate source) and once for symmetrised alignments (grow-diag-final-and).
You can control whether these variants get trained/evaluated using DO\_DIRMODEL and DO\_SYMMODEL, respectively.
To account for stability of the optimiser (MERT) you can run tuning/evaluation multiple times (see `--array` in SBATCH\_TUNE and SBATCH\_EVAL).

In section (3), control resource allocation for different steps.

In section (4), configure where frozen data, tools and pretrained models can be found.

In section (5), configure tools that will be used, e.g., Moses, mgiza, fastalign, balign.

Finally, run `pipeline.sh CONFIG > JOBIDS`.


# Compiling a table with results

Check the script `summary.py`


# Adding a new Bayesian aligner

Suppose you have NEW-VARIANT of Bayesian alignment model, then

1. Allocate resources for at least 2 tasks (source-to-target and target-to-source alignments)

    SBATCH_ALIGN["balign-NEW-VARIANT"]="--time 400 --mem-per-cpu=40000 --cpus-per-task=2"

2. Configure Bayesian Aligner

    BALIGNFLAGS["balign-NEW-VARIANT"]="--FLAGS --FLAGS --FLAGS"

3. Make sure `$ARCHIVE/tools/BayesianAligner.jar` points to the version which implements your new options


# TO DO

1. Amir: fix permissions of mgiza
