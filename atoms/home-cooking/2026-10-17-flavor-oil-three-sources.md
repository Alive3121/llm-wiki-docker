---
id: home-cooking/flavor-oil-three-sources
type: explanation
depth: intermediate
source_type: note
source_ids: ["raw/recipe_corpus_full.json#dish=糖醋里脊", "raw/recipe_corpus_full.json#dish=地三鲜", "raw/recipe_corpus_full.json#dish=辣子鸡", "raw/recipe_corpus_full.json#dish=梅菜扣肉", "raw/recipe_corpus_full.json#dish=红烧肉", "raw/recipe_corpus_full.json#dish=水煮肉片", "raw/recipe_corpus_full.json#dish=清蒸鲈鱼", "raw/recipe_corpus_full.json#dish=白切鸡", "scripts/flavor-stats.py"]
reuse_score: high
tags: [五味, 油, 油炸, 泼油, 五花肉]
created: 2026-10-17
---

家常菜的“油”有三个来源：过油炸、肥肉出油、出锅泼热油，重油菜至少占其中一项。

- 过油炸：糖醋里脊 95% 的菜谱有炸的步骤，地三鲜 73%，辣子鸡 68%。外壳或茄子会吸油，这是不辣菜也能很油的原因。
- 肥肉出油：红烧肉、梅菜扣肉约 90% 用五花肉，长时间烧或蒸把肥肉里的油逼出来，油来自食材本身。
- 泼热油：水煮肉片约 1/4 的菜谱在步骤中明确写泼油（细读样本时约 27/30），清蒸鲈鱼约 29/30 用一勺热油激香葱丝，白切鸡的姜葱蘸料也是热油泼出来的。

前两类的油留在菜里，第三类的量差别很大：水煮肉片泼的是一层油，清蒸鲈鱼只有一勺。这也是清蒸鲈鱼、白切鸡的油只评 2 分的原因。

> 出典: scripts/flavor-stats.py 的 deepfry / fatty / pour_oil 指标；样本细读见 home-cooking/shui-zhu-rou-pian-hot-oil-pour-finish、home-cooking/qing-zheng-lu-yu-hot-oil-on-fresh-scallion、home-cooking/bai-qie-ji-ginger-scallion-hot-oil-dip
