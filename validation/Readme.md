# Classification results validation

## Data

Each validation data set has its own subdirectory, indicateding the date when
the tests were performed. Each subdirectory should be self-contained, especially
with respect to the reference data.

The subdirectories follow the following structure

data/date/validation_dataset/

e.g.

data/05_2014/wole

contains test performed in May of 2014 for ISWC conference paper using WoLE
dataset.

The file in the directory should contain one `reference.csv` file, which
contains the manual reference classification and a bunch of files for each
method that was tested. The individual files contain abbreviations of the
method/s that were used to created given result. The common abbreviations are:

* `ls` - local support applied to Wikipedia categories
* `gs` - global support applied to Wikipedia categories
* `gh` - global heuristics applied to Wikipedia categories
* `db` - DBpedia classification
* `cp` - compound categories
* `fs` - definition types

Moreover a plus sign indicates that results from two methods were combined and  
`_res` suffix idnicates that the conflict resolution algorithm was run for the
combined classifications, while `trace_` prefix indicates individual decision of
a given method useful for computing statistical significance of the results.

We do not describe individual files, since their contents should reflect their
names.

## Scripts

### Precision & recall

Compute precision, recall and F1 for different evaluation scenarios:

```bash
validation$ utils/precision_and_recall.rb
```

### Statistical significance

Check statistical significance of the results using paired Student t-test.

```bash
validation$ utils/paired_t_test.rb
```

### Convert reference classification

Convert reference classification using different taxonomy to Cyc terms.

```bash
validation$ utils/convert_generic_classification.rb
```

### Filter classification

Filter classification to only include entries that are present in the reference
classification, to speed-up precicion/recall computation.

```bash
validation$ utils/filter_concepts_for_verification.rb
```

### Update reference classification

Update reference classification to use latest Wikipedia article names.

```bash
validation$ utils/update_names_with_redirects.rb
```
