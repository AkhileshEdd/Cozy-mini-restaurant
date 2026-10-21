# Google Play store listing

Copy these into **Play Console → Grow → Store presence → Main store listing**.

## App name (30 characters max)

Cozy Mini Restaurant

## Short description (80 characters max)

Cook, serve and decorate a tiny pastel café run by Chef Mochi the cat.

## Full description (4000 characters max)

Welcome to Cozy Mini Restaurant, a tiny pastel café run by Chef Mochi, a ginger cat with a big heart.

Cook lattes, strawberry cakes, fluffy pancakes, pumpkin soup and berry sundaes for a cast of adorable animal regulars. Serve them before their patience runs out, collect their tips and grow your little café, one cozy day at a time.

COOK AND SERVE
• Simple one-finger taps: cook at a station, carry dishes on your tray, serve hungry guests
• Fast service means bigger tips and better reviews
• Combo orders, rush hours and rainy days keep every day a little different

MEET THE REGULARS
• Pip the bunny has a sweet tooth, Bruno the bear always orders two dishes, Bao the panda is a food critic...
• Make friends, earn hearts and unlock gifts from each regular
• Fill your collection book with recipes, regulars and stickers

MAKE IT YOURS
• Unlock new recipes, stations and tables
• Redecorate: wallpapers, floors, plants, lamps and bookcases, placed wherever you like
• Dress Chef Mochi in cute outfits
• Hire helpers: Pepper the penguin waiter and Nibbles the hamster busser

RELAX
• Seasons change the café, with snow, petals and falling leaves
• Your café keeps earning takeaway tips while you're away
• No timers, no energy, no pressure, just cozy cooking
• Progress is saved automatically and backed up to your Google account

Cozy Mini Restaurant is free to play with ads. A one-time "Remove ads" purchase turns off ads between days and adds a golden chef outfit.

## Category and tags

- App category: **Game → Casual** (or Simulation)
- Tags: Cooking, Restaurant, Cute, Casual, Offline, Decoration

## Graphics (in this folder)

| Asset | File | Size |
| --- | --- | --- |
| App icon | `icon_512.png` | 512 × 512 |
| Feature graphic | `feature_graphic.png` | 1024 × 500 |
| Phone screenshots | `screenshots/phone_*.png` | 1080 × 1920 |

To regenerate them after art or UI changes:

```sh
xvfb-run -s "-screen 0 1200x2000x24" godot --rendering-driver opengl3 --path . \
  --resolution 1080x1920 res://tools/godot/store_shots.tscn -- --out=docs/store/screenshots
python3 tools/store_graphics.py
```
