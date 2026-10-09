"""Pack the generated PNG iconset into a standard PNG-backed ICNS file.

macOS iconutil on this host rejects even iconsets it produced itself, so this
small packer writes the documented ICNS chunk container directly. The result
can be checked by unpacking it with iconutil -c iconset.
"""

from pathlib import Path
from struct import pack


here = Path(__file__).resolve().parent
iconset = here / "AppIcon.iconset"
output = here.parent / "AppIcon.icns"

representations = [
    (b"icp4", "icon_16x16.png"),
    (b"ic11", "icon_16x16@2x.png"),
    (b"icp5", "icon_32x32.png"),
    (b"ic12", "icon_32x32@2x.png"),
    (b"ic07", "icon_128x128.png"),
    (b"ic13", "icon_128x128@2x.png"),
    (b"ic08", "icon_256x256.png"),
    (b"ic14", "icon_256x256@2x.png"),
    (b"ic09", "icon_512x512.png"),
    (b"ic10", "icon_512x512@2x.png"),
]

chunks = []
for type_code, filename in representations:
    png = (iconset / filename).read_bytes()
    if not png.startswith(b"\x89PNG\r\n\x1a\n"):
        raise ValueError(f"Not a PNG: {filename}")
    chunks.append(type_code + pack(">I", len(png) + 8) + png)

body = b"".join(chunks)
output.write_bytes(b"icns" + pack(">I", len(body) + 8) + body)
print(output)
