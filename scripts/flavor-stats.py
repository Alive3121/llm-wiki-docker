#!/usr/bin/env python3
"""五味指标统计: per-dish flavor indicators over raw/recipe_corpus_full.json (read-only).

Usage: python scripts/flavor-stats.py raw/recipe_corpus_full.json out.json
Output per dish (averaged over all recipes whose `dish` field matches):
  hot/sour/sweet/salty = mean number of ingredient lines matching that flavor's seasonings
  oil_items            = mean oil ingredient lines (酱油/蚝油/豉油 excluded)
  deepfry / pour_oil   = share of recipes whose steps deep-fry / pour hot oil
  fatty                = share using 五花/肥肉
  sugar_big / vinegar_big = share with a large sugar / sour-ingredient amount
Used for wiki/home-cooking-flavor-comparison.md (scores = these indicators + judgment).
"""
import json, sys, re, collections
src, out = sys.argv[1:3]
D = ['清蒸鲈鱼','白切鸡','鲫鱼豆腐汤','西红柿炒鸡蛋','酸汤肥牛','酸辣土豆丝','酸菜鱼','糖醋排骨','糖醋里脊','可乐鸡翅','红烧肉','京酱肉丝','鱼香肉丝','口水鸡','麻婆豆腐','水煮肉片','辣子鸡','地三鲜','梅菜扣肉','青椒肉丝']
OIL_ING = re.compile(r'(?<![酱蚝豉])油(?![菜麦豆条面])|猪油|红油|辣椒油|花椒油|香油|麻油')
NUM = re.compile(r'(\d+(?:\.\d+)?)\s*(克|g|ml|毫升|勺|汤匙|大勺)')
P = {
 'hot': r'干辣椒|小米辣|朝天椒|花椒|麻椒|郫县|豆瓣|剁椒|泡椒|火锅底料|辣椒面|辣椒粉|辣椒油|红油|黄灯笼|辣',
 'sour': r'醋|柠檬|番茄|西红柿|酸菜|泡菜|酸笋|山楂|黄灯笼|酸汤',
 'sweet': r'糖|蜂蜜|可乐|番茄酱|甜面酱|麦芽|蜜',
 'salty': r'盐|酱油|生抽|老抽|蚝油|豆豉|豆瓣|黄豆酱|甜面酱|梅菜|咸|腊|酱',
}
st = {d: collections.Counter() for d in D}; n = collections.Counter()
with open(src, encoding='utf-8') as f:
    for line in f:
        if not any(d in line for d in D): continue
        r = json.loads(line); d = r.get('dish')
        if d not in st: continue
        ings = r.get('recipeIngredient') or []; steps = '；'.join(r.get('recipeInstructions') or [])
        n[d]+=1; a = st[d]
        for k,p in P.items(): a[k] += len([i for i in ings if re.search(p,i)])
        oil_items = [i for i in ings if OIL_ING.search(i)]
        a['oil_items'] += len(oil_items)
        a['deepfry'] += bool(re.search(r'炸|过油|油温|半锅油|宽油', steps))
        a['pour_oil'] += bool(re.search(r'泼|淋.{0,3}热油|浇.{0,3}热油', steps))
        a['fatty'] += bool(re.search(r'五花|肥', '；'.join(ings)))
        a['sugar_big'] += bool(re.search(r'(\d{2,}|[3-9])\s*(克|g).{0,2}糖|糖.{0,4}(\d{2,})\s*(克|g)|[2-9]\s*勺.{0,2}糖|糖.{0,3}[2-9]\s*勺|冰糖|可乐', '；'.join(ings)))
        a['vinegar_big'] += bool(re.search(r'醋.{0,4}([2-9]|\d{2,})\s*(勺|克|g|ml|汤匙)|([2-9]|\d{2,})\s*(勺|克|g|ml).{0,2}醋|番茄|西红柿|酸菜|黄灯笼|柠檬', '；'.join(ings)))
res = {d: {'n': n[d], **{k: round(v/n[d],2) for k,v in st[d].items()}} for d in D}
json.dump(res, open(out,'w',encoding='utf-8'), ensure_ascii=False, indent=0)
