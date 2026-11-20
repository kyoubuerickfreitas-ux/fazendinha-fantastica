#!/usr/bin/env python3
"""Gera data/npcs/<id>.tres a partir de tools/npc_table.py."""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from npc_table import NPCS  # noqa: E402
from make_fish_data import arr, q  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "data", "npcs")


def gd(v):
    """valor Python -> literal do Godot (Dictionary/Array/String/int)"""
    return json.dumps(v, ensure_ascii=False)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for n in NPCS:
        rewards = {str(k): {"item": v[0], "qty": v[1], "line": v[2]} for k, v in n["rewards"].items()}
        L = ['[gd_resource type="Resource" script_class="NPCData" load_steps=2 format=3]', "",
             '[ext_resource type="Script" path="res://scripts/data/npc_data.gd" id="1"]', "", "[resource]",
             'script = ExtResource("1")', "id = " + q(n["id"]), "name = " + q(n["name"]), "role = " + q(n["role"]),
             "description = " + q(n["description"]),
             "sheet = " + q("res://assets/sprites/npc_%s.png" % n["id"]),
             "home = Vector2i(%d, %d)" % n["home"], "wander = %d" % n["wander"], "scale = %s" % n.get("scale", 1.0),
             "birthday_season = " + q(n["birthday"][0]), "birthday_day = %d" % n["birthday"][1],
             "loves = " + arr(n["loves"]), "likes = " + arr(n["likes"]), "dislikes = " + arr(n["dislikes"]),
             "lines = " + gd(n["lines"]), "rewards = " + gd(rewards)]
        open(os.path.join(OUT, n["id"] + ".tres"), "w").write("\n".join(L) + "\n")
    print(len(NPCS), "moradores em", OUT)
