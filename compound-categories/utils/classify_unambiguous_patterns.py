import numpy as np
import sys
import csv
from sklearn import svm
from sklearn.tree import DecisionTreeClassifier
from sklearn import tree
from sklearn.linear_model import SGDClassifier, LogisticRegression
from optparse import OptionParser

parser = OptionParser(description='Classify patterns as unambiguous.')
parser.add_option("-i", dest="input", help="CSV with label, entropy, probability, count, name to fit. Result of export_patterns_for_classification.rb.", metavar="CSV")
parser.add_option("-o", dest="output", help="CSV with names classified as unambiguous.", metavar="CSV")
parser.add_option("-p", dest="patterns", help="CSV with label, entropy, probability, count, name to predict.", metavar="CSV")

(options, args) = parser.parse_args()

if len(filter(lambda x: x is None, options.__dict__.values())):
    parser.print_help()
    sys.exit()




def read_data(path):
    names = []
    X = []
    y = []
    with open(path) as f:
        reader = csv.reader(f)
        for row in reader:
            label, entropy, probability, count, name = row
            names.append(name)
            X.append((float(entropy), float(probability), int(count)))
            y.append(int(label))
    return names, X, y

names, X, y = read_data(options.input)

#clf = DecisionTreeClassifier(max_depth=3)
#clf = SGDClassifier(loss="log")
#clf = svm.LinearSVC()
clf = LogisticRegression()
clf.fit(X, y)
print 'Accuracy:', clf.score(X,y)



names2, X2, _ = read_data(options.patterns)

p = clf.predict(X2)


with open(options.output,'w') as f:
    writer = csv.writer(f)
    tp=0
    fp=0
    fn=0
    tn=0
    for i, name in enumerate(names2):
        if p[i]==1:
            writer.writerow([name])

    #     if p[i]!=y[i]:
    #         if p[i]==1:
    #             fp+=1
    #         else:
    #             fn+=1
    #     else:
    #         if p[i]==1:
    #             tp+=1
    #         else:
    #             tn+=1
    #
    #         # print name, p[i], y[i]
    #
    # print 'TP:', tp, 'FP:', fp, 'FN:', fn, 'TN:', tn
    # print 'Precision:', float(tp)/(tp+fp), 'Recall:', float(tp)/(tp+fn)



from sklearn.externals.six import StringIO
# with open("tree.dot", 'w') as f:
#     f = tree.export_graphviz(clf, out_file=f)