#!/usr/bin/env python3
"""Gera data/crops/<id>.tres a partir de tools/crops_table.py."""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from crops_table import CROPS  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "data", "crops")
FIELDS = ["id", "name", "description", "category", "seed_item", "seed_name", "seed_price", "produce_item",
          "produce_name", "sell_price", "produce_icon_hd", "stage_days", "seasons", "season_end",
          "water_min", "water_max", "drought_tolerance", "temp_min", "temp_max", "fragile", "harvest_type", "regrow_days",
          "max_harvests", "yield_min", "yield_max", "extra_seed_chance", "rarity", "sprite_height"]


def val(v):
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, str):
        return '"%s"' % v.replace('"', '\\"')
    if isinstance(v, list):
        if all(isinstance(x, int) for x in v):
            return "PackedInt32Array(%s)" % ", ".join(str(x) for x in v)
        return "PackedStringArray(%s)" % ", ".join('"%s"' % x for x in v)
    return str(v)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for c in CROPS:
        d = dict(c)
        if "hd" in d and "produce_item" not in d:
            d["produce_icon_hd"] = d["hd"]
        lines = ['[gd_resource type="Resource" script_class="CropData" load_steps=2 format=3]', "",
                 '[ext_resource type="Script" path="res://scripts/data/crop_data.gd" id="1"]', "",
                 "[resource]", 'script = ExtResource("1")']
        for f in FIELDS:
            if f in d:
                lines.append("%s = %s" % (f, val(d[f])))
        open(os.path.join(OUT, d["id"] + ".tres"), "w").write("\n".join(lines) + "\n")
    print(len(CROPS), "plantas em", OUT)
