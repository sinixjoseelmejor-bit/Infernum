# -*- coding: utf-8 -*-
"""Lecture et ecriture de PNG en pur Python (zlib + struct).

Le projet n'a aucune dependance : cet outil non plus. Ne gere que ce dont
l'extraction a besoin — 8 bits par canal, non entrelace.
"""
import struct
import zlib


def decode(path):
    """-> (largeur, hauteur, lignes de tuples RGBA)."""
    data = open(path, "rb").read()
    assert data[:8] == b"\x89PNG\r\n\x1a\n", "%s n'est pas un PNG" % path
    pos, idat, plte, trns = 8, b"", None, None
    width = height = depth = color = 0
    while pos < len(data):
        length = struct.unpack(">I", data[pos:pos + 4])[0]
        tag = data[pos + 4:pos + 8]
        body = data[pos + 8:pos + 8 + length]
        pos += 12 + length
        if tag == b"IHDR":
            width, height, depth, color, _, _, interlace = struct.unpack(">IIBBBBB", body)
            assert depth == 8 and interlace == 0, "%s : PNG non gere" % path
        elif tag == b"PLTE":
            plte = body
        elif tag == b"tRNS":
            trns = body
        elif tag == b"IDAT":
            idat += body
        elif tag == b"IEND":
            break

    raw = zlib.decompress(idat)
    channels = {0: 1, 2: 3, 3: 1, 4: 2, 6: 4}[color]
    stride = width * channels
    out = bytearray(stride * height)
    prev = bytearray(stride)
    p = 0
    for y in range(height):
        f = raw[p]
        p += 1
        line = bytearray(raw[p:p + stride])
        p += stride
        if f == 1:
            for i in range(channels, stride):
                line[i] = (line[i] + line[i - channels]) & 255
        elif f == 2:
            for i in range(stride):
                line[i] = (line[i] + prev[i]) & 255
        elif f == 3:
            for i in range(stride):
                a = line[i - channels] if i >= channels else 0
                line[i] = (line[i] + ((a + prev[i]) >> 1)) & 255
        elif f == 4:
            for i in range(stride):
                a = line[i - channels] if i >= channels else 0
                b = prev[i]
                c = prev[i - channels] if i >= channels else 0
                q = a + b - c
                pa, pb, pc = abs(q - a), abs(q - b), abs(q - c)
                line[i] = (line[i] + (a if pa <= pb and pa <= pc else (b if pb <= pc else c))) & 255
        out[y * stride:(y + 1) * stride] = line
        prev = line

    rows = []
    for y in range(height):
        row = []
        for x in range(width):
            i = y * stride + x * channels
            if color == 6:
                row.append(tuple(out[i:i + 4]))
            elif color == 2:
                row.append((out[i], out[i + 1], out[i + 2], 255))
            elif color == 0:
                v = out[i]
                row.append((v, v, v, 255))
            elif color == 4:
                v = out[i]
                row.append((v, v, v, out[i + 1]))
            else:
                k = out[i]
                r, g, b = plte[k * 3:k * 3 + 3]
                row.append((r, g, b, trns[k] if trns and k < len(trns) else 255))
        rows.append(row)
    return width, height, rows


def encode(width, height, rows):
    raw = bytearray()
    for row in rows:
        raw.append(0)
        for px in row:
            raw += bytes(px)

    def chunk(tag, body):
        block = tag + body
        return struct.pack(">I", len(body)) + block + struct.pack(">I", zlib.crc32(block) & 0xFFFFFFFF)

    return (b"\x89PNG\r\n\x1a\n"
            + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0))
            + chunk(b"IDAT", zlib.compress(bytes(raw), 9))
            + chunk(b"IEND", b""))
