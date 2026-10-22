# Video ad

`cozy-mini-restaurant-ad.mp4`: a 27-second vertical (1080 × 1920, 30 fps, H.264 + AAC) motion-graphics ad, made from real gameplay and the game's own 3D models, music and sound effects. `cozy-mini-restaurant-ad_poster.png` is its end card, for a thumbnail.

| Time | Scene |
| --- | --- |
| 0.0–2.6 s | "Run your own tiny café!": Chef Mochi and the five dishes pop in |
| 2.6–7.6 s | A busy café: "Cook yummy treats", then "Serve cute guests" |
| 7.6–10.8 s | Close on Chef Mochi: "Collect big tips!" with flying coins |
| 10.8–14.0 s | "Meet the cutest regulars": Pip, Bruno, Lily, Sunny and Bao |
| 14.0–17.9 s | "Decorate your way": wallpapers and floors change |
| 17.9–21.0 s | "Dress up Chef Mochi": outfit changes |
| 21.0–23.2 s | "Hire helpers & grow": Pepper and Nibbles at work |
| 23.2–27.0 s | End card: logo, "Play free now" button, the cast |

It fits Google Ads app campaigns (portrait video, 10–30 s), YouTube Shorts, Instagram Reels and TikTok. Upload it to YouTube (unlisted is fine) to use it in a Google Ads app campaign, and add it as the promo video in the Play Store listing if you like.

## Making it again

Everything is generated from the project, so the ad can be re-made after art or gameplay changes. It needs a display (or `xvfb-run`), Pillow, numpy and an ffmpeg with libx264 (`pip install numpy imageio-ffmpeg` provides one).

```sh
mkdir -p build/ad
# 1. Portraits of the cast and dishes (transparent PNGs)
godot --rendering-driver opengl3 --path . res://tools/godot/ad_portraits.tscn -- --out=build/ad/portraits

# 2. Gameplay footage with Movie Maker. Movie Maker records at the window size,
#    so override the desktop window size for the run.
printf '[display]\nwindow/size/window_width_override=1080\nwindow/size/window_height_override=1920\n[editor]\nmovie_writer/mjpeg_quality=0.95\n' > override.cfg
godot --rendering-driver opengl3 --path . --fixed-fps 30 --write-movie build/ad/capture.avi \
  res://tools/godot/ad_capture.tscn -- --out=build/ad
rm override.cfg

# 3. Cut, animate and mix
python3 tools/ad_video.py build/ad docs/marketing/cozy-mini-restaurant-ad.mp4
```

`tools/godot/ad_capture.gd` stages a well-upgraded café and scripts the shots (camera moves, style and outfit changes). `tools/ad_video.py` holds the timeline, captions, transitions and the sound mix. Both overwrite and then reset the local save, like the smoke test.
