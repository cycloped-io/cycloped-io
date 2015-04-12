# Data

(files in `data` directory)

* `abstract_level.txt` - Cyc concepts too abstract to be used in the mapping
  between Wikipedia categories and Cyc
* `added_to_umbel.txt` - list of reference concepts that were added to Umbel and
  are missing from OpenCyc
* `apohl_categories_to_cyc.csv` - A. Pohl manual mapping between Wikipedia
  categories and Cyc terms
* `clients.yaml` - addresses of non-English Wikipedia editions (at our internal
  severs)
* `conflicts_category_wise.csv` - conflicts between manual mapping of Wikipedia
  categories of A. Pohl and SD
* `conflicts_resolution.csv` - file with resolved conflicts between manual
  mappings
* `cyc_to_umbel_mapping.csv` - mapping between Cyc terms and Umbel concepts with
  ambiguities removed (umbel_to_cyc.csv is not an injection, while
  cyc_to_umbel_mapping.csv is)
* `cyc_wiki_umbel.csv` - Mappings extracted from opencyc-latest.owl (Header: Cyc
  ID, Umbel, DBpedia, Wikipedia) to:
  * Umbel
  * DBpedia 
  * Wikipedia 
* `intersection_categories_to_cyc.csv` - intersection between manual mappings of
  categories to Cyc from A. Pohl mapping and SD mapping
* `manual_reference_mapping.csv` - union of manual mappings form categories to 
  Cyc term based on A. Pohl and SD mapping (used to compute stats regarding
  precision and recall of automatic methods)
* `manual_umbel_wiki_cyc.csv` - SD manual mapping between categories and Umbel
  and Cyc concepts, Header: Wikipedia category, Umbel, Cyc ID, Cyc Name
* `missing_in_apohl.csv` - concepts missing in A. Pohl mapping of Wikipedia
  categories to Cyc concepts that are present in SD mapping
* `missing_in_apohl_reviewed.csv` - manual review of the above, with some
  mappings removed
* `missing_in_sd.csv` - concepts missing in SD mapping of Wikipedia
  categories to Cyc concepts that are present in A. Pohl mapping
* `resolve_cycles.csv` - file used to resolve cycels in (English) Wikipedia
  categories
* `sd_categories_to_cyc.csv` - file created from `manual_umbel_wiki_cyc.csv`
  converted to common format
* `SD_umbel_wiki_cyc_filtered.csv` - SD manual mapping from Wikipedia categories
  to Umbel and Cyc with some mappings filtered
* `semantic_parents_without_cycles.csv` - list of Wikipedia categories and their
  semantic parents with cycles removed
* `umbel_concepts.csv` - list of all Umbel concepts with labels and parent concepts.  Header: Name, Label, *Parents
* `umbel_to_cyc_mapping.csv` - mapping from Umbel to Cyc. Header: Umbel name, Cyc id, Cyc name
* `umbel_to_cyc_mapping_ambiguous.csv` - Umbel names that have multiple possible mappings in Cyc. Header: Name, Label, *Parents
* `umbel_to_cyc_mapping_missing.csv` - concepts present in Umbel but missing
  from Cyc (i.e. concepts that were added to Cyc). Header: Name, label, *Parents

(files in `data/automatic_mapping` directory)

* `local_support.csv` - mapping between Wikipedia catgorie and Cyc concept using
  local heuristics, these results are ambiguous

# Scripts

## Category mapping

### Semantic parents

#### Finding semantic parents.

Use Cyc `genls` relation to find semantic parents for Wikipedia categories.

```bash
category-mapping$ ruby utils/find_semantic_parents.rb -o semantic_parents.csv
```

Use additional data from other Wikipedia editions for finding semantic parents.

```bash
category-mapping$ ruby utils/find_semantic_parents_with_other_languages_data.rb -o semantic_parents.csv
```

Use WordNet hypernymy relation to find semantic parents for Wikipedia
categories.

```bash
category-mapping$ ruby utils/find_semantic_parents_wordnet_data.rb -o semantic_parents.csv
```

#### Find cycles in semantic parents.

Wikipedia category parent graph should be acyclic. This script find cycles in
that graph and stores them in text format for manual inspection.

```bash
category-mapping$ ruby utils/semantic-parents/find_semantic_cycles.rb -c semantic_parents.csv -o semantic_cycles.csv
```

#### Generate description about cycles in Markdown format.

Convert the file with cycles to Markdown format with simple decisions. Generate file resolve_parents.csv with rules, which should be manually corrected.

```bash
category-mapping$ ruby utils/resolve_cycles.rb -p semantic_parents.csv -c semantic_cycles.csv -o resolve_parents.csv
```

#### Remove cycles using resolve_cycles.csv data.


Remove cycles from the semantic parent category graph using rules in resolve_cycles.csv.

```bash
category-mapping$ ruby utils/delete_cycles.rb -c semantic_parents.csv -o semantic_parents_without_cycles.csv -r resolve_cycles.csv
```

#### Check if cycles still exist

If cycles still exist you need to correct rules and remove cycles again (previous step).

```bash
category-mapping$ ruby utils/check_cycles.rb -c semantic_parents_without_cycles.csv -o semantic_cycles.csv
```

#### Load semantic parents to ROD.

This script is in RLP subproject. It loads the semantic-parent information to
the ROD database.

```bash
rlp$ ruby utils/load/semantic_parents.rb -w ../category-mapping/semantic_parents_without_cycles.csv -d data/en-2013
```

#### Load semantic children to ROD

Load semantic children using semantic parents for speed up.

```bash
rlp$ ruby utils/load/semantic_children.rb -d data/en-2013
```

### Automatic Category mapping

#### Compute local support

For each regular and plural Wikipedia category the scripts finds the candidate
Cyc terms via name mapping and assigns the number of matching parent categories,
child categories and instances. The output file also includs information if the
whole name of the categor was matched.

```
utils/local_support.rb
```


#### Compute global support

Compute global support - accumulate support on lower levels and promote them to
top levels of category hierarchy.

```
utils/global_support.rb
```


#### Apply global mapping heuristic

Apply global heuristic to compute consistent mapping between categories and
concepts.

```
utils/global_heuristic.rb
```

#### Print disambigation results

Since the results of the heuristics are hard to read, this script prints
the results in a human-readable and colorful form.

```
utils/show_mapping_results.rb
```

#### Print disambiguation statistics

This script computes various statistics regarding for the mapping,
such as:

* the number of unambiguous mappings
* the number of ambiguous mappings
* number of unique cyc terms in the mapping

```
utils/show_disambiguation_stats.rb
```

#### Export results of mapping

The script exports the results of disambiguation heuristics in a format
that is useful for assigning these results to individual Wikipedia articles.

```
utils/export_disambiguation_results.rb
```


#### Article coverage

Computes article classification coverage, based on the mapping of Wikipedia
categories.

```
utils/article_coverage.rb
```

#### OpenCyc.owl

Extract mappings from opencyc.owl file (http://sw.opencyc.org)

```
utils/extract_mappings_from_opencyc.rb
```

#### Conflict detection between mapping and child/parent relationships

Detect conflicts between automatic category mapping and mappings on higher and
lower levels of category hierarchy.

```
utils/detect_mapping_conflicts.rb
```

### Manual category mapping


#### Convert n3 Umbel - Wikipedia mappings to Cyc mappings

The script guesses the cyc concepts names and writes the mappings with missing
concepts to external file.

```
utils/convert_umbel_mappings_to_cyc.rb -f wikipediaCategories.n3 -m manual_umbel_wiki_cyc.csv -e missing.csv [-p port] [-h host]
```

#### Filter SD mapping

Remove from the SD mapping singular Wikipedia categories.

```
utils/filter_sd_mapping.rb -f input.csv -o output.csv [-d database]
```

#### Convert SD mapping to common format

The resulting file will have the same format as A.Pohl mapping simplifying
processing:

```
utils/convert_sd_mapping.rb -f input.csv -o output.csv
```

#### Compare two mappings

Designed to compute conflicts between SD and A.Pohl mappings, but may be used to
compare any mappings in common format.

Computes the following sets:

* intersection between mappings (category-wise)
* conflicts in the intersection (category-wise)
* missing mappings in the first and the second mapping


```
utils/compare_mappings.rb -a first_mapping.csv -b second_mapping.csv [-i intersection.csv] [-c conflicts.csv] [-d missing_in_first.csv] [-e missing_in_second.csv]
```


### Cyc - Umbel concept mapping

#### Extract Umbel reference concepts names

Extract from Umbel n3 file names of all reference concepts and write them in CSV
file.

```
utils/extract_umbel_concept_names.rb
```

#### Analyse mapping between Cyc and Umbel

The script find concepts that are in Umbel and are missing in Cyc, were renamed
in Cyc, etc.

```
utils/analyse_automatic_mapping.rb
```

# Rake

## Semantic parents and cycle resolution

Cycles resolution is manual task.

### Run Cyc server

`opencyc/opencyc-4.0$ ./scripts/run-cyc.sh`

### Find semantic parents

`category-mapping$ rake semantic:parents`

### Find semantic cycles

`category-mapping$ rake semantic:cycles`

File `RLP_DATA_PATH/semantic_cycles.csv` is created with detected cycles paths.

### Cycles resolution

Every cycle needs manual resolution. It is needed to create file `RLP_DATA_PATH/resolve_cycles.csv` with child-parent relation and action (delete or add). Every row has 3 columns ([example file](https://github.com/structureddynamics/wikipedia-umbel/blob/master/category-mapping/data/resolve_cycles.csv)): action (DEL or ADD), child category name, parent category name.

Generate sample `resolve_cycles.csv` file with all relations deleted between first two categories in cycle. Also print parents of all categories in cycles.

`category-mapping$ rake semantic:resolve`

### Delete cycles

`category-mapping$ rake semantic:delete`

### Check cycles after deletion

`category-mapping$ rake semantic:check`

If there are cycles, the notification `Cycles exist!` is printed. If so you have to follow steps from "Cycles resolution".

### Load semantic parents to ROD

If there is no cycles, we can load semantic parents to ROD.

`category-mapping$ rake semantic:load`

### Load semantic children to ROD

Load semantic children using semantic parents for speed up.

`category-mapping$ rake semantic:children`
