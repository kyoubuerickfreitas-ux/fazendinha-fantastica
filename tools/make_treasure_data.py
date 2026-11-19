#!/usr/bin/env python3
"""Gera data/treasures/<id>.tres a partir de tools/treasure_table.py."""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from treasure_table import TREASURES  # noqa: E402
from make_fish_data import arr, q  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "data", "treasures")

if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for t in TREASURES:
        L = ['[gd_resource type="Resource" script_class="TreasureData" load_steps=2 format=3]', "",
             '[ext_resource type="Script" path="res://scripts/data/treasure_data.gd" id="1"]', "", "[resource]",
             'script = ExtResource("1")', "id = " + q(t["id"]), "name = " + q(t["name"]),
             "description = " + q(t.get("description", "")), "kind = " + q(t["kind"]),
             "rarity = %d" % t["rarity"], "weight = %s" % float(t["weight"]),
             "waters = " + arr(t.get("waters", ["lake", "river", "pond"])), "depth = " + q(t.get("depth", "any")),
             "min_level = %d" % t.get("min_level", 1), "unique = %s" % ("true" if t.get("unique") else "false"),
             "sell = %d" % t.get("sell", 0), "gives = " + q(t.get("gives", "")), "gives_qty = %d" % t.get("gives_qty", 1)]
        open(os.path.join(OUT, t["id"] + ".tres"), "w").write("\n".join(L) + "\n")
    print(len(TREASURES), "tesouros em", OUT)
