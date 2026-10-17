# Wiki Change Log


## 2026-10-17

- ingest+compile: home-cooking +15 dishes (白切鸡..水煮肉片) from raw/recipe_corpus_full.json, 97 atoms; + home-cooking-flavor-comparison (五味对比, 6 atoms with source_type: note, radar via scripts/gen-flavor-radar.py, stats via scripts/flavor-stats.py, image in wiki/assets/). home-cooking now 142 atoms / 21 pages — exceeds 30-atom split threshold, split pending user decision.

## 2026-10-13

- ingest+compile: recipe pilot from raw/recipe_corpus_full.json (20 dishes x 30 samples) -> branches home-cooking(39), baking(34), staples(34), desserts-drinks(39) = 146 atoms, 20 wiki pages. New branches approved by user 2026-10-13; gen-index.sh BRANCHES set explicitly because branch names contain hyphens.
