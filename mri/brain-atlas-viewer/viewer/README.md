# Brain Atlas Viewer

Builds `dist/viewer.html`: one offline file with the brain volumes, label colours and [NiiVue](https://github.com/niivue/niivue) 0.69.0 inlined.

```bash
pip install -r requirements.txt
python3 build.py
```

The first build downloads the Allen ontology once for readable label names (cached in `.build/`). Without it the viewer falls back to lookup-table names.

## config.json

- `title`: page title.
- `lookup_table`: FreeSurfer ASCII LUT (`index name R G B A`).
- `volumes[]`: `file`, plus optional `role` (`background` or `segmentation`; exactly one background), `title` (default: file name) and `opacity` (default 1).
- `layout`: starting view; `2` (2×2 with 3D), `3` (1×3), `ax`, `cor` or `sag`.
- `display.quality`: `fast`, `normal` or `high`.
- `display.adaptive_drag`: lower resolution while dragging.
- `display.show_existing_labels_only`: list only labels present in the layer.
- `display.readable_names`: readable names instead of lookup-table names.

`layout` and every `display` option are optional and default to the values in the shipped `config.json`.

## Licences

NiiVue and the code it bundles require their notices to ship with the file, so `build.py` embeds `vendor/THIRD_PARTY_LICENCES.txt` behind the page's *Licences* link.
