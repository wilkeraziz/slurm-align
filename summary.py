"""
This script can be used to compile results.

For example,
    
    ls /workspace/wferrei1/aligncmp/experiments/newsco/*/*/*model/mert-*/results/*.bleu | python summary.py > out 2> err

will produce 
    1. (out) a big table with mean and deviations
    2. (err) a big table with all data points as a file that can be loaded with numpy 
    3. *.dat files: which are organised as to produce the plots in the Coling16 paper


"""

import sys
import re
import numpy as np
from collections import defaultdict

MERTRUN = -3
MODELTYPE = -4
PAIR = -5
ALIGNER = -6
TRAININGSET = -7
TESTSET = -1

BLEU_RE = re.compile(r'BLEU = ([^,]+),')


def read_bleu(path):
    """
    Reads the output of mteval and returns a BLEU score (100 points scale).
    The output of mteval looks like the following (in which case we return 20.12):
            BLEU = 20.12, 58.3/27.6/15.1/8.6 (BP=0.941, ratio=0.943, hyp_len=63767, ref_len=67624)
    This function returns None in case of missing score/file or bad format.
    """
    bleu = None
    try:
        with open(path) as fi:
            for line in fi:
                result = BLEU_RE.search(line)
                if not result:
                    continue
                bleu = float(result.group(1))
    except:
        pass
    return bleu


class ContrastModelType:

    def __init__(self):
        self._data = defaultdict(lambda: defaultdict(list))

    def add_observation(self, trainingset, testset, pair, aligner, modeltype, mertrun, bleu):
        self._data[(trainingset, testset, pair, aligner)][modeltype].append(bleu)

    def do(self, ostream=None):
        for (trainingset, testset, pair, aligner), resultsByType in self._data.items():
            with open('%s-%s-%s-%s.dat' % (trainingset, testset, pair, aligner), 'w') as fo:
                print('model avg std n', file=fo)
                for modeltype, results in sorted(resultsByType.items(), key=lambda t: t[0]):
                    avg = np.mean(results)
                    std = np.std(results)
                    n = len(results)
                    print(modeltype, '%.2f' % avg, '%.2f' % std, n, file=fo)

class MeanStd:

    def __init__(self):
        self._data = defaultdict(list)

    def add_observation(self, trainingset, testset, pair, aligner, modeltype, mertrun, bleu):
        self._data[(trainingset, testset, pair, aligner, modeltype)].append(bleu)

    def do(self, ostream):
        print('trainingset testset pair aligner modeltype avg std n', file=ostream)
        for (trainingset, testset, pair, aligner, modeltype), results in sorted(self._data.items(), key=lambda t: t[0]):
            avg = np.mean(results)
            std = np.std(results)
            n = len(results)
            print(' '.join(str(v) for v in [trainingset, testset, pair, aligner, modeltype]), avg, std, n, file=ostream)
    

def main(istream):
    summariser = ContrastModelType()
    meanstd = MeanStd()

    print(' '.join(['trainingset', 'testset', 'pair', 'aligner', 'modeltype', 'mertrun', 'BLEU', 'path']), file=sys.stderr)
    for line in istream:
        path = line.strip()
        # e.g. /workspace/wferrei1/aligncmp/experiments/newsco/balign-ibm2/de-en/dirmodel/mert-1/results/newstest2014.de-en.bleu 
        parts = path.split('/')
        mertrun = parts[MERTRUN]
        modeltype = parts[MODELTYPE]
        pair = parts[PAIR]
        src, tgt = pair.split('-')
        aligner = parts[ALIGNER]
        trainingset = parts[TRAININGSET]
        testset = parts[TESTSET].split('.')[0]
        bleu = read_bleu(path)
        if bleu is None:
            print('Problem with %s' % path, file=sys.stderr)
            continue
        for summary in [summariser, meanstd]:
            summary.add_observation(trainingset, testset, pair, aligner, modeltype, mertrun, bleu)

        print(' '.join(str(v) for v in [trainingset, testset, pair, aligner, modeltype, mertrun, bleu, path]), file=sys.stderr)

    summariser.do()
    meanstd.do(sys.stdout)



if __name__ == '__main__':
    main(sys.stdin)
