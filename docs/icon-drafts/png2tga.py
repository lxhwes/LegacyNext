#!/usr/bin/env python3
"""Convert an 8-bit RGBA, non-interlaced PNG to an uncompressed 32-bit TGA. Stdlib only.

Usage: python3 png2tga.py in.png out.tga
The TGA is image type 2, 32 bpp BGRA, bottom-left origin (descriptor 0x08), which is
what Photoshop and GIMP write and what the WoW client has loaded for years.
"""
import struct
import sys
import zlib


def read_png(path):
    data = open(path, "rb").read()
    assert data[:8] == b"\x89PNG\r\n\x1a\n", "not a PNG"
    pos, idat, ihdr = 8, [], None
    while pos < len(data):
        length, ctype = struct.unpack(">I4s", data[pos:pos + 8])
        body = data[pos + 8:pos + 8 + length]
        if ctype == b"IHDR":
            ihdr = struct.unpack(">IIBBBBB", body)
        elif ctype == b"IDAT":
            idat.append(body)
        pos += 12 + length
    w, h, depth, ctype, _, _, interlace = ihdr
    assert (depth, ctype, interlace) == (8, 6, 0), "need 8-bit RGBA non-interlaced, got %r" % (ihdr,)
    raw = zlib.decompress(b"".join(idat))
    bpp, stride = 4, w * 4
    rows, prev = [], bytearray(stride)
    for y in range(h):
        f = raw[y * (stride + 1)]
        line = bytearray(raw[y * (stride + 1) + 1:(y + 1) * (stride + 1)])
        for i in range(stride):
            a = line[i - bpp] if i >= bpp else 0
            b = prev[i]
            c = prev[i - bpp] if i >= bpp else 0
            if f == 1:
                line[i] = (line[i] + a) & 0xFF
            elif f == 2:
                line[i] = (line[i] + b) & 0xFF
            elif f == 3:
                line[i] = (line[i] + ((a + b) >> 1)) & 0xFF
            elif f == 4:
                p = a + b - c
                pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                pred = a if (pa <= pb and pa <= pc) else (b if pb <= pc else c)
                line[i] = (line[i] + pred) & 0xFF
        rows.append(bytes(line))
        prev = line
    return w, h, rows


def write_tga(path, w, h, rows):
    header = struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, w, h, 32, 0x08)
    out = bytearray(header)
    for row in reversed(rows):
        for x in range(w):
            r, g, b, a = row[x * 4:x * 4 + 4]
            out += bytes((b, g, r, a))
    open(path, "wb").write(out)


if __name__ == "__main__":
    w, h, rows = read_png(sys.argv[1])
    write_tga(sys.argv[2], w, h, rows)
    print("wrote %s %dx%d 32bpp" % (sys.argv[2], w, h))
