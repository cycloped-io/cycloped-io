# Conclict resolution of different type assignemnts

## Data

## Scripts

### Conflict resolution

The script is responsible resolving the concflicts in type assignment between
different classification methods. Its primary application is the resolution of
type assignment conflicts for Wikipedia articles, but it might be used to detect
inconsistencies in any group of Cyc terms, that should be inherently consistent. 
The result of the script is a file with Cyc terms grouped into ,,partitions'',
with indication of a strength of each group. This allows for selecting the group
that has the largest support. However this is done by a separate script (e.g.
export_results.rb).

```bash
conflict-resolution$ ./utils/conflict_resolution.rb
```

### Export of results

This script exports the results of the conflict resolution by selecting the
group of terms with the highest support. In case there are two such groups, the
first one that appears in the file is selected.

```bash
conflict-resolution$ ./utils/export_results.rb
```

### Display graph of terms

Create PNG file with graph of terms on the basis of a text file with the
definitions of edges between the nodes. Might be useful for inspecting the type
structure for a given article.

```bash
conflict-resolution$ ./utils/display_graph.rb
```
