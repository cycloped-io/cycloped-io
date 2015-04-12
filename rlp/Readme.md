# Rlp-Wiki

Object-oriented access to Wikipedia data.

*Note:* Ruby Object Data works only with Ruby v. 1.9.2 (not higher!). We
recommend installing that version of Ruby with [Ruby Version Manager](http://rvm.io).

## Description

Rlp-Wiki uses Ruby Object Database (ROD) to provide fast access to selected part
of Wikipedia data. This library links articles with their categories, included
templates, infoboxes, etc. It also contains statistics valuable in
Wikipedia-related text processing tasks.

## Notions

* Page - any Wikipedia page in any namespace, i.e. regular articles, categories,
  templates, redirectes, disambiguation pages, etc.
* Article/Concept - a regular Wikipedia page that belongs to the default Wikipedia
  namespace and does not have any special meaning, this excludes disambigation
  pages, redirects, etc.
* Category - any Wikipedia page that belongs to the Category namespace. These
  should exclude category redirects, disambiguation, etc. but so far these
  special kinds of categories are NOT kept separately
* Redirect - a redirect from an alternative name to a regular article (so far this
  excludes category and other redirects).
* Translation - a name of a Wikipedia page in a language different than English
* Anchor - a text used to link to articles inside Wikipedia
* Occurrence - a link between an anchor and a target article
* Infobox - a name of an infobox used in Wikipedia articles

## Scripts

### Download

`utils/download.rb` is used to automatically download necessary dumps of
Wikipedia files. It check the checksums of files, so in case of problems it
reports it back to the user.

You can also run the task by issuing a `rake` task:

```bash
rlp$ RLP_DATA_PATH=/path/to/data RLP_DB_PATH=/path/to/db rake download

### Console

`utils/console.rb` is a script allowing for an interactive access to the
database. The console features access to both the DB and full Ruby environment,
thus any more or less complicated manipulations are possible, e.g.

```ruby
# print names of the first child of non-empty administrative categories:
Category.each{|c| puts c.children.first.name if c.administrative? && c.children.count > 0 } 

# print categories of a given concept
concept = Concept.find_by_name("Michael Jackson")
concept.categories.each{|c| puts c.name }
```

### Loading

The loading of the data has to follow a step by step procedure. Since each step
may take several hours, it is advisable to make backup copies during that
procedure. The scripts are described in the order of running.

* `utils/load/init.rb` - load initial Wikipedia data, i.e. concepts, categories,
  redirects, disambiguation pages and templates (so far the last two types of
  pages are omitted).
* `utils/load/redirects.rb` - link articles with their redirects
* `utils/load/categories.rb` - link categories with their children and articles
* `utils/load/anchors.rb` - load anchors
* `utils/load/occurrences.rb` - load occurrences, i.e. link articles with their anchors
* `utils/load/links.rb` - link articles with other articles that link to or are
  linked from the article
* `utils/load/offsets.rb` - load offsets of the article contents in the main
  (XML) Wikipedia dump

The data that is loaded has to be first extracted from Wikipedia SQL files (via
our own scripts) and from Wikipedia article contents (via Wikipedia Miner). In
future most of the data will be loaded from the SQL files, since WM is no longer
developed.

You can also load the data in a sequence using Rake. From the `rlp` directory
call:

```bash
rlp$ RLP_DATA_PATH=path/to/extracted/data RLP_DB_PATH=path/to/db rake
```

`RLP_DATA_PATH` is the path to the directory where the data extracted by SQL
extraction scripts is stored. `RLP_DB_PATH` is the path to the ROD database. It
will be created if it does not exist. Make the path convenient, since it will be
used in many of the other scripts.

### Category processing

Scripts used to find and filter-out administrative categories.

#### Finding categories with administrative templates

The script consults the `templates.csv` file and registers ids of categories
with administrative template:

```bash
rlp$ utils/categories/find_administrative_templates.rb
```

#### Marking administrative categories in ROD

This script uses the file with marked categories that contain the administrative
template and uses the regexps to mark administrative categories in the ROD
database.

```bash
rlp$  utils/categories/mark_administrative.rb
```

#### Export administrative categories 

This script exports the administrative categories to an external file in order
to consult the results.

```bash
rlp$ utils/categories/export_administrative.rb
```

#### Load category heads to ROD

**You need to parse the category names first**.

The script loads the parsed categories to the ROD database.

```bash
rlp$ ruby utils/categories/load_parses.rb
```

#### Rake tasks

You can find, mark and export the administrative categories in a sequence
using the following `Rake` tasks:

```bash
rlp$ RLP_DATA_PATH=path/to/extracted/data RLP_DB_PATH=path/to/db rake administrative:all
```

You can load the parsed categories using the following task:

```bash
rlp$ RLP_DATA_PATH=path/to/extracted/data RLP_DB_PATH=path/to/db rake load:heads
```


### Statistics

* `utils/stats/categories.rb` - compute statistics for categories and articles,
  e.g. what is the mean and median of category children count

### Special pages

* `utils/special_pages/identify_lists.rb` - identifies list pages
* `utils/special_pages/identify_disambiguation_pages.rb` - identifies disambiguation pages
* `utils/special_pages/identify_indexes.rb` - identifies oher special pages, i.e. indexes, outlines, glossaries, data pages

* `utils/load/lists_indexes.rb` - load all special pages to database

## Data

`data` directory:

* `config.en.yml` - edition specific configuration for English Wikipedia
* `config.pl.yml` - edition specific configuration for Polish Wikipedia
* `wikipedia_dumps.txt` - list of Wikipedia SQL files that are downloaded and
  parsed in order to create ROD database

`data/categories` directory:

* `ids_including_admin_template.csv` - list of category ids that include `admin`
  template
* `prefix_match.txt` - list of prefix matches for administrative categories
* `root_administrative.txt` - list of root administrative categories, whos
  children and grand children are marked as administrative
* `strict_match.txt` - list of words that are strictly matched in administrative 
  category names 
* `universal_match.txt` - list of character sequences that are universally
  matched in administrative category names
* `whitelist_categories.txt` - list of categories that are excluded in child and
  grand-child category marking

`data/special_pages` directory:
* `lista_pages.csv` - identified list pages
* `disambiguation_pages.csv` - - identified disambiguation pages
* `indexes_outlines_glossaries_data.csv` - other special pages, i.e. indexes, outlines, glossaries, data pages
