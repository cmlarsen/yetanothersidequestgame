# Import provenance

Imported 2026-07-17 from the Claude Design project
`5499a060-1176-4c69-bcce-cb74ae56e437`
(https://claude.ai/design/p/5499a060-1176-4c69-bcce-cb74ae56e437), directory
`design_handoff_yas_v1/`, via the DesignSync API.

Deviations from the source bundle:

- `assets/_facesheet.png` is **omitted**: it exceeds the API's 256 KiB
  per-file read cap and arrived truncated. It is only a contact sheet of the
  8 individual `face-*.png` files, all of which imported complete
  (IEND-verified).
- The 8 face PNGs are additionally copied to `game/assets/ui/faces/` for use
  as in-app stand-ins until live KayKit renders exist.

To view the design boards: open the `.dc.html` files in a browser from this
directory (they need `support.js`, `ios-frame.jsx`, and `assets/` as siblings,
plus network access for Google Fonts).
