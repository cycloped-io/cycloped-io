# Parsing of first sentences in Wikipedia abstracts

## Scripts

### Extract abstract from DBpedia

Script used to extract abstracts from DBpedia TTL files.

```bash
utils/extract_abstracts_from_dbpedia.rb
```

### Filter brackets

Remove brackets in the abstracts.

```bash
utils/filter_brackets.rb
```

### Parse definitions

Extract definition types from parsed information.

```bash
utils/filter_brackets.rb
```

### Map types

Map types to Cyc terms using raw categories as support.

```bash
utils/map_types.rb
```

### Choose best candidates

Choose best candidates for every type.

```bash
utils/export_disambiguation_results.rb
```