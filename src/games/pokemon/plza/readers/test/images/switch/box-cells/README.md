# Box cell captures, redacted

The fork's CommandLineTests BoxCellInfoDetector frames (360p, jpg there),
redacted to the Boxes' probes by `dev/reader_fixtures/redact_frame.py` and kept
as png: `redact_frame.py SPEC '^(boxes_screen|box_cell)\.' IN OUT`, the spec
from `write_probe_spec.exe --gifts en` (run from `src/`). The cursor's cell
keeps nothing of what it holds but, on pokemon-gardevoir-0-0, the cut-off
name tag over the party title ("ardevoir").

`pokemon-magikarp-2-0-360p.png` ("Box 9") and `empty-2-5-360p.png` ("Box 24"),
from `mac_box_magikarp_2_0_Regular_L032.jpg` and `mac_box_2_5_Empty_None.jpg`
scaled to 640x360 (Lanczos), also keep the box title's band:
`redact_frame.py SPEC '^(boxes_screen|box_cell|box_title)\.' IN OUT`.
