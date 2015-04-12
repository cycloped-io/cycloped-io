# Data

* `apohl_dbpedia_class_cyc_mapping.csv` - old mapping between DBpedia classes
  and Cyc concept manually created by A. Pohl
* `apohl_dbpedia_class_cyc_missing.csv` - mappings missing in the old mapping
  (wrt to old DBpedia)
* `dbpedia_3.9.owl` - DBpedia ontology 3.9
* `dbpedia_class_cyc_concept_mapping.csv` - mapping between DBpedia classes and Cyc
  concepts created on the basies of SD DBpedia - Umbel mapping and short-cut
  mappings between DBpedia and Cyc
* `dbpedia_hierarchy.yml` - hierarchy of DBpedia classes in YAML format
* `pair_conflicts.csv` - detected conflicts in DBpedia mappings
* `pair_conflicts_heuristic.csv` - detected conflicts in DBpedia mappings (heuristic)
* `pair_conflicts_only_FO.csv` - detected conflicts in DBpedia mappings (only
  first order collections)
* `shortcut_dbpedia_cyc_mapping.csv` - short-cut mapping between DBpedia classes
  and Cyc concepts, for entries that are not present in UMBEL or are ambiguous
* `sd_dbpedia_class_mapping_annotated.csv` - annotated manula mapping between
  DBpedia and Umbel created by Mike/SD

# DBpedia mapping

## Transform DBpedia instances file to CSV format

DBpedia uses n-triple format - this script converts them to CSV. It converts
both TTL and NT file formats.

```bash
dbpedia-mapping$ utils/convert_dbpedia_to_csv.rb -i instance_types_en.ttl -o dbpedia_instances.csv
dbpedia-mapping$ utils/convert_dbpedia_to_csv.rb -i instance_types_heuristic_en.ttl -o dbpedia_instances_heuristic.csv
```

## Convert DBpedia mapping from UMBEL to Cyc

DBpedia is manually mapped to UMBEL. This scripts converts that mapping from
UMBEL to Cyc thanks to UMBEL to Cyc mapping and several short-cut mappings from
DBpedia to Cyc.

```bash
dbpedia-mapping$ utils/convert_dbpedia-umbel_to_dbpedia-cyc.rb -b data/sd_dbpedia_class_mapping_annotated.csv -c ../category-mapping/data/umbel_to_cyc_mapping.csv -o dbpedia_to_cyc.csv
```

## Check consistency of collections of articles in DBpedia

Check consistency of classification of DBpedia resources. 

```bash
dbpedia-mapping$ utils/check_consitency_of_types.rb -b dbpedia_instances_heuristic.csv -i dbpedia_class_cyc_mapping.csv -c pair_conflicts_heuristic.csv
```

## Export DBpedia ontology

Export DBpedia ontology to simpler format (YAML).

```bash
dbpedia-mapping$ utils/export_ontology.rb
```
