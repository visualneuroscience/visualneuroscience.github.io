// Source for dist/viewer.html; build.py injects CONFIG (colormap, label names, volumes, UI defaults).
(function () {
  "use strict";

  const CONFIG = __CONFIG__;

  const SEG_COLORMAP = CONFIG.colormap;
  const LABEL_NAMES = CONFIG.label_names;

  const ROLE_SEG = "segmentation";

  // NIfTI label intent makes NiiVue use its atlas shader, which looks up exact integers;
  // the generic shader merged small indices (white matter, 7) into one colour.
  const NIFTI_INTENT_LABEL = 1002;

  const VOLUMES = CONFIG.volumes;
  const LAYOUT = String(CONFIG.layout);
  const DISPLAY = CONFIG.display;

  const $ = (id) => document.getElementById(id);
  const canvas = $("gl");
  const overlay = $("overlay");
  const overlayMsg = $("overlayMsg");
  const statusEl = $("status");
  const sidePanel = $("sidePanel");
  const btnPanel = $("btnPanel");
  const layerList = $("layerList");
  const labelSection = $("labelSection");
  const labelHeading = $("labelHeading");
  const labelList = $("labelList");
  const labelCount = $("labelCount");
  const labelSearch = $("labelSearch");
  const chkAll = $("chkAll");
  const chkExisting = $("chkExisting");
  const selQuality = $("selQuality");
  const chkAdaptive = $("chkAdaptive");
  const infoCard = $("infoCard");
  const infoCoords = $("infoCoords");
  const btnInfoHide = $("btnInfoHide");
  const btnInfoShow = $("btnInfoShow");
  const chkReadable = $("chkReadable");
  const modeButtons = document.querySelectorAll("[data-mode]");
  const infoRows = $("infoRows");
  const renderCaption = $("renderCaption");
  const layoutButtons = document.querySelectorAll("[data-layout]");

  const nv = new niivue.Niivue({
    backColor: [0.03, 0.035, 0.047, 1],
    show3Dcrosshair: true,
    dragAndDropEnabled: false,
    isColorbar: false,
    // The 3D raycast costs per physical pixel, so CSS pixels are 4x cheaper on HiDPI
    // screens; antialiasing adds little to a volume render.
    forceDevicePixelRatio: -1,
    isAntiAlias: false,
  });

  // NVImage id -> { present: labels in the volume, hidden: labels the user unchecked }
  const segState = new Map();
  let selectedSegId = null;
  let hoveredRow = null;
  let lastHoverLabel = null;

  const setStatus = (msg, isErr) => {
    statusEl.textContent = msg || "";
    delete statusEl.dataset.kind;
    statusEl.classList.toggle("error", !!isErr);
  };

  const hideOverlay = () => { overlay.style.display = "none"; };
  const showOverlayError = (msg) => {
    overlay.style.display = "flex";
    overlay.classList.add("error");
    overlayMsg.textContent = msg;
  };

  function base64ToArrayBuffer(b64) {
    const bin = atob(b64);
    const bytes = new Uint8Array(bin.length);
    for (let i = 0; i < bin.length; i++) bytes[i] = bin.charCodeAt(i);
    return bytes.buffer;
  }

  const colorByIndex = new Map();
  const nameByIndex = new Map();
  const readableByIndex = new Map();
  for (let i = 0; i < SEG_COLORMAP.I.length; i++) {
    const idx = SEG_COLORMAP.I[i];
    const hex =
      "#" +
      [SEG_COLORMAP.R[i], SEG_COLORMAP.G[i], SEG_COLORMAP.B[i]]
        .map((c) => Math.max(0, Math.min(255, c | 0)).toString(16).padStart(2, "0"))
        .join("");
    colorByIndex.set(idx, hex);
    nameByIndex.set(idx, SEG_COLORMAP.labels[i]);
    readableByIndex.set(idx, LABEL_NAMES[i] || SEG_COLORMAP.labels[i]);
  }

  // One setting drives both the info card and the label list so they always agree.
  let useReadable = DISPLAY.readable_names;
  const labelName = (idx) =>
    (useReadable ? readableByIndex.get(idx) : nameByIndex.get(idx)) || "?";
  const otherLabelName = (idx) =>
    (useReadable ? nameByIndex.get(idx) : readableByIndex.get(idx)) || "";

  // Layout "2" matches freeview's -layout 2: three slices plus the 3D view.
  function applyLayout(kind) {
    layoutButtons.forEach((b) => b.classList.toggle("active", b.dataset.layout === kind));
    if (nv.clearCustomLayout) nv.clearCustomLayout();
    switch (kind) {
      case "3":
        nv.opts.multiplanarShowRender = niivue.SHOW_RENDER.NEVER;
        nv.setSliceType(nv.sliceTypeMultiplanar);
        nv.setMultiplanarLayout(niivue.MULTIPLANAR_TYPE.ROW);
        break;
      case "ax":
        nv.opts.multiplanarShowRender = niivue.SHOW_RENDER.NEVER;
        nv.setSliceType(nv.sliceTypeAxial);
        break;
      case "cor":
        nv.opts.multiplanarShowRender = niivue.SHOW_RENDER.NEVER;
        nv.setSliceType(nv.sliceTypeCoronal);
        break;
      case "sag":
        nv.opts.multiplanarShowRender = niivue.SHOW_RENDER.NEVER;
        nv.setSliceType(nv.sliceTypeSagittal);
        break;
      case "2":
      default:
        nv.opts.multiplanarShowRender = niivue.SHOW_RENDER.ALWAYS;
        nv.setSliceType(nv.sliceTypeMultiplanar);
        nv.setMultiplanarLayout(niivue.MULTIPLANAR_TYPE.GRID);
        break;
    }
    nv.drawScene();
    viewChanged();
  }

  layoutButtons.forEach((b) =>
    b.addEventListener("click", () => {
      try {
        applyLayout(b.dataset.layout);
      } catch (e) {
        console.error(e);
      }
    })
  );

  const PANEL_KEY = "brainViewer.panelOpen";

  function setPanelOpen(open, remember) {
    sidePanel.classList.toggle("collapsed", !open);
    btnPanel.setAttribute("aria-expanded", String(open));
    if (remember) {
      try { localStorage.setItem(PANEL_KEY, open ? "1" : "0"); } catch (e) { /* storage unavailable */ }
    }
    // NiiVue only listens for window resizes, not for its canvas changing size.
    try { nv.resizeListener(); } catch (e) { /* not attached yet */ }
    viewChanged();
  }

  btnPanel.addEventListener("click", () =>
    setPanelOpen(sidePanel.classList.contains("collapsed"), true)
  );

  function initialPanelOpen() {
    try {
      const v = localStorage.getItem(PANEL_KEY);
      if (v === "1" || v === "0") return v === "1";
    } catch (e) { /* storage unavailable */ }
    return window.innerWidth > 900;
  }

  // Raycast cost is pixels times depth, so the pixel ratio is the cheapest lever.
  function qualityRatio() {
    switch (selQuality.value) {
      case "fast": return 0.5;
      case "high": return window.devicePixelRatio || 1;
      default: return 1;
    }
  }

  function applyQuality(ratio) {
    try {
      nv.setHighResolutionCapable(ratio);
      viewChanged(); // hover mapping depends on the backing store size
    } catch (e) {
      console.error(e);
    }
  }

  selQuality.addEventListener("change", () => applyQuality(qualityRatio()));

  // Half resolution while dragging costs two canvas resizes instead of a heavy frame
  // per move. Pointer events cover touch; blur and cancel catch releases we never see.
  let dragging = false;
  canvas.addEventListener("pointerdown", () => {
    if (dragging || !chkAdaptive.checked) return;
    dragging = true;
    applyQuality(Math.max(0.35, qualityRatio() * 0.5));
  });
  const endDrag = () => {
    if (!dragging) return;
    dragging = false;
    applyQuality(qualityRatio());
  };
  window.addEventListener("pointerup", endDrag);
  window.addEventListener("pointercancel", endDrag);
  window.addEventListener("blur", endDrag);

  // Labels present in a volume, for freeview's "show existing labels only".
  function scanPresentLabels(vol) {
    const present = new Set();
    const img = vol.img;
    if (!img) return present;
    const hdr = vol.hdr || {};
    let slope = hdr.scl_slope;
    let inter = hdr.scl_inter;
    if (!isFinite(slope) || slope === 0) slope = 1;
    if (!isFinite(inter)) inter = 0;

    // A flat array beats Set.add() across tens of millions of voxels.
    let maxIdx = 0;
    for (let i = 0; i < SEG_COLORMAP.I.length; i++) {
      if (SEG_COLORMAP.I[i] > maxIdx) maxIdx = SEG_COLORMAP.I[i];
    }
    const seen = new Uint8Array(maxIdx + 1);
    const n = img.length;
    if (slope === 1 && inter === 0) {
      for (let i = 0; i < n; i++) {
        const v = img[i];
        if (v > 0 && v <= maxIdx) seen[v] = 1;
      }
    } else {
      for (let i = 0; i < n; i++) {
        const v = Math.round(img[i] * slope + inter);
        if (v > 0 && v <= maxIdx) seen[v] = 1;
      }
    }
    for (let v = 1; v <= maxIdx; v++) if (seen[v]) present.add(v);
    return present;
  }

  // NiiVue re-uploads colormapLabel.lut on every refresh, so editing alpha in place is enough.
  function writeLabelAlpha(vol) {
    const st = segState.get(vol.id);
    const lut = vol.colormapLabel;
    if (!st || !lut || !lut.lut) return false;
    const min = lut.min || 0;
    const max = lut.max || 0;
    for (let idx = min; idx <= max; idx++) {
      const a = (idx - min) * 4 + 3;
      if (a >= lut.lut.length) break;
      // Index 0 and LUT gaps (which NiiVue fills with black) stay transparent.
      lut.lut[a] = idx === 0 || st.hidden.has(idx) || !colorByIndex.has(idx) ? 0 : 255;
    }
    return true;
  }

  // NiiVue blends all overlays into one texture, so refreshing only the changed layer
  // would blend it over its own stale colours. Rebuilding from layer 1 starts a fresh
  // texture and skips the background, which makes it cheaper than updateGLVolume.
  let pendingRefresh = null;
  function applyLabelVisibility(vol) {
    if (!writeLabelAlpha(vol)) return;
    if (pendingRefresh) return;
    pendingRefresh = requestAnimationFrame(() => {
      pendingRefresh = null;
      try {
        for (let i = 1; i < nv.volumes.length; i++) nv.refreshLayers(nv.volumes[i], i);
        nv.drawScene();
      } catch (e) {
        console.error(e);
        nv.updateGLVolume();
      }
    });
  }

  // "All" acts on exactly these rows, so search then All toggles only the matches.
  function visibleLabelIndices(st) {
    const existingOnly = chkExisting.checked;
    const q = labelSearch.value.trim().toLowerCase();
    const out = [];
    for (let i = 0; i < SEG_COLORMAP.I.length; i++) {
      const idx = SEG_COLORMAP.I[i];
      if (idx === 0) continue; // freeview does not list the background either
      if (existingOnly && !st.present.has(idx)) continue;
      if (q && !matchesQuery(idx, q)) continue;
      out.push(idx);
    }
    return out;
  }

  function matchesQuery(idx, q) {
    if (/^\d+$/.test(q)) return String(idx).startsWith(q);
    return (
      readableByIndex.get(idx).toLowerCase().includes(q) ||
      (nameByIndex.get(idx) || "").toLowerCase().replace(/_/g, " ").includes(q)
    );
  }

  function renderLabelList() {
    labelList.innerHTML = "";
    hoveredRow = null;
    if (!selectedSegId) return;
    const vol = nv.volumes.find((v) => v.id === selectedSegId);
    const st = segState.get(selectedSegId);
    if (!vol || !st) return;

    const idxs = visibleLabelIndices(st);
    const frag = document.createDocumentFragment();

    idxs.forEach((idx) => {
      const row = document.createElement("label");
      row.className = "label-row";
      row.dataset.idx = String(idx);
      row.title = idx + ": " + otherLabelName(idx);

      const cb = document.createElement("input");
      cb.type = "checkbox";
      cb.checked = !st.hidden.has(idx);
      row.classList.toggle("off", !cb.checked);
      cb.addEventListener("change", () => {
        if (cb.checked) st.hidden.delete(idx);
        else st.hidden.add(idx);
        row.classList.toggle("off", !cb.checked);
        applyLabelVisibility(vol);
        syncAllCheckbox();
      });

      const sw = document.createElement("span");
      sw.className = "swatch";
      sw.style.background = colorByIndex.get(idx) || "#000";

      const nm = document.createElement("span");
      nm.className = "lname";
      nm.textContent = labelName(idx);

      const num = document.createElement("span");
      num.className = "lidx";
      num.textContent = idx;

      row.appendChild(cb);
      row.appendChild(sw);
      row.appendChild(nm);
      row.appendChild(num);
      frag.appendChild(row);
    });

    if (!idxs.length) {
      const empty = document.createElement("div");
      empty.className = "empty";
      empty.textContent = labelSearch.value.trim() ? "No labels found" : "No labels";
      frag.appendChild(empty);
    }

    labelList.appendChild(frag);
    labelCount.textContent =
      idxs.length + (idxs.length === 1 ? " label" : " labels") +
      (labelSearch.value.trim() ? " found" : "");
    syncAllCheckbox();
    highlightHoveredLabel(lastHoverLabel);
  }

  function syncAllCheckbox() {
    if (!selectedSegId) return;
    const st = segState.get(selectedSegId);
    if (!st) return;
    const idxs = visibleLabelIndices(st);
    const shown = idxs.filter((i) => !st.hidden.has(i)).length;
    chkAll.checked = shown === idxs.length && idxs.length > 0;
    chkAll.indeterminate = shown > 0 && shown < idxs.length;
  }

  chkAll.addEventListener("change", () => {
    if (!selectedSegId) return;
    const vol = nv.volumes.find((v) => v.id === selectedSegId);
    const st = segState.get(selectedSegId);
    if (!vol || !st) return;
    const idxs = visibleLabelIndices(st);
    if (chkAll.checked) idxs.forEach((i) => st.hidden.delete(i));
    else idxs.forEach((i) => st.hidden.add(i));
    applyLabelVisibility(vol);
    renderLabelList();
  });

  chkExisting.addEventListener("change", renderLabelList);
  labelSearch.addEventListener("input", renderLabelList);

  // Highlight only; scrolling the list would fight the user.
  function highlightHoveredLabel(idx) {
    lastHoverLabel = idx;
    const row = idx != null ? labelList.querySelector('.label-row[data-idx="' + idx + '"]') : null;
    if (row === hoveredRow) return;
    if (hoveredRow) hoveredRow.classList.remove("hovered");
    if (row) row.classList.add("hovered");
    hoveredRow = row;
  }

  function selectSeg(id) {
    selectedSegId = id;
    const vol = nv.volumes.find((v) => v.id === id);
    labelSection.hidden = !vol;
    if (vol) labelHeading.textContent = "Labels: " + vol.__title;
    document.querySelectorAll(".layer").forEach((el) => {
      el.classList.toggle("selected", el.dataset.id === id);
    });
    renderLabelList();
  }

  function renderLayers() {
    layerList.innerHTML = "";
    nv.volumes.forEach((vol, idx) => {
      const isSeg = vol.__role === ROLE_SEG;
      const row = document.createElement("div");
      row.className = "layer" + (isSeg ? "" : " nonseg");
      row.dataset.id = vol.id;

      const top = document.createElement("div");
      top.className = "layer-top";

      if (isSeg) {
        const sw = document.createElement("span");
        sw.className = "swatch";
        sw.style.background = "linear-gradient(135deg,#d4b435,#c9576f,#4f9d69)";
        top.appendChild(sw);
      }

      const name = document.createElement("span");
      name.className = "layer-name";
      name.textContent = vol.__title;
      top.appendChild(name);

      const kind = document.createElement("span");
      kind.className = "layer-kind";
      kind.textContent = isSeg ? "labels" : "image";
      top.appendChild(kind);

      const pct = document.createElement("span");
      pct.className = "layer-pct";
      const initial = Math.round((vol.opacity != null ? vol.opacity : 1) * 100);
      pct.textContent = initial + "%";
      top.appendChild(pct);

      row.appendChild(top);

      const slider = document.createElement("input");
      slider.type = "range";
      slider.min = "0";
      slider.max = "100";
      slider.value = String(initial);
      slider.setAttribute("aria-label", vol.__title + " opacity");
      row.appendChild(slider);

      let hint = null;
      if (isSeg) {
        hint = document.createElement("p");
        hint.className = "layer-hint";
        hint.textContent = "Hidden. Move the slider to show the labels.";
        hint.hidden = initial > 0;
        row.appendChild(hint);
      }

      slider.addEventListener("input", () => {
        nv.setOpacity(idx, Number(slider.value) / 100);
        pct.textContent = slider.value + "%";
        if (hint) hint.hidden = Number(slider.value) > 0;
        if (isSeg && Number(slider.value) > 0 && statusEl.dataset.kind === "labels-hidden") setStatus("");
        if (isSeg && selectedSegId !== vol.id) selectSeg(vol.id);
      });
      slider.addEventListener("click", (e) => e.stopPropagation());

      if (isSeg) row.addEventListener("click", () => selectSeg(vol.id));

      layerList.appendChild(row);
    });
  }

  // Info card reads out under the mouse or at the crosshair; it never switches by itself.
  let infoModeState = "mouse";

  function setInfoMode(mode) {
    infoModeState = mode;
    modeButtons.forEach((b) => {
      const on = b.dataset.mode === mode;
      b.classList.toggle("active", on);
      b.setAttribute("aria-checked", String(on));
    });
    scheduleInfo();
  }
  modeButtons.forEach((b) => b.addEventListener("click", () => setInfoMode(b.dataset.mode)));

  function setInfoVisible(show) {
    infoCard.hidden = !show;
    btnInfoShow.hidden = show;
    if (show) scheduleInfo();
    else highlightHoveredLabel(null);
  }
  btnInfoHide.addEventListener("click", () => setInfoVisible(false));
  btnInfoShow.addEventListener("click", () => setInfoVisible(true));

  const licenseDialog = $("licenseDialog");
  $("btnLicenses").addEventListener("click", () => licenseDialog.showModal());
  $("btnLicensesClose").addEventListener("click", () => licenseDialog.close());
  licenseDialog.addEventListener("click", (e) => {
    if (e.target === licenseDialog) licenseDialog.close(); // backdrop click
  });

  chkReadable.checked = useReadable;
  chkReadable.addEventListener("change", () => {
    useReadable = chkReadable.checked;
    renderLabelList();
    scheduleInfo();
  });

  const EMPTY_INFO = { text: "", num: "", kind: "none", color: null, idx: null };

  function labelFor(vol, value) {
    if (!isFinite(value)) return { text: "Outside", num: "", kind: "none", color: null, idx: null };
    if (vol.__role === ROLE_SEG) {
      const v = Math.round(value);
      if (v === 0) return { text: "No label", num: "", kind: "none", color: null, idx: null };
      if (colorByIndex.has(v)) {
        // LUT names have no spaces, so allow wrapping after "_" and "-".
        const text = labelName(v).replace(/([_-])/g, "$1\u200b");
        return { text, num: String(v), kind: "label", color: colorByIndex.get(v), idx: v };
      }
      return { text: "Unknown label", num: String(v), kind: "none", color: null, idx: null };
    }
    return { text: value.toFixed(1), num: "", kind: "value", color: null, idx: null };
  }

  // Rows are reused so hovering does not rebuild the DOM on every mouse event.
  const infoWidgets = [];

  function buildInfoRows() {
    infoRows.innerHTML = "";
    infoWidgets.length = 0;
    nv.volumes.forEach((vol) => {
      const row = document.createElement("div");
      row.className = "info-row";

      const nm = document.createElement("span");
      nm.className = "iname";
      nm.textContent = vol.__title;

      const val = document.createElement("span");
      val.className = "ival";
      const sw = document.createElement("span");
      sw.className = "swatch";
      sw.hidden = true;
      const txt = document.createElement("span");
      txt.className = "vtext";
      const num = document.createElement("span");
      num.className = "vnum mono";
      val.appendChild(sw);
      val.appendChild(txt);
      val.appendChild(num);

      row.appendChild(nm);
      row.appendChild(val);
      infoRows.appendChild(row);
      infoWidgets.push({ vol, val, sw, txt, num });
    });
  }

  function showInfo(w, info) {
    if (w.txt.textContent !== info.text) w.txt.textContent = info.text;
    w.num.textContent = info.num;
    w.val.className = "ival " + info.kind;
    w.sw.hidden = !info.color;
    if (info.color) w.sw.style.background = info.color;
  }

  // Mouse, wheel and crosshair events coalesce into one update per frame.
  let hoverEvent = null;
  let infoQueued = false;
  let canvasRect = null;

  function scheduleInfo() {
    if (infoQueued) return;
    infoQueued = true;
    requestAnimationFrame(updateInfo);
  }

  function viewChanged() {
    canvasRect = null;
    requestAnimationFrame(() => {
      positionRenderCaption();
      scheduleInfo();
    });
  }
  window.addEventListener("resize", viewChanged);
  window.addEventListener("scroll", () => { canvasRect = null; }, true);

  // Texture fraction under the mouse, or null when not over a 2D slice.
  function sliceFracUnderMouse() {
    const e = hoverEvent;
    if (!e || !nv.screenSlices || !nv.screenSlices.length) return null;
    if (!canvasRect) canvasRect = canvas.getBoundingClientRect();
    const rect = canvasRect;
    if (!rect.width || !rect.height) return null;

    const dpr = nv.gl.canvas.width / rect.width;
    const x = (e.clientX - rect.left) * dpr;
    const y = (e.clientY - rect.top) * dpr;

    const tileIdx = nv.tileIndex(x, y);
    if (tileIdx < 0) return null;
    const tile = nv.screenSlices[tileIdx];
    if (!tile || tile.axCorSag === niivue.SLICE_TYPE.RENDER) return null;

    const frac = nv.screenXY2TextureFrac(x, y, tileIdx, true);
    if (!frac || frac[0] < 0) return null;
    return frac;
  }

  function updateInfo() {
    infoQueued = false;
    if (!nv.volumes.length || infoCard.hidden) return;
    if (infoWidgets.length !== nv.volumes.length) buildInfoRows();

    const frac = infoModeState === "mouse" ? sliceFracUnderMouse() : nv.scene.crosshairPos;
    if (!frac) {
      infoCoords.textContent = "Point at a slice";
      infoCoords.classList.add("prompt");
      infoWidgets.forEach((w) => showInfo(w, EMPTY_INFO));
      highlightHoveredLabel(null);
      return;
    }

    const mm = nv.frac2mm(frac, 0, true);
    infoCoords.classList.remove("prompt");
    infoCoords.textContent =
      mm[0].toFixed(1) + ", " + mm[1].toFixed(1) + ", " + mm[2].toFixed(1) + " mm";

    let selectedLabel = null;
    for (const w of infoWidgets) {
      const vox = w.vol.mm2vox(mm);
      const raw = w.vol.getValue(vox[0], vox[1], vox[2], w.vol.frame4D);
      const info = labelFor(w.vol, raw);
      showInfo(w, info);
      if (w.vol.id === selectedSegId) selectedLabel = info.idx;
    }
    highlightHoveredLabel(selectedLabel);
  }

  canvas.addEventListener("mousemove", (e) => {
    hoverEvent = e;
    if (infoModeState === "mouse") scheduleInfo();
  });
  canvas.addEventListener("mouseleave", () => {
    hoverEvent = null;
    if (infoModeState === "mouse") scheduleInfo();
  });
  // Scrolling changes the tissue under a still cursor; NiiVue's earlier listener moves the slice first.
  canvas.addEventListener("wheel", scheduleInfo, { passive: true });
  nv.onLocationChange = scheduleInfo;

  function positionRenderCaption() {
    const tile = (nv.screenSlices || []).find(
      (t) => t.axCorSag === niivue.SLICE_TYPE.RENDER && t.leftTopWidthHeight
    );
    if (!tile || !nv.gl) {
      renderCaption.hidden = true;
      return;
    }
    const rect = canvas.getBoundingClientRect();
    const scale = rect.width / nv.gl.canvas.width;
    const [l, t] = tile.leftTopWidthHeight;
    renderCaption.style.left = Math.round(l * scale + 12) + "px";
    renderCaption.style.top = Math.round(t * scale + 12) + "px";
    renderCaption.hidden = false;
  }

  async function boot() {
    overlayMsg.textContent = "Starting…";
    await nv.attachToCanvas(canvas);

    let loaded = 0;
    const failures = [];

    for (const spec of VOLUMES) {
      overlayMsg.textContent = "Loading " + spec.name + "…";
      // Yield so the progress text repaints between volumes.
      await new Promise((r) => setTimeout(r, 0));
      try {
        const buf = base64ToArrayBuffer(spec.base64);
        spec.base64 = null; // frees the string once decoded
        await nv.loadFromArrayBuffer(buf, spec.name);
        const vol = nv.volumes[nv.volumes.length - 1];
        vol.__role = spec.role;
        vol.__title = spec.title;
        // setOpacity would re-upload all volumes; boot ends with one updateGLVolume anyway.
        vol.opacity = spec.opacity;

        if (spec.role === ROLE_SEG) {
          vol.hdr.intent_code = NIFTI_INTENT_LABEL;
          // Fresh copy per volume because makeLabelLut mutates its input.
          vol.setColormapLabel(JSON.parse(JSON.stringify(SEG_COLORMAP)));
          overlayMsg.textContent = "Reading labels in " + spec.name + "…";
          await new Promise((r) => setTimeout(r, 0));
          segState.set(vol.id, { present: scanPresentLabels(vol), hidden: new Set() });
        }
        loaded++;
      } catch (err) {
        console.error("Failed to load " + spec.name, err);
        failures.push(spec.name + ": " + (err && err.message ? err.message : err));
      }
    }

    if (loaded === 0) {
      showOverlayError("No images could be loaded.\n" + failures.join("\n"));
      return;
    }

    // A UI problem must never hide a successful load.
    try {
      nv.updateGLVolume();
      applyLayout(LAYOUT);
      renderLayers();
      buildInfoRows();
      const firstSeg = nv.volumes.find((v) => v.__role === ROLE_SEG);
      if (firstSeg) selectSeg(firstSeg.id);
      scheduleInfo();
    } catch (err) {
      console.error("UI setup problem", err);
    }

    hideOverlay();

    if (failures.length) {
      setStatus("Loaded " + loaded + " of " + VOLUMES.length + " images. " + failures.join(" | "), true);
    } else if (nv.volumes.some((v) => v.__role === ROLE_SEG && !(v.opacity > 0))) {
      setStatus("The labels are hidden. Move a label slider in Settings to show them.");
      statusEl.dataset.kind = "labels-hidden";
    }
  }

  selQuality.value = DISPLAY.quality;
  chkAdaptive.checked = DISPLAY.adaptive_drag;
  chkExisting.checked = DISPLAY.show_existing_labels_only;
  applyQuality(qualityRatio());
  setPanelOpen(initialPanelOpen(), false);

  boot().catch((err) => {
    console.error(err);
    showOverlayError((err && err.message ? err.message : String(err)));
  });
})();
