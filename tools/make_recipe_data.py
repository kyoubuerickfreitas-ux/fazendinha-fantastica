#!/usr/bin/env python3
"""Gera data/recipes/<id>.tres a partir de tools/recipe_table.py."""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from recipe_table import RECIPES  # noqa: E402
from make_fish_data import q  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "data", "recipes")

if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for r in RECIPES:
        ing = "{" + ", ".join('"%s": %d' % (k, v) for k, v in r["ing"].items()) + "}"
        L = ['[gd_resource type="Resource" script_class="RecipeData" load_steps=2 format=3]', "",
             '[ext_resource type="Script" path="res://scripts/data/recipe_data.gd" id="1"]', "", "[resource]",
             'script = ExtResource("1")', "id = " + q(r["id"]), "name = " + q(r["name"]),
             "description = " + q(r.get("description", "")), "ingredients = " + ing,
             "energy = %d" % r["energy"], "health = %d" % r.get("health", 0), "buff = " + q(r.get("buff", "")),
             "buff_minutes = %d" % r.get("buff_minutes", 0), "sell = %d" % r["sell"],
             "unlock = " + q(r.get("unlock", "start")), "shop_season = " + q(r.get("shop_season", "")),
             "price = %d" % r.get("price", 150), "icon = " + q("res://assets/sprites/food/%s.png" % r["id"])]
        open(os.path.join(OUT, r["id"] + ".tres"), "w").write("\n".join(L) + "\n")
    print(len(RECIPES), "receitas em", OUT)
