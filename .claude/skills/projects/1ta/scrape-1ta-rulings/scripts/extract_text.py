"""
Extrae texto de los PDF de una causa descargada por scraper.py.

Para cada PDF corre `pdftotext -layout`. Los fallos del 1TA antiguos son
imagenes escaneadas (solo el timbre de foja sale como texto), asi que se
clasifica cada documento como 'texto' o 'escaneado' segun cuanto texto util
tenga. Opcionalmente corre OCR (ocrmypdf, espanol) sobre los escaneados para
recuperar su contenido.

Salida en el directorio de la causa:
    text/<archivo>.txt      texto extraido por documento
    text_index.json         indice: archivo, tipo, fecha, chars, escaneado

Uso:
    python extract_text.py <dir_causa> [--ocr]
"""

import argparse
import json
import re
import subprocess
import sys
from pathlib import Path

# Umbral de caracteres (sin espacios) bajo el cual se considera escaneado.
UMBRAL_TEXTO = 500


def pdftotext(pdf: Path):
    try:
        out = subprocess.run(
            ["pdftotext", "-layout", str(pdf), "-"],
            capture_output=True, timeout=120)
        return out.stdout.decode("utf-8", "replace")
    except (subprocess.SubprocessError, FileNotFoundError) as e:
        print(f"  pdftotext fallo en {pdf.name}: {e}", file=sys.stderr)
        return ""


def util(texto):
    """Caracteres sin contar espacios ni los timbres de foja repetidos."""
    sin_foja = re.sub(r"Fojas?\s*\d+|dos mil[^\n]*", "", texto)
    return len(re.sub(r"\s+", "", sin_foja))


def ocr(pdf: Path, destino: Path):
    """Corre ocrmypdf espanol; devuelve texto o '' si no esta disponible."""
    try:
        subprocess.run(
            ["ocrmypdf", "-l", "spa", "--force-ocr", "--sidecar", str(destino),
             str(pdf), "/dev/null"],
            capture_output=True, timeout=600, check=True)
        return destino.read_text("utf-8", "replace") if destino.exists() else ""
    except FileNotFoundError:
        print("  ocrmypdf no instalado; omitiendo OCR", file=sys.stderr)
        return None  # senal de que OCR no esta disponible
    except subprocess.SubprocessError as e:
        print(f"  ocrmypdf fallo en {pdf.name}: {e}", file=sys.stderr)
        return ""


def main():
    ap = argparse.ArgumentParser(description="Extrae texto de una causa")
    ap.add_argument("dir_causa", help="Directorio de la causa (con los PDF)")
    ap.add_argument("--ocr", action="store_true",
                    help="OCR (ocrmypdf, espanol) sobre los escaneados")
    args = ap.parse_args()

    base = Path(args.dir_causa)
    pdfs = sorted(base.glob("*.pdf"))
    if not pdfs:
        print(f"No hay PDF en {base}", file=sys.stderr)
        sys.exit(1)

    text_dir = base / "text"
    text_dir.mkdir(exist_ok=True)
    ocr_disponible = True
    indice = []

    for pdf in pdfs:
        texto = pdftotext(pdf)
        chars = util(texto)
        escaneado = chars < UMBRAL_TEXTO
        ocr_aplicado = False

        if escaneado and args.ocr and ocr_disponible:
            sidecar = text_dir / (pdf.stem + ".ocr.txt")
            res = ocr(pdf, sidecar)
            if res is None:
                ocr_disponible = False
            elif res:
                texto, chars, escaneado, ocr_aplicado = res, util(res), False, True

        (text_dir / (pdf.stem + ".txt")).write_text(texto, encoding="utf-8")
        # Nombre: fecha__tipo__... -> recuperar campos del patron del scraper.
        partes = pdf.stem.split("__")
        indice.append({
            "archivo": pdf.name,
            "fecha": partes[0] if partes else "",
            "tipo": partes[1] if len(partes) > 1 else "",
            "chars": chars,
            "escaneado": escaneado,
            "ocr": ocr_aplicado,
        })
        marca = "OCR" if ocr_aplicado else ("escaneado" if escaneado else "texto")
        print(f"  [{marca}] {pdf.name} ({chars} chars)")

    (base / "text_index.json").write_text(
        json.dumps(indice, ensure_ascii=False, indent=2), encoding="utf-8")
    n_txt = sum(1 for x in indice if not x["escaneado"])
    print(f"\n{len(indice)} PDF | con texto: {n_txt} | "
          f"escaneados: {len(indice) - n_txt}")
    print(f"Indice: {base / 'text_index.json'}")


if __name__ == "__main__":
    main()
