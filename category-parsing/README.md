# Category parsing

## Data

* `noun` directory - contains lists and mappings of nouns forms (plural, singular, countable, etc.). They are used to identify plural forms and transform to singular. Generated from wiktionary dump using https://github.com/djstrong/nouns-with-plurals. Two columns (singular and plural form) have files: `noun.csv`, `noun_countable_and_uncountable.csv`, `noun_usually_uncountable.csv`.
  * `noun.csv` - countable nouns
  * `noun_countable_and_uncountable.csv` - e.g. http://en.wiktionary.org/wiki/beers
  * `noun_uncountable.csv` - nouns that cannot be used freely with numbers or the indefinite article, and which therefore takes no plural form, e.g. http://en.wiktionary.org/wiki/lycra
  * `noun_usually_uncountable.csv` - e.g. http://en.wiktionary.org/wiki/information
  * `noun_unknown.csv` - nouns with unknown or uncertain plural
  * `noun_pluralia_tantum.csv` - nouns that has no singular form, e.g. http://en.wiktionary.org/wiki/scissors
  * `noun_not_attested.csv` - nouns with plural not attested



* `tree_stats_all.csv` - grammatical trees of Wikipedia category names with counts
* `tree_stats_ok.csv` - grammatical trees of Wikipedia category names with counts, whose head nouns are marked as correct
* `tree_stats_error.csv` - grammatical trees of Wikipedia category names with counts, whose head nouns are marked as incorrect
* `parsing-errors.txt` - parsed category names with identified heads, that are inconsistent
* `parsing-samples.txt` - sample parsed category names with identified heads, that are consistent

## Scripts flow

###  Remove commas and brackets for better parsing

```bash
category-parsing$ ruby utils/filter_commas_and_brackets.rb -c categories.csv -o preprocessed_categories.csv
```

### Prepare data for Stanford Parser by adding suffix "are good." to category names

```bash
category-parsing$ ruby utils/add_suffix.rb -c preprocessed_categories.csv > preprocessed_categories_to_parse.txt
```

### Parse using Stanford Parser

```bash
java -Xmx4g -cp stanford-parser.jar:stanford-parser-3.3.1-models.jar edu.stanford.nlp.parser.lexparser.LexicalizedParser -outputFormat "oneline, typedDependenciesCollapsed" -outputFormatOptions "markHeadNodes" -sentences newline -retainTmpSubcategories edu/stanford/nlp/models/lexparser/englishPCFG.ser.gz preprocessed_categories_to_parse.txt > preprocessed_categories.parsed
```

###  Merge parsing results with category names in CSV

```bash
category-parsing$ ruby utils/join_parsed_data.rb -s preprocessed_categories.csv -p preprocessed_categories.parsed -o parsed_preprocessed_categories.csv
```

### Filter administrative, list, stub and etc. categories

```bash
category-parsing$ ruby utils/filter_administartive.rb -p parsed_preprocessed_categories.csv -a administrative.csv -o parsed_preprocessed_categories_wo_administrative.csv
```

### Fix plurals using Wiktionary data and find noun heads

```bash
category-parsing$ ruby utils/parse_category_names.rb -c parsed_preprocessed_categories_wo_administrative.csv -o parsed_with_heads.csv -e errors
```

### Load heads to ROD

**This is run in `rlp` subproject**.

```bash
rlp$ ruby utils/categories/load_parses.rb -d data/en-2013 -f ../category-parsing/parsed_with_heads.csv
```

### Compute statistics

```bash
category-parsing$ ruby utils/chars_stats.rb -c parsed_with_heads.csv
category-parsing$ ruby utils/words_stats.rb -c parsed_with_heads.csv > words_stats
```

### Aggregated Rake task

`category-parsing$ RLP_DATA_PATH=path/to/data STANFORD_PARSER_PATH=path/to/parser RLP_DB_PATH=path/to/db rake`
