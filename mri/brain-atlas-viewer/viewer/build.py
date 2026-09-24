#!/usr/bin/env python3
"""Build dist/viewer.html from config.json: one offline file with NiiVue and all volumes inlined."""

import base64
import gzip
import html
import json
import os
import re
import sys

import numpy as np
import nibabel as nib

import label_names

ROOT = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(ROOT, "dist", "viewer.html")
LAYOUTS = ("2", "3", "ax", "cor", "sag")  # the data-layout values in src/index.html
DISPLAY_DEFAULTS = {"quality": "normal", "adaptive_drag": True,
                    "show_existing_labels_only": True, "readable_names": True}


def read_text(*parts):
    with open(os.path.join(ROOT, *parts)) as f:
        return f.read()


def stem_of(path):
    """'seg.left.nii.gz' -> 'seg.left'; splitext alone would keep '.nii'."""
    b = os.path.basename(path)
    for e in (".nii.gz", ".mgz", ".mgh", ".nii"):
        if b.lower().endswith(e):
            return b[: -len(e)]
    return os.path.splitext(b)[0]


def labels_in(d):
    return set(np.unique(np.rint(d[d > 0])).astype(int).tolist())


def convert_lut(path):
    """NiiVue label colormap. The LUT alpha is ignored because FreeSurfer leaves it 0, which would hide every label."""
    rows = label_names.read_lut(path)
    if not rows:
        sys.exit("ERROR: no usable rows in %s" % path)
    if all(r[0] != 0 for r in rows):
        rows.insert(0, (0, "Unknown", 0, 0, 0))  # NiiVue indexes the colour table from 0
    clamp = lambda c: max(0, min(255, c))  # some LUTs hold values like 320; freeview clamps too
    return {
        "R": [clamp(r[2]) for r in rows],
        "G": [clamp(r[3]) for r in rows],
        "B": [clamp(r[4]) for r in rows],
        "A": [0 if r[0] == 0 else 255 for r in rows],
        "I": [r[0] for r in rows],
        "labels": [r[1] for r in rows],
    }


def prepare(path, is_label):
    """Crop to the data and store int16 to halve the GPU texture; returns (.mgz bytes, labels)."""
    img = nib.load(path)
    nz = np.argwhere(np.asanyarray(img.dataobj) > 0)
    if not nz.size:
        sys.exit("ERROR: %s is empty" % path)
    lo, hi = nz.min(0), nz.max(0) + 1
    sub = img.slicer[lo[0]:hi[0], lo[1]:hi[1], lo[2]:hi[2]]  # slicer shifts the affine, so alignment holds
    d = np.asanyarray(sub.dataobj)

    if np.nanmax(d) > 32767 or np.nanmin(d) < -32768:
        out = np.asarray(d, np.float32)
    else:
        out = np.rint(np.nan_to_num(d)).astype(np.int16)
    labels = labels_in(out) if is_label else set()
    if is_label and labels != labels_in(d):
        sys.exit("ERROR: int16 conversion changed labels in %s" % path)

    affine = sub.affine
    if is_label:
        # NiiVue's label shader clamps to the edge voxel, so a label on the crop edge would smear across the view.
        out = np.pad(out, 1)
        affine = affine @ np.array([[1, 0, 0, -1], [0, 1, 0, -1], [0, 0, 1, -1], [0, 0, 0, 1]])

    # Always .mgz because NiiVue picks its reader from the extension; mtime=0 keeps builds reproducible.
    data = gzip.compress(nib.MGHImage(out, affine).to_bytes(), mtime=0)
    print("  %-18s %s -> %s vox, %.1f MB" % (
        os.path.basename(path), "x".join(map(str, img.shape)), "x".join(map(str, out.shape)), len(data) / 1e6))
    return data, labels


def fill_template(template, values):
    """Single pass so placeholder-like text inside inserted code or data is never touched."""
    return re.sub(r"__([A-Z_]+)__", lambda m: values[m.group(1)], template)


def main():
    cfg = json.loads(read_text("config.json"))
    # Checked here because the viewer would silently fall back on a typo.
    layout = str(cfg.get("layout", 2))
    display = {**DISPLAY_DEFAULTS, **cfg.get("display", {})}
    if layout not in LAYOUTS:
        sys.exit("ERROR: layout must be one of %s" % ", ".join(LAYOUTS))
    if display["quality"] not in ("fast", "normal", "high"):
        sys.exit("ERROR: display.quality must be fast, normal or high")
    unknown = set(display) - set(DISPLAY_DEFAULTS)
    if unknown:
        sys.exit("ERROR: unknown display options: %s" % ", ".join(sorted(unknown)))

    vols = cfg["volumes"]
    if sum(v.get("role", "background") == "background" for v in vols) != 1:
        sys.exit("ERROR: config.json needs exactly one volume with role 'background'")
    vols.sort(key=lambda v: v.get("role", "background") != "background")  # NiiVue draws volumes[0] as the base

    lut_path = os.path.join(ROOT, cfg["lookup_table"])
    colormap = convert_lut(lut_path)
    names = label_names.readable_names(lut_path, os.path.join(ROOT, ".build"))
    print("  %d labels, %d readable names" % (len(colormap["I"]), len(names)))

    volumes = []
    for v in vols:
        path = os.path.join(ROOT, v["file"])
        is_label = v.get("role") == "segmentation"
        data, labels = prepare(path, is_label)
        missing = sorted(labels - set(colormap["I"]))
        if missing:
            print("    ! %d labels not in the lookup table: %s" % (len(missing), missing[:10]))
        volumes.append({
            "name": stem_of(path) + ".mgz",
            "title": v.get("title", stem_of(path)),
            "role": "segmentation" if is_label else "background",
            "opacity": v.get("opacity", 1.0),
            "base64": base64.b64encode(data).decode("ascii"),
        })

    config_js = json.dumps({
        "colormap": colormap,
        "label_names": [names.get(i) or label_names.plain(n) for i, n in zip(colormap["I"], colormap["labels"])],
        "volumes": volumes,
        "layout": layout,
        "display": display,
    }, separators=(",", ":")).replace("</", "<\\/")  # "</" in a string would end the <script> early

    niivue = read_text("vendor", "niivue.umd.js")
    if "</script" in niivue.lower():
        sys.exit("ERROR: vendored NiiVue contains a closing script tag; cannot inline safely")

    page = fill_template(read_text("src", "index.html"), {
        "TITLE": html.escape(cfg.get("title", "Brain Atlas Viewer")),
        "CSS": read_text("src", "style.css"),
        "NIIVUE_JS": niivue,
        # The licences require their notices to ship inside the distributed file.
        "LICENSES": html.escape(read_text("vendor", "THIRD_PARTY_LICENCES.txt")),
        "APP_JS": fill_template(read_text("src", "app.js"), {"CONFIG": config_js}),
    })

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w") as f:
        f.write(page)
    print("Wrote %s (%.1f MB)" % (os.path.relpath(OUT, ROOT), os.path.getsize(OUT) / 1e6))


if __name__ == "__main__":
    main()
