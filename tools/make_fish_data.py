#!/usr/bin/env python3
"""Gera data/fish/<id>.tres a partir de tools/fish_table.py."""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from fish_table import FISH  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "data", "fish")


def arr(v):
    return "PackedStringArray(%s)" % ", ".join('"%s"' % x for x in v)


def q(s):
    return '"%s"' % s.replace('"', '\\"')


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for f in FISH:
        L = ['[gd_resource type="Resource" script_class="FishData" load_steps=2 format=3]', "",
             '[ext_resource type="Script" path="res://scripts/data/fish_data.gd" id="1"]', "", "[resource]",
             'script = ExtResource("1")', "id = " + q(f["id"]), "name = " + q(f["name"]),
             "description = " + q(f.get("description", "")), "lore = " + q(f.get("lore", "")),
             "rarity = %d" % f["rarity"], "waters = " + arr(f.get("waters", ["lake"])),
             "depth = " + q(f.get("depth", "any")), "regions = " + arr(f.get("regions", ["farm"])),
             "seasons = " + arr(f.get("seasons", [])), "times = " + arr(f.get("times", [])),
             "weathers = " + arr(f.get("weathers", [])), "favored_weathers = " + arr(f.get("favored", [])),
             "baits = " + arr(f.get("baits", [])), "min_level = %d" % f.get("min_level", 1),
             "difficulty = %s" % f.get("difficulty", 0.0), "special = " + q(f.get("special", "")),
             "hint = " + q(f.get("hint", "")),
             "size_min = %s" % float(f["size"][0]), "size_max = %s" % float(f["size"][1]),
             "weight_min = %s" % float(f["weight"][0]), "weight_max = %s" % float(f["weight"][1])]
        if "sell" in f:
            L.append("sell = %d" % f["sell"])
        if "icon" in f:
            L.append("icon = " + q(f["icon"]))
        if "uses" in f:
            L.append("uses = " + arr(f["uses"]))
        open(os.path.join(OUT, f["id"] + ".tres"), "w").write("\n".join(L) + "\n")
    print(len(FISH), "peixes em", OUT)
