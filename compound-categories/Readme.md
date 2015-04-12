# Compound categories

## Data

Empty (so far).

## Scripts 

### Detection of proper names in category names

Scritp for detecting proper names (i.e. Wikipedia article names) in categories.
The results are used both for detecting eponymous categories and compound
category patterns.

```bash
compound-categories$ utils/find_entities_in_category_names.rb
```

### Eponymous category discovery

Script for discovering eponymous categories (based on category-article name
matching). The assumption is that if the whole category name matches an article
it means that the category is based on the article.

```bash
compound-categories$ utils/export_eponymous_categories.rb
```

### Detection of patterns in category names

Script for detecting patterns in catgory names. At the same time it discoverst
patterns with 1,2,3 and 4 variables.

```bash
compound-categories$ utils/discover_patterns.rb
```

### Detection of pattern and preidcate constraints

Script for computing statistics for patterns and predicate matches, used to
infere constraints for predicate arguments and pattern variables.

```bash
compound-categories$ utils/discover_constraints.rb
```

### Extraction and merging of individual pattern variables

Script for dividing the stats for individual variables in category name
patterns.

```bash
compound-categories$ utils/divide_constraints.rb
```

### Export of pattern constraints

Script for exporting selected computed pattern constraints. It takes into
account several factors, entropy in particular, to ensure high quality of the
constraints.

```bash
compound-categories$ utils/export_pattern_mapping.rb
```

### Pattern matching

Script for matching patterns against category names.

```bash
compound-categories$ utils/match_patterns.rb
```

### Pattern mapping assignment

Script used to assign mapping of patterns to individual categories

```bash
compound-categories$ utils/assign_pattern_mapping.rb
```
