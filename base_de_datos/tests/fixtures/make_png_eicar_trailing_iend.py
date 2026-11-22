#!/usr/bin/env python3
"""SOLO PRUEBA. Genera test_png_eicar_trailing_IEND.png: PNG 1x1 valido con la
cadena EICAR (estandar, inofensiva) anexada DESPUES del chunk IEND.
Se genera en tiempo de test; NO versionar el .png, NO desplegar a produccion.
Uso: python3 make_png_eicar_trailing_iend.py [directorio_salida]
"""
import struct, sys, zlib, pathlib

# EICAR partido en dos para que el propio script no dispare antivirus.
EICAR = (r"X5O!P%@AP[4\PZX54(P^)7CC)7}$" + "EICAR-STANDARD-ANTIVIRUS-TEST-FILE!$H+H*").encode()
NAME = "test_png_eicar_trailing_IEND.png"

def chunk(t, d):
    return struct.pack(">I", len(d)) + t + d + struct.pack(">I", zlib.crc32(t + d) & 0xFFFFFFFF)

def build():
    ihdr = struct.pack(">IIBBBBB", 1, 1, 8, 2, 0, 0, 0)
    idat = zlib.compress(b"\x00\xff\x00\x00")
    return (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr) + chunk(b"IDAT", idat)
            + chunk(b"IEND", b"") + EICAR)

def generate(outdir="."):
    p = pathlib.Path(outdir) / NAME
    p.write_bytes(build())
    return p

if __name__ == "__main__":
    print(generate(sys.argv[1] if len(sys.argv) > 1 else "."))
