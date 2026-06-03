"""
Scraper de Sentencias del Primer Tribunal Ambiental (1TA).

Descubre el API REST que alimenta la SPA en
https://www.portaljudicial1ta.cl/sgc-web/sentencias.html y descarga los PDF de
las sentencias publicadas. No requiere navegador ni autenticacion: todos los
endpoints son publicos (GET).

Cadena de resolucion por sentencia:
    1. /sentencia/search?year=Y&month=M
         -> [{rol, caratula, codDocumento, fechaSentencia, ...}]
    2. /ver-causa/cuaderno-por-documento?documento=<codDocumento>
         -> idCuaderno
    3. /ver-causa/lista-asiento-cuaderno?idCuaderno=<id>&tipoDocumento=all
         -> [asientos]; se busca el que tenga codDocumento == codDocumento
         -> codAsiento
    4. /ver-causa/lista-documento-asiento?asiento=<codAsiento>
         -> linkFoleado / linkFirmando / linkOriginal  (ruta del PDF)
    5. /servlet/download-file?file=<ruta>
         -> bytes del PDF
"""

import argparse
import csv
import json
import re
import sys
import time
from collections import Counter
from pathlib import Path
from urllib.parse import quote

import requests

BASE = "https://www.portaljudicial1ta.cl/sgc-ws/rest"
DOWNLOAD_SERVLET = BASE + "/servlet/download-file?file="

# Rango con datos conocido al 2026-05; el scraper se detiene solo en anios vacios.
DEFAULT_YEARS = range(2018, 2027)


class TribunalClient:
    """Cliente HTTP fino sobre el API del 1TA, con reintentos y cortesia."""

    def __init__(self, delay=0.8, timeout=60, retries=3):
        self.s = requests.Session()
        self.s.headers.update({
            "User-Agent": "1ta-sentencias-scraper/1.0 (investigacion ambiental)",
            "Accept": "application/json, */*",
        })
        self.delay = delay
        self.timeout = timeout
        self.retries = retries

    def _get(self, url, **kw):
        last = None
        for attempt in range(self.retries):
            try:
                r = self.s.get(url, timeout=self.timeout, **kw)
                r.raise_for_status()
                return r
            except requests.RequestException as e:
                last = e
                time.sleep(self.delay * (attempt + 1) * 2)
        raise last

    def _get_json(self, url):
        """Endpoints devuelven {response: <json-string>, status: '200'}.

        El campo `response` viene como string JSON (doble codificado).
        """
        r = self._get(url)
        time.sleep(self.delay)
        data = r.json()
        resp = data.get("response")
        if resp in (None, "", "null"):
            return None
        return json.loads(resp)

    # --- pasos de la cadena -------------------------------------------------

    def search(self, year, month=0):
        url = f"{BASE}/sentencia/search?year={year}&month={month}"
        return self._get_json(url) or []

    def cuaderno_de_documento(self, cod_documento):
        url = f"{BASE}/ver-causa/cuaderno-por-documento?documento={cod_documento}"
        return self._get_json(url)  # devuelve el id como string, p.ej. "310"

    def datos_causa(self, rol):
        """Datos de la causa por rol (incluye idCausa). None si no existe."""
        url = f"{BASE}/ver-causa/carga-datos-causa?rolCausa={quote(rol)}"
        obj = self._get_json(url)
        if isinstance(obj, dict) and obj.get("idCausa"):
            return obj
        return None

    def cuadernos_causa(self, id_causa):
        url = f"{BASE}/ver-causa/lista-cuadernos-causa?idCausa={id_causa}"
        return self._get_json(url) or []

    def litigantes(self, rol):
        url = f"{BASE}/ver-causa/lista-litigantes-causa?rolCausa={quote(rol)}"
        return self._get_json(url) or []

    def rol_desde_documento(self, cod_documento):
        """Deduce el rol a partir de un codDocumento/cita.

        La ruta del PDF contiene el rol, p.ej.
        /data/sgc/documentos/R-1-2017/<uuid>.pdf -> R-1-2017.
        """
        ruta, _ = self.resolver_pdf(cod_documento)
        if not ruta:
            return None
        m = re.search(r"/documentos/([^/]+)/", ruta)
        return m.group(1) if m else None

    def asientos_de_cuaderno(self, id_cuaderno):
        url = (f"{BASE}/ver-causa/lista-asiento-cuaderno?idCuaderno={id_cuaderno}"
               "&tipoDocumento=all&idUsuario=&rolUsuario=")
        return self._get_json(url) or []

    def documentos_de_asiento(self, cod_asiento):
        url = (f"{BASE}/ver-causa/lista-documento-asiento?token=&asiento="
               f"{cod_asiento}")
        return self._get_json(url) or []

    def resolver_pdf(self, cod_documento):
        """Resuelve la ruta del PDF a partir del codDocumento de la sentencia.

        Prefiere el documento foleado/firmado sobre el original.
        Devuelve (ruta_pdf, cod_asiento) o (None, None).
        """
        id_cuaderno = self.cuaderno_de_documento(cod_documento)
        if not id_cuaderno:
            return None, None

        cod_asiento = None
        for asiento in self.asientos_de_cuaderno(id_cuaderno):
            if str(asiento.get("codDocumento")) == str(cod_documento):
                cod_asiento = asiento.get("codAsiento")
                break
        if not cod_asiento:
            return None, None

        for doc in self.documentos_de_asiento(cod_asiento):
            if str(doc.get("codDocumento")) != str(cod_documento):
                continue
            ruta = (doc.get("linkFirmando")
                    or doc.get("linkFoleado")
                    or doc.get("linkOriginal"))
            if ruta:
                return ruta, cod_asiento
        return None, cod_asiento

    def descargar(self, ruta_pdf, destino: Path):
        url = DOWNLOAD_SERVLET + quote(ruta_pdf, safe="")
        r = self._get(url)
        time.sleep(self.delay)
        if not r.content.startswith(b"%PDF"):
            raise ValueError(
                f"Respuesta no es PDF (ct={r.headers.get('content-type')}, "
                f"{len(r.content)} bytes)")
        destino.write_bytes(r.content)
        return len(r.content)


# codTipoDocumento -> etiqueta corta para nombres de archivo
TIPOS = {"1": "escrito", "2": "certificacion", "3": "resolucion",
         "4": "actuacion", "5": "sentencia", "6": "notificacion",
         "7": "conciliacion"}

# Por defecto: sentencias + resoluciones + actuaciones ("modificaciones e
# intervenciones"). Notificaciones, escritos y certificaciones se omiten.
TIPOS_DEFAULT = ("3", "4", "5")


def mejor_link(doc):
    """Ruta PDF preferida de un documento: firmado > foleado > original."""
    return (doc.get("linkFirmando")
            or doc.get("linkFoleado")
            or doc.get("linkOriginal"))


def scrape_causa(client, rol, out: Path, tipos, delay):
    """Descarga los documentos (tipos seleccionados) de una causa por rol."""
    datos = client.datos_causa(rol)
    if not datos:
        print(f"[{rol}] causa no encontrada en el portal publico")
        return []

    id_causa = datos["idCausa"]
    caratula = datos.get("caratulaCausa", "")
    print(f"[{rol}] {caratula}")
    causa_dir = out / slug(rol)
    causa_dir.mkdir(parents=True, exist_ok=True)

    # Litigantes: separar por rol judicial para el resumen.
    litigantes = client.litigantes(rol)
    info = {
        "rol": rol,
        "caratula": caratula,
        "tipoCausa": datos.get("tipoCausa"),
        "materia": datos.get("materia"),
        "fechaIngreso": datos.get("fechaIngreso"),
        "region": datos.get("region"),
        "comuna": datos.get("comuna"),
        "idCausa": id_causa,
        "litigantes": [
            {
                "rolJudicial": x.get("txtRolJudicial"),
                "tipoPersona": x.get("txtTipoPersona"),
                "nombre": " ".join(filter(None, [x.get("txtNombre"),
                                                 x.get("txtApellido")])).strip(),
                "rut": (f"{x.get('txtRut')}-{x.get('txtRutDv')}"
                        if x.get("txtRut") else None),
                "email": x.get("txtEmail") or None,
            }
            for x in litigantes
        ],
    }

    rows = []
    for cuaderno in client.cuadernos_causa(id_causa):
        id_cuaderno = cuaderno.get("clave")
        nombre_cuaderno = cuaderno.get("valor", "")
        asientos = client.asientos_de_cuaderno(id_cuaderno)
        objetivo = [a for a in asientos
                    if str(a.get("codTipoDocumento")) in tipos]
        print(f"  cuaderno {nombre_cuaderno}: {len(objetivo)}/{len(asientos)} "
              f"documentos en tipos {tipos}")

        for a in objetivo:
            cod_asiento = a.get("codAsiento")
            cod_doc = a.get("codDocumento")
            tipo = str(a.get("codTipoDocumento"))
            fecha = (a.get("fechaDocumento") or "").replace("/", "-")
            etiqueta = TIPOS.get(tipo, f"tipo{tipo}")
            row = {
                "rol": rol, "cuaderno": nombre_cuaderno,
                "codAsiento": cod_asiento, "codDocumento": cod_doc,
                "tipo": etiqueta, "fecha": a.get("fechaDocumento"),
                "nombre": a.get("nombreDocumento"), "rutaPdf": "",
                "archivo": "", "bytes": "", "estado": "",
            }
            try:
                docs = client.documentos_de_asiento(cod_asiento)
                principal = next(
                    (d for d in docs if d.get("tipoArchivo") == "documento"),
                    docs[0] if docs else None)
                ruta = mejor_link(principal) if principal else None
                row["rutaPdf"] = ruta or ""
                if not ruta:
                    row["estado"] = "sin_link"
                    print(f"    ! asiento {cod_asiento} ({etiqueta}): sin link")
                else:
                    nombre = (f"{fecha}__{etiqueta}__{slug(a.get('nombreDocumento'), 50)}"
                              f"__a{cod_asiento}.pdf")
                    destino = causa_dir / nombre
                    row["archivo"] = str(destino)
                    if destino.exists() and destino.stat().st_size > 0:
                        row["estado"] = "ya_existe"
                        row["bytes"] = destino.stat().st_size
                        print(f"    = {nombre}")
                    else:
                        n = client.descargar(ruta, destino)
                        row["bytes"] = n
                        row["estado"] = "ok"
                        print(f"    + {nombre} ({n} bytes)")
            except Exception as e:  # noqa: BLE001
                row["estado"] = f"error: {e}"
                print(f"    ! asiento {cod_asiento}: ERROR {e}", file=sys.stderr)
            rows.append(row)

    # Conteo por tipo y nota de escaneados (texto se detecta en el resumen).
    info["conteoPorTipo"] = dict(Counter(r["tipo"] for r in rows))
    info["totalDocumentos"] = len(rows)
    (causa_dir / "info.json").write_text(
        json.dumps(info, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"  info.json -> {causa_dir / 'info.json'}")
    return rows


def slug(texto, maxlen=80):
    texto = re.sub(r"[^\w\s-]", "", texto or "", flags=re.UNICODE).strip()
    texto = re.sub(r"\s+", "_", texto)
    return texto[:maxlen].strip("_") or "sin_titulo"


def main():
    ap = argparse.ArgumentParser(description="Scraper de sentencias del 1TA")
    ap.add_argument("--rol", nargs="+",
                    help="Causa(s) por rol, p.ej. R-1-2017 (modo causa completa: "
                         "descarga sentencias + resoluciones + actuaciones)")
    ap.add_argument("--from-doc", nargs="+",
                    help="codDocumento(s)/cita numerica; se resuelve a rol y se "
                         "descarga la causa completa")
    ap.add_argument("--tipos", nargs="+", default=list(TIPOS_DEFAULT),
                    help="codTipoDocumento a incluir en modo --rol "
                         "(1=escrito 2=certif 3=resolucion 4=actuacion 5=sentencia "
                         "6=notif 7=conciliacion). Default: 3 4 5")
    ap.add_argument("--years", type=int, nargs="+", default=list(DEFAULT_YEARS),
                    help="Anios a descargar en modo sentencias (default: 2018-2026)")
    ap.add_argument("--out", default="out", help="Directorio de salida")
    ap.add_argument("--delay", type=float, default=0.8,
                    help="Segundos de espera entre requests (cortesia)")
    ap.add_argument("--manifest-only", action="store_true",
                    help="Solo construye el CSV de metadatos, no descarga PDFs")
    args = ap.parse_args()

    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    client = TribunalClient(delay=args.delay)

    # Resolver citas numericas (codDocumento) a roles.
    roles = list(args.rol or [])
    if args.from_doc:
        for cod in args.from_doc:
            rol = client.rol_desde_documento(cod)
            if rol:
                print(f"[cita {cod}] -> rol {rol}")
                roles.append(rol)
            else:
                print(f"[cita {cod}] no se pudo resolver a un rol")

    # --- Modo causa completa por rol ---------------------------------------
    if roles:
        rows = []
        for rol in roles:
            rows += scrape_causa(client, rol, out, tuple(args.tipos), args.delay)
        manifest_path = out / "manifest_causas.csv"
        fields = ["rol", "cuaderno", "codAsiento", "codDocumento", "tipo",
                  "fecha", "nombre", "rutaPdf", "archivo", "bytes", "estado"]
        with manifest_path.open("w", newline="", encoding="utf-8") as f:
            w = csv.DictWriter(f, fieldnames=fields)
            w.writeheader()
            w.writerows(rows)
        ok = sum(1 for r in rows if r["estado"] in ("ok", "ya_existe"))
        print(f"\nDocumentos: {len(rows)} | descargados/existentes: {ok} | "
              f"fallidos: {len(rows) - ok}")
        print(f"Manifest: {manifest_path}")
        return

    manifest_path = out / "manifest.csv"
    fields = ["year", "rol", "caratula", "fechaIngreso", "fechaSentencia",
              "redactor", "integracion", "codDocumento", "rutaPdf",
              "archivo", "bytes", "estado"]

    rows = []
    total = 0
    descargados = 0
    fallidos = 0

    for year in args.years:
        sentencias = client.search(year)
        if not sentencias:
            print(f"[{year}] sin sentencias")
            continue
        print(f"[{year}] {len(sentencias)} sentencias")
        year_dir = out / str(year)
        year_dir.mkdir(exist_ok=True)

        for s in sentencias:
            total += 1
            rol = s.get("rol", "SIN_ROL")
            cod = s.get("codDocumento")
            nombre = f"{slug(rol)}__{slug(s.get('caratula'), 60)}.pdf"
            destino = year_dir / nombre
            row = {
                "year": year, "rol": rol, "caratula": s.get("caratula"),
                "fechaIngreso": s.get("fechaIngreso"),
                "fechaSentencia": s.get("fechaSentencia"),
                "redactor": s.get("redactor"),
                "integracion": s.get("integracion"),
                "codDocumento": cod, "rutaPdf": "", "archivo": str(destino),
                "bytes": "", "estado": "",
            }

            try:
                ruta, _ = client.resolver_pdf(cod)
                row["rutaPdf"] = ruta or ""
                if not ruta:
                    row["estado"] = "sin_link"
                    fallidos += 1
                    print(f"  ! {rol}: sin link de PDF")
                elif args.manifest_only:
                    row["estado"] = "resuelto"
                elif destino.exists() and destino.stat().st_size > 0:
                    row["estado"] = "ya_existe"
                    row["bytes"] = destino.stat().st_size
                    descargados += 1
                    print(f"  = {rol}: ya existe")
                else:
                    n = client.descargar(ruta, destino)
                    row["bytes"] = n
                    row["estado"] = "ok"
                    descargados += 1
                    print(f"  + {rol}: {n} bytes -> {destino.name}")
            except Exception as e:  # noqa: BLE001 - registrar y seguir
                row["estado"] = f"error: {e}"
                fallidos += 1
                print(f"  ! {rol}: ERROR {e}", file=sys.stderr)

            rows.append(row)

    with manifest_path.open("w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=fields)
        w.writeheader()
        w.writerows(rows)

    print(f"\nTotal sentencias: {total} | descargadas: {descargados} | "
          f"fallidas: {fallidos}")
    print(f"Manifest: {manifest_path}")


if __name__ == "__main__":
    main()
