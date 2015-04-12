# Article classification

## Utilies

### Classify articles using categories

Types are assigned to the Wikipedia articles via a mapping between Wikipedia
categories and Cyc terms. Each article receives types from all its categories
that have a corresponding term in Cyc (provided in the mapping file).

```bash
classification$ ./utils/classify_using_categories.rb
```

### Classify articles using DBpedia

Types are assigned based on mapping between DBpedia ontological classes and Cyc
terms. The script uses a conversion from DBpedia ttl file to CSV and a mapping
between Cyc and DBpedia.

```bash
classification$ ./utils/classify_using_dbpedia.rb
```

### Convert classification to RDF

The scripts converts the classification from CSV format to RDF format.

```bash
classification$ ./utils/classification_to_rdf.rb
```

### Convert classification from Cyc to Umbel

The script converts the classification of articles from Cyc terms to Umbel
reference concepts.

```bash
classification$ ./utils/convert_cyc_to_umbel_classification.rb
```

### Merge two classifications

The script merges two classification. It preserves duplicated entries.

```bash
classification$ ./utils/merge_classification.rb
```

### Export unique term stats

Export statistics of unique Cyc and UMBEL terms.

```bash
classification$ ./utils/export_unique_terms_stats.rb
```

### Export SuperType stats

Export statistics regarding UMBEL SuperType coverage.

```bash
classification$ ./utils/export_supertypes_stats.rb
```

### Classification translation

Translate the classification to the other Wikipedia edition (i.e. provide the
types for articles with names in a different language).

```bash
classification$ ./utils/translate.rb
```

### Articles without classification

Export list of regular articles that lack classification.

```bash
classification$ utils/articles_without_type.rb
```
