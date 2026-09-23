"""Readable names for LUT labels from published sources: Desikan et al. 2006 (NeuroImage 31:968-980)
for cortex, and the Allen Human Brain Atlas ontology (structure graph 16) that the NextBrain LUT names come from."""

import hashlib
import json
import os
import re
import urllib.request

ALLEN_URL = ("https://api.brain-map.org/api/v2/data/Structure/query.json"
             "?criteria=%5Bgraph_id%24eq16%5D&num_rows=all")

# Spelled as printed in the paper; its hyphens and dashes become spaces.
DK_NAMES = {
    "bankssts": "Banks of the superior temporal sulcus",
    "caudalanteriorcingulate": "Caudal anterior cingulate cortex",
    "caudalmiddlefrontal": "Caudal middle frontal gyrus",
    "corpuscallosum": "Corpus callosum",
    "cuneus": "Cuneus cortex",
    "entorhinal": "Entorhinal cortex",
    "fusiform": "Fusiform gyrus",
    "inferiorparietal": "Inferior parietal cortex",
    "inferiortemporal": "Inferior temporal gyrus",
    "isthmuscingulate": "Isthmus cingulate cortex",
    "lateraloccipital": "Lateral occipital cortex",
    "lateralorbitofrontal": "Lateral orbital frontal cortex",
    "lingual": "Lingual gyrus",
    "medialorbitofrontal": "Medial orbital frontal cortex",
    "middletemporal": "Middle temporal gyrus",
    "parahippocampal": "Parahippocampal gyrus",
    "paracentral": "Paracentral lobule",
    "parsopercularis": "Pars opercularis",
    "parsorbitalis": "Pars orbitalis",
    "parstriangularis": "Pars triangularis",
    "pericalcarine": "Pericalcarine cortex",
    "postcentral": "Postcentral gyrus",
    "posteriorcingulate": "Posterior cingulate cortex",
    "precentral": "Precentral gyrus",
    "precuneus": "Precuneus cortex",
    "rostralanteriorcingulate": "Rostral anterior cingulate cortex",
    "rostralmiddlefrontal": "Rostral middle frontal gyrus",
    "superiorfrontal": "Superior frontal gyrus",
    "superiorparietal": "Superior parietal cortex",
    "superiortemporal": "Superior temporal gyrus",
    "supramarginal": "Supramarginal gyrus",
    "frontalpole": "Frontal pole",
    "temporalpole": "Temporal pole",
    "transversetemporal": "Transverse temporal cortex",
}
# Not a region in Desikan 2006; FreeSurfer's aparc added it later.
FREESURFER_ONLY = {"insula": "Insula"}

# Written out from the ontology itself; CA1..CA4 stay as they are standard field names.
EXPAND_ACRONYMS = ["HTH", "VA", "VL", "VLC", "VPM", "MD", "STH", "CoA", "PVA"]

# Typos in the Allen names themselves.
SPELLING = {
    "densocelllular": "densocellular",
    "dicussation": "decussation",
    "habenuno": "habenulo",
}


def read_lut(path):
    """FreeSurfer ASCII LUT rows as (index, name, r, g, b); comments and malformed lines are skipped."""
    rows = []
    with open(path, errors="ignore") as f:
        for line in f:
            p = line.split()
            if len(p) < 5 or p[0].startswith("#"):
                continue
            try:
                rows.append((int(p[0]), p[1], int(p[2]), int(p[3]), int(p[4])))
            except ValueError:
                pass
    return rows


def plain(lut_name):
    """Fallback for labels without a published name."""
    s = lut_name.replace("_", " ").strip()
    return s[:1].upper() + s[1:]


def norm(s):
    """Match LUT names to Allen names, which differ in case, underscores and commas."""
    return re.sub(r"\s+", " ", re.sub(r"[_,]", " ", s.lower())).strip()


def load_allen(cache_dir):
    """Structure graph 16, downloaded once into cache_dir."""
    path = os.path.join(cache_dir, "allen_graph16.json")
    if not os.path.exists(path):
        print("  downloading the Allen ontology")
        with urllib.request.urlopen(ALLEN_URL, timeout=120) as r:
            data = json.load(r)
        if not data.get("success"):
            raise ValueError("Allen API request failed")
        os.makedirs(cache_dir, exist_ok=True)
        with open(path, "w") as f:
            json.dump(data, f)
    with open(path) as f:
        return json.load(f)["msg"]


def build_names(lut_rows, allen):
    by_name = {}
    for r in allen:
        by_name.setdefault(norm(r["name"]), r["name"])
    acronyms = {}
    for ac in EXPAND_ACRONYMS:
        hits = [r["name"] for r in allen if r.get("acronym") == ac]
        if len(hits) != 1:
            raise ValueError("acronym %s is ambiguous or missing in the ontology" % ac)
        acronyms[ac] = hits[0]
    pattern = re.compile(r"\b(%s)\b" % "|".join(map(re.escape, acronyms)))

    def expand(m):
        # An acronym's own name can hold another one (VLC = "caudal division of VL").
        full = pattern.sub(lambda n: acronyms[n.group(0)], acronyms[m.group(0)])
        return "%s (%s)" % (full, m.group(0))

    names = {}
    for idx, lut_name, *_ in lut_rows:
        m = re.match(r"^ctx-[lr]h-(.+)$", lut_name)  # hemisphere is dropped; the layer title says it
        if idx == 0:
            names[idx] = "Unknown"
        elif m and m.group(1) in DK_NAMES:
            names[idx] = DK_NAMES[m.group(1)]
        elif m and m.group(1) in FREESURFER_ONLY:
            names[idx] = FREESURFER_ONLY[m.group(1)]
        elif norm(lut_name) in by_name:
            s = re.sub(r"\s+", " ", by_name[norm(lut_name)]).strip()
            for wrong, right in SPELLING.items():
                s = s.replace(wrong, right)
            s = pattern.sub(expand, s)
            names[idx] = s[:1].upper() + s[1:]
    return names


def readable_names(lut_path, cache_dir):
    """{index: name}, cached per LUT; {} when the ontology is unreachable so the build can fall back."""
    h = hashlib.sha1()
    for p in (lut_path, __file__):  # editing the rules here invalidates old caches
        with open(p, "rb") as f:
            h.update(f.read())
    cache = os.path.join(cache_dir, "label_names.%s.json" % h.hexdigest()[:8])
    if not os.path.exists(cache):
        try:
            names = build_names(read_lut(lut_path), load_allen(cache_dir))
        except (OSError, ValueError, KeyError) as e:
            print("  ! readable names unavailable (%s); using LUT names" % e)
            return {}
        with open(cache, "w") as f:
            json.dump(names, f, indent=0)
    with open(cache) as f:
        return {int(k): v for k, v in json.load(f).items()}
