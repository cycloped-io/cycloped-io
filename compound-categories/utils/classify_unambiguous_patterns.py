import numpy as np
import sys
import csv
from sklearn import svm
from sklearn.tree import DecisionTreeClassifier
from sklearn import tree
from sklearn.linear_model import SGDClassifier, LogisticRegression
from optparse import OptionParser

parser = OptionParser(description='Classify patterns as unambiguous.')
parser.add_option("-i", dest="input", help="CSV patterns with entropy.", metavar="CSV")
parser.add_option("-o", dest="output", help="CSV with patterns classified as unambiguous.", metavar="CSV")
parser.add_option("-r", dest="reference", help="CSV gold patterns.", metavar="CSV")

(options, args) = parser.parse_args()

if len(filter(lambda x: x is None, options.__dict__.values())):
    parser.print_help()
    sys.exit()

reference = {}
with open(options.reference) as f:
    reader = csv.reader(f)
    for row in reader:
        name, cyc_id, cyc_name = row
        reference[name] = cyc_name



X=[]
y=[]
with open(options.input) as f:
    reader = csv.reader(f)
    for row in reader:
        try:
            name, entropy, cyc_id, cyc_name, probability = row[:5]
        except:
            continue
        if name not in reference: continue
        if reference[name] == 'Thing':
            label=0
        else:
            label=1
        X.append([float(entropy), float(probability), (len(row)-2)/3])
        y.append(label)

#clf = DecisionTreeClassifier(max_depth=3)
#clf = SGDClassifier(loss="log")
#clf = svm.LinearSVC()

clf = LogisticRegression()
clf.fit(X, y)

print 'Accuracy:', clf.score(X,y)

with open(options.output,'w') as output:
    writer = csv.writer(output)
    with open(options.input) as input:
        reader = csv.reader(input)
        for row in reader:
            try:
                name, entropy, cyc_id, cyc_name, probability = row[:5]
            except:
                continue
            X=[float(entropy), float(probability), (len(row)-2)/3]
            predicted = clf.predict([X])

            if predicted[0]==1:
                writer.writerow(row)

p = clf.predict(X)