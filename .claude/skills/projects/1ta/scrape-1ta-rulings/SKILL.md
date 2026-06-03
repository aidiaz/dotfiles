---
name: scrape-1ta-rulings
description: >-
  Descarga y resume causas del Primer Tribunal Ambiental de Chile (1TA) desde el
  portal publico portaljudicial1ta.cl. Usa esta skill SIEMPRE que el usuario
  mencione un rol del 1TA (formato R-N-AAAA, D-N-AAAA, S-N-AAAA, p.ej. R-1-2017),
  un numero de cita / codDocumento de una sentencia o resolucion del tribunal
  ambiental, o pida "bajar", "scrapear", "descargar" o "resumir" expedientes,
  sentencias, resoluciones o fallos ambientales chilenos. Tambien aplica cuando
  el usuario habla del "tribunal ambiental", "1TA", "1ta.cl" o causas
  ambientales (Dominga, proyectos mineros, SEA, Superintendencia del Medio
  Ambiente) y quiere los PDFs o un analisis del caso. Baja los PDF via el API
  REST publico (sin navegador ni login), los organiza por causa y entrega un
  resumen detallado con partes, hitos y resultado.
---

# Scraper de causas del Primer Tribunal Ambiental (1TA)

El portal `portaljudicial1ta.cl` es una SPA respaldada por un **API REST publico
y sin autenticacion** (`/sgc-ws/rest`). No se necesita navegador ni Playwright:
todo se resuelve con HTTP directo, que es mas rapido y robusto. Esta skill
envuelve ese flujo en dos scripts y produce un resumen "quisquilloso" de la
causa.

## Entrada

El usuario dara una de estas dos cosas:

- **Un rol**: `R-1-2017`, `D-11-2021`, `S-3-2020`. Es el identificador de la
  causa (R=Reclamacion, D=Demanda, S=Solicitud, etc.).
- **Una cita / codDocumento**: un numero como `9550` que identifica un documento
  (sentencia o resolucion) dentro del sistema. Se resuelve al rol
  automaticamente (la ruta interna del PDF contiene el rol).

Si la entrada es ambigua, pregunta brevemente; si es un numero, tratalo como
codDocumento.

## Flujo

Trabaja desde un directorio del proyecto (p.ej. el cwd actual). Los scripts
estan en `scripts/` dentro de esta skill; usa la ruta absoluta de la skill.

### 1. Descargar la causa

Por rol:

```bash
python3 <SKILL_DIR>/scripts/scraper.py --rol R-1-2017 --out causas
```

Por cita / codDocumento (se resuelve a rol y baja la causa completa):

```bash
python3 <SKILL_DIR>/scripts/scraper.py --from-doc 9550 --out causas
```

Esto crea `causas/<ROL>/` con:
- Los PDF nombrados `fecha__tipo__nombre__a<codAsiento>.pdf` (ordenan
  cronologicamente solos).
- `info.json` con metadatos de la causa, **litigantes** (separados por rol
  judicial: reclamante, reclamado, terceros, abogados) y conteo por tipo.
- `manifest_causas.csv` en `causas/` con una fila por documento.

Por defecto baja **sentencias + resoluciones + actuaciones** (tipos `3 4 5`),
que es lo sustantivo del expediente. Para incluir todo (escritos,
certificaciones, notificaciones) agrega `--tipos 1 2 3 4 5 6 7`. El scraper es
**reanudable**: re-ejecutar omite los archivos que ya existen.

Es un servidor estatal: deja el `--delay` por defecto (0.8s). Para causas
grandes (>100 docs) corre en segundo plano y avisa al usuario del avance.

### 2. Extraer texto

```bash
python3 <SKILL_DIR>/scripts/extract_text.py causas/R-1-2017
```

Crea `causas/R-1-2017/text/<archivo>.txt` y `text_index.json` que marca cada
documento como `texto` o `escaneado`.

**Importante**: muchos fallos antiguos del 1TA son **PDF escaneados** (solo el
timbre de foja sale como texto). En esos `pdftotext` no extrae nada. Para
recuperarlos pasa `--ocr` (requiere `ocrmypdf`; instalable con
`pip install ocrmypdf` + el binario `tesseract-ocr-spa`):

```bash
python3 <SKILL_DIR>/scripts/extract_text.py causas/R-1-2017 --ocr
```

Si no hay `ocrmypdf`, el script lo informa y sigue sin OCR; dilo en el resumen y
ofrece instalarlo.

### 3. Redactar el resumen

Lee `info.json` y los `.txt` de los documentos clave (la sentencia y las
resoluciones con mas texto; usa `text_index.json` para elegir los que tienen
contenido). Para hechos especificos (resultado, montos, fechas de hitos), cita
el documento del que salen. **No inventes**: si un dato solo esta en un PDF
escaneado sin OCR, dilo explicitamente en vez de adivinar.

## Formato del resumen

Entrega el resumen en este orden. Es deliberadamente detallado y "quisquilloso":
el usuario hace investigacion juridica/ambiental seria y necesita precision y
trazabilidad, no un parrafo generico.

```markdown
# <ROL> — <Caratula>

## Identificacion
- **Rol / tipo**: R-1-2017 (Reclamacion, art. 17 N°X Ley 20.600)
- **Caratula**: ...
- **Materia**: ...
- **Region / comuna**: ...
- **Fecha de ingreso**: dd/mm/aaaa
- **Proyecto / acto impugnado**: (p.ej. Dominga; Res. Ex. N°1146/2017 del Comite de Ministros)

## Partes
- **Reclamante(s)**: nombre, RUT, representacion (abogados). Distingue
  reclamante de terceros coadyuvantes — no los mezcles.
- **Reclamado(s)**: ...
- **Terceros coadyuvantes**: por parte (de la reclamante / de la reclamada).

## El expediente (lo descargado)
- Total de documentos bajados y desglose por tipo (resoluciones, actuaciones,
  sentencia(s)).
- Rango de fechas cubierto.
- Nota de cobertura de texto: cuantos PDF son texto vs escaneados, y si se
  aplico OCR. Esto le dice al usuario que tan completo es el analisis.

## Linea de tiempo (hitos)
Lista cronologica de los hitos relevantes con su fecha y el documento fuente:
ingreso, admisibilidad, inspeccion personal del Tribunal, vista de la causa,
sentencia(s), recursos a la Corte Suprema, cumplimiento. Cita el archivo.

## Resultado
- Que resolvio el Tribunal (acoge / rechaza / acoge parcialmente) y, si existe,
  el destino posterior (Corte Suprema, reenvio, nueva sentencia). Cita el o los
  documentos de sentencia.

## Notas y limitaciones
- Documentos que no se pudieron leer (escaneados sin OCR), datos no verificables
  en lo descargado, etc.
```

Si el usuario pidio algo mas acotado (solo las partes, solo el resultado),
responde eso directamente y ofrece el resumen completo.

## Notas tecnicas

- Endpoints clave (todos GET publicos, base `https://www.portaljudicial1ta.cl/sgc-ws/rest`):
  `sentencia/search`, `ver-causa/carga-datos-causa`, `lista-cuadernos-causa`,
  `lista-asiento-cuaderno`, `lista-documento-asiento`,
  `lista-litigantes-causa`, `servlet/download-file`. El detalle del flujo esta
  documentado en el docstring de `scripts/scraper.py`.
- Para descubrir causas por criterio (region, anio, parte) en vez de por rol
  conocido, existe `POST consulta-causa/get-consulta-causa` (multipart; los
  campos no usados van con el string `"null"`, no vacios). No esta envuelto aun;
  agregalo a `scraper.py` si el usuario lo pide.
- Si en el futuro el portal agrega un WAF/Cloudflare que bloquee `requests`,
  habria que reemplazar `TribunalClient` por automatizacion de navegador; el
  resto del flujo no cambia.
