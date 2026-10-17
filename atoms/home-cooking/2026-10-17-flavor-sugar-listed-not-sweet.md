---
id: home-cooking/flavor-sugar-listed-not-sweet
type: myth-busting
depth: intermediate
source_type: note
source_ids: ["raw/recipe_corpus_full.json#dish=地三鲜", "raw/recipe_corpus_full.json#dish=青椒肉丝", "raw/recipe_corpus_full.json#dish=鱼香肉丝", "raw/recipe_corpus_full.json#dish=水煮肉片", "raw/recipe_corpus_full.json#dish=麻婆豆腐", "raw/recipe_corpus_full.json#dish=糖醋排骨", "raw/recipe_corpus_full.json#dish=可乐鸡翅", "scripts/flavor-stats.py"]
reuse_score: medium
tags: [五味, 甜, 糖, 提鲜]
created: 2026-10-17
---

食材表里有糖不等于菜是甜的：多数咸鲜菜放的是几克“提鲜”糖，判断甜度要看用量，而不是看有没有糖。

全量统计里，地三鲜约 2/3 的菜谱加糖、青椒肉丝约一半加糖，水煮肉片和麻婆豆腐也常见“少许糖”，但这些菜谱写“大量糖”（≥3 克、≥2 勺、冰糖或可乐）的比例只有 7%–16%。真正以甜为主味的菜，大量糖的比例高得多：可乐鸡翅 96%、糖醋排骨 71%、红烧肉 73%。

所以五味评分里，地三鲜、青椒肉丝的甜只给 1–2 分。作者们对这类糖的说法也一致：用来“提鲜”“中和”，而不是让菜变甜。

> 出典: scripts/flavor-stats.py 的 sugar_big 指标（地三鲜 0.16、青椒肉丝 / 水煮肉片 0.07、麻婆豆腐 0.10、可乐鸡翅 0.96、糖醋排骨 0.71、红烧肉 0.73）
