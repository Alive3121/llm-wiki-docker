---
id: home-cooking/flavor-scoring-method-proxy-indicators
type: explanation
depth: intermediate
source_type: note
source_ids: ["raw/recipe_corpus_full.json#dish=白切鸡", "raw/recipe_corpus_full.json#dish=清蒸鲈鱼", "raw/recipe_corpus_full.json#dish=鲫鱼豆腐汤", "raw/recipe_corpus_full.json#dish=青椒肉丝", "raw/recipe_corpus_full.json#dish=西红柿炒鸡蛋", "raw/recipe_corpus_full.json#dish=酸汤肥牛", "raw/recipe_corpus_full.json#dish=酸辣土豆丝", "raw/recipe_corpus_full.json#dish=酸菜鱼", "raw/recipe_corpus_full.json#dish=糖醋排骨", "raw/recipe_corpus_full.json#dish=糖醋里脊", "raw/recipe_corpus_full.json#dish=可乐鸡翅", "raw/recipe_corpus_full.json#dish=京酱肉丝", "raw/recipe_corpus_full.json#dish=红烧肉", "raw/recipe_corpus_full.json#dish=梅菜扣肉", "raw/recipe_corpus_full.json#dish=地三鲜", "raw/recipe_corpus_full.json#dish=鱼香肉丝", "raw/recipe_corpus_full.json#dish=口水鸡", "raw/recipe_corpus_full.json#dish=麻婆豆腐", "raw/recipe_corpus_full.json#dish=辣子鸡", "raw/recipe_corpus_full.json#dish=水煮肉片", "scripts/flavor-stats.py"]
reuse_score: medium
tags: [五味, 评分方法, 统计, 辣, 酸, 甜, 油, 咸]
created: 2026-10-17
---

20 道家常菜的五味分数（辣、酸、甜、油、咸各 1–5 分）是用菜谱食材与步骤里的代理指标统计出来、再经人工校正的，不是品尝评分。

统计对象是 raw/recipe_corpus_full.json 中 dish 字段等于该菜名的全部菜谱，每道 451–2129 份。指标定义（脚本 scripts/flavor-stats.py）：

- 辣：每份菜谱中辣味料食材行的平均数（干辣椒、小米辣、花椒、郫县豆瓣、剁椒、泡椒、红油、辣椒油、黄灯笼等）。水煮肉片 2.79、麻婆豆腐 2.11 最高，糖醋里脊 0.04 最低。
- 酸：酸味料行数（醋、番茄、西红柿、酸菜、柠檬、黄灯笼等），以及“用量大”的比例。糖醋里脊 1.55、酸汤肥牛 1.46 最高。
- 甜：甜味料行数（糖、冰糖、蜂蜜、可乐、番茄酱、甜面酱），以及“大量糖”（≥3 克或 ≥2 勺、冰糖、可乐）的比例。
- 油：步骤中“炸 / 过油 / 宽油”的比例、“泼热油”的比例、是否用五花或肥肉。食材行里的“油”排除了酱油、蚝油、豉油。
- 咸：咸味调料种类数（盐、酱油、生抽、老抽、蚝油、豆瓣、甜面酱、梅菜等）。

局限：菜谱只写放了什么、很少写尝起来多重，所以指标反映的是“用了多少种、多常用”，不是浓度。油和咸两项误差最大，约 ±1 分；辣、酸、甜较可靠。最终分数在指标排序基础上，结合各道菜 atom 中对 30 份样本的细读做了校正（例如白切鸡的油主要来自姜葱热油蘸料）。

> 出典: scripts/flavor-stats.py 对 20 道菜全量菜谱的统计（2026-10-17 运行）
