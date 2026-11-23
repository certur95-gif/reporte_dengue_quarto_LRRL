# Registro de cambios del reporte de dengue

## 17.11.2026 · Ajuste de dos láminas (SE 44-2026)

### 1. Tabla "NÚMERO DE MUESTRAS DE DENGUE E IP POR MICRORED Y EESS" se salía de la diapositiva

**Problema.** La diapositiva mide 13.33 x 7.5 pulgadas. La tabla medía 12.4
pulgadas de ancho y, a partir de la 2.ª lámina, flextable la colocaba en su
posición por defecto (1 pulgada desde la izquierda) porque dentro del bucle no
leía las opciones `ft.left` / `ft.top` del chunk. El borde derecho quedaba en
13.4 pulgadas, fuera de la lámina.

**Qué se cambió** (archivo `reporte_dengue.qmd`, chunk `laminas-semana`):

| Antes | Ahora |
|---|---|
| Anchos 0.9 / 2.9 / 5.3 / 0.9 / 0.9 / 0.8 / 0.7 = 12.4 pulg. | 0.6 / 2.6 / 5.1 / 0.9 / 0.9 / 0.7 / 0.7 = 11.5 pulg. |
| Letra 10 pt, alto de fila 0.23 | Letra 9 pt, alto de fila 0.22 |
| 20 filas por lámina | 18 filas por lámina |
| Posición solo por opciones del chunk (se perdía desde la 2.ª lámina) | Posición fija en cada lámina: `flextable_to_rmd(ft, ft.left = 0.9, ft.top = 2.1)` (tabla centrada) |

Con 9 pt el nombre de EESS más largo de esta semana mide unas 4.5 pulgadas y
cabe en la columna de 5.1, así que las filas no se parten en dos líneas.
No cambia ninguna cifra.

Para ajustar en el futuro: el número de filas por lámina está en
`paginar(t, filas = 18)` y la posición en `pos_izq` / `pos_arr`, ambos en el
mismo chunk.

### 2. Tabla "DIAGNÓSTICO DIFERENCIAL: ZIKA Y CHIKUNGUNYA": solo 2025 y 2026

**Qué se cambió:**

- `R/00_config.R`: nueva opción `DIFERENCIAL_ANIOS_PREVIOS <- 1`. Significa
  "el año del reporte y 1 año anterior". Con `ANIO <- 2026` entran 2025 y 2026.
  En 2027 pasará solo a 2026 y 2027 sin tocar nada. Para volver a ver todos los
  años, poner `Inf`.
- `R/05_preparar.R` (paso 3): el filtro de Zika / Chikungunya ahora exige que
  la fecha de toma sea del año `ANIO - DIFERENCIAL_ANIOS_PREVIOS` en adelante.
  Se filtra ahí, antes de armar la tabla, para que la tabla de la lámina, el
  texto con los positivos / negativos y la hoja `zika_chik` del Excel de tablas
  usen las mismas cifras.
- `reporte_dengue.qmd` (chunk `lamina-zika-chik-titulo`): el texto de la lámina
  ahora dice qué años se muestran ("Se muestran los años 2025–2026").

**Efecto esperado en la SE 44:** desaparecen las filas 2023 (2 pruebas) y 2024
(84 pruebas). El total general baja de 4,418 a 4,332 pruebas. Los 26 positivos
y 17 indeterminados de Chikungunya son todos de 2026, así que no cambian; sí
bajan los negativos del texto.

**No se tocó:** Mayaro y Oropouche siguen mostrando todos los años.

### Archivos modificados (cambios 1 y 2)

- `reporte_dengue.qmd`
- `R/00_config.R`
- `R/05_preparar.R`
- `CAMBIOS.md` (este archivo, nuevo)

Cada cambio en el código está marcado con el comentario `[Cambio 17.11.2026]`.

### 3. El reporte no se actualizaba con la descarga de la SE 45

**Causa.** El archivo `datos/semanal/Resultados (10).xlsx` sí es la SE 45
(1,031 registros, verificados del 09 al 14.11.2026) y el código lo lee bien.
Pero la semana del reporte seguía en 44 en dos sitios:

- `generar_reporte.R`: `SE <- 44`
- `reporte_dengue.qmd` (encabezado YAML): `se: 44`

Con SE 44 la fecha de corte es el sábado 07.11.2026, y todo lo verificado
después (es decir, toda la SE 45) queda fuera. Además, si se pulsa **Render**
sobre el `.qmd`, se usa el `se:` del encabezado y no el de `generar_reporte.R`;
el PPTX sale en la carpeta raíz (`reporte_dengue.pptx`) y no en `salidas/`.

**Qué se cambió:** ambos valores pasan a 45, con un comentario en el `.qmd`
que recuerda mantenerlos iguales.

**Cómo generarlo cada semana:** cambiar `SE <-` en `generar_reporte.R` y pulsar
**Source** en ese archivo (no **Render** en el `.qmd`). El informe queda en
`salidas/SE45_2026_INFORME_SEMANAL_DENGUE_LRRL.pptx`.

### 4. Logos en la plantilla y error "PowerPoint debe reparar el archivo"

**Causa del error.** Al guardar `plantilla/plantilla_lrrl.pptx` desde PowerPoint
en OneDrive, el archivo incorporó dos partes de control de versiones
(`revisionInfo.xml` y `changesInfos/changesInfo1.xml`). Pandoc (el motor de
Quarto) copia las *referencias* a esas partes al informe, pero no los archivos.
El PPTX resultante apunta a dos archivos que no existen y PowerPoint pide
repararlo. Se comprobó generando una presentación de prueba con la plantilla
anterior (2 referencias rotas) y con la nueva (ninguna).

**Qué se cambió en `plantilla/plantilla_lrrl.pptx`:**

- Se quitaron `revisionInfo` y `changesInfo`. El diseño (colores, fuentes,
  posiciones) no cambia.
- Logos agregados:
  - **Portada** (diseño "Title Slide"): DIRESA Loreto arriba a la izquierda y
    LRRL arriba a la derecha, en tamaño grande.
  - **Resto de láminas** (patrón de diapositivas): ambos logos chicos en la
    franja inferior, DIRESA a la izquierda y LRRL a la derecha, debajo del
    área de contenido para no tapar gráficos ni tablas.
- Al logo de DIRESA se le recortó el borde blanco y la línea gris inferior.

**Si vuelves a editar la plantilla en PowerPoint**, el error puede regresar
porque PowerPoint vuelve a añadir esas partes al guardar en OneDrive. Para
evitarlo, guarda la plantilla con *Archivo > Guardar una copia* en una carpeta
fuera de OneDrive y cópiala luego aquí, o avísame para limpiarla de nuevo.

### 5. El informe se guarda en salidas/ con el nombre de la SE

- `generar_reporte.R` ya nombraba el informe como
  `SE45_2026_INFORME_SEMANAL_DENGUE_LRRL.pptx` (SE + año) y lo movía a
  `salidas/`, pero si algo fallaba no avisaba. Ahora:
  - se detiene con un mensaje claro si Quarto no generó el archivo;
  - si el informe de esa SE ya existe en `salidas/`, lo reemplaza; si está
    abierto en PowerPoint, pide cerrarlo.
- `reporte_dengue.qmd`: comentario al inicio recordando no usar **Render** ahí,
  porque ese botón deja `reporte_dengue.pptx` en la carpeta principal y no en
  `salidas/`.

### 6. Las salidas no llegaban a salidas/ (ni el PPTX ni el Excel)

**Causa.** El informe se estaba generando con el botón **Render** del `.qmd`.
Ese botón solo crea `reporte_dengue.pptx` en la carpeta principal: no escribe
el Excel de tablas ni el control de calidad, y no copia nada a `salidas/`. Todo
eso lo hacía únicamente `generar_reporte.R`, que no se estaba corriendo. (Se
comprobó en la carpeta: `reporte_dengue.pptx` actualizado y `salidas/` vacía).

**Qué se cambió** (ahora funciona igual con Render o con Source):

- `_quarto.yml` (nuevo): convierte la carpeta en proyecto de Quarto para que,
  al terminar cada render, se ejecute `R/mover_a_salidas.R`.
- `R/mover_a_salidas.R` (nuevo): copia el PPTX recién generado a
  `salidas/SE45_2026_INFORME_SEMANAL_DENGUE_LRRL.pptx`. Si el archivo de
  destino está abierto en PowerPoint, avisa en la consola sin romper el render.
- `reporte_dengue.qmd` (chunk `preparar`): escribe en `salidas/` el Excel de
  tablas y el control de calidad, y deja el prefijo de la SE en
  `salidas/.prefijo_ultimo_render` para que el PPTX reciba el nombre correcto.
- `generar_reporte.R`: acepta que el informe ya esté en `salidas/` y se
  detiene con un mensaje claro si no llegó.

Tras generar, `reporte_dengue.pptx` sigue apareciendo en la carpeta principal
(RStudio lo abre desde ahí); la copia oficial es la de `salidas/`.

### 7. Zika y Chikungunya: filtro por año de toma de muestra en el título

El filtro de la tabla ya era por **año de la fecha de toma de muestra**
(2025 y 2026; ver cambio 2). Se verificó en el informe de la SE 45: solo
aparecen las filas 2025 y 2026. Lo que confundía era el título, que decía
"SE 01 – SE 45, 2026".

- Título nuevo: `DIAGNÓSTICO DIFERENCIAL: ZIKA Y CHIKUNGUNYA. AÑO DE TOMA DE
  MUESTRA 2025 – 2026 (corte 14.11.2026)`.
- Texto de la lámina: "Solo muestras con fecha de toma en 2025–2026".

### 8. Reporte de serotipos del virus dengue al final del informe

Sigue el modelo `REPORTE_SEROTIPOS_DE_DENGUE_LRRL_SE41.2026.pptx`.

**De dónde salen los datos.** No hace falta ningún archivo nuevo: las mismas
descargas de NetLab v2 traen el examen *"Presencia del ARN del virus dengue
1,2,3,4, por RT - PCR en tiempo real"*, y el serotipo viene escrito en el
resultado (`Positivo : Serotipo 3`). Se incluyen todos los laboratorios
(INS, CIETROP y LRRL), igual que el modelo. Se comprobó con el corte del
17/10/2026: da exactamente las cifras del modelo SE41 (DENV-1: 6, DENV-2: 16,
DENV-3: 764, negativos: 425, mismas cifras por SE, por distrito y por EESS).

**Láminas nuevas** (al final, después de Zika/Chikungunya y Oropouche/Mayaro):

1. Portada de sección: "VIGILANCIA MOLECULAR: IDENTIFICACIÓN DE LOS SEROTIPOS
   DEL VIRUS DENGUE EN LA REGIÓN LORETO", con la SE y el corte.
2. Distribución temporal: positivos por serotipo y SE de toma del año, texto
   automático (serotipo predominante, %, pico, serotipos esporádicos) y tabla
   "Datos acumulados" (% por serotipo en la SE del reporte y la anterior).
   - El gráfico comparativo con el año anterior (como el modelo, 2025 vs 2026)
     aparece solo si las descargas cubren al menos 40 semanas de ese año. Hoy
     solo hay 11 semanas de 2025, así que la lámina lo indica. Para activarlo,
     coloca las descargas NetLab v2 de 2025 en la carpeta nueva
     `datos/anio_anterior/`. Esas descargas también completan la fila 2025 de
     la tabla de Zika y Chikungunya; no cambian las cifras de dengue 2026.
3. Distribución geográfica: tabla por provincia y distrito (negativos, DENV-1,
   DENV-2, DENV-3, total; positivos en rojo) y texto con los serotipos de cada
   provincia.
4. Establecimientos notificantes de casos positivos en las últimas 4 SE: una
   fila por establecimiento con los positivos de cada SE, el serotipo y los
   negativos; se reparte en varias láminas si son más de 18 (en la SE 45 son
   34 establecimientos, 2 láminas).
   - Diferencia con el modelo: el modelo listaba cada SE por separado e
     incluía establecimientos sin positivos. Con los datos de la SE 45 eso
     daba 63 filas (4 láminas), así que se resumió por establecimiento.

**No se generan** (se siguen pegando a mano si se desean): los mapas de
distritos, la lámina de zonas fronterizas con datos de la OPS y la lámina final
de logos del modelo. DENV-4 aparece automáticamente si llega a registrarse.

**Archivos:**

- `R/06_serotipos.R` (nuevo): cálculo, textos, gráfico y tablas.
- `_serotipos.qmd` (nuevo): las láminas. El `_` inicial hace que Quarto no lo
  renderice solo; lo incluye `reporte_dengue.qmd` al final.
- `reporte_dengue.qmd`: `slide-level: 2` (necesario para la portada de
  sección), parámetro `dir_anterior` y chunk final `serotipos`.
- `R/00_config.R`: examen de serotipos, colores por serotipo, mínimo de
  semanas para comparar y fuente.
- `R/05_preparar.R`: calcula los serotipos; hojas `serotipos_SE`,
  `serotipos_distrito` y `serotipos_EESS` en el Excel de tablas; sección 8 en
  el control de calidad.
- `generar_reporte.R`: `DIR_ANTERIOR <- "datos/anio_anterior"`.
- `datos/anio_anterior/LEEME.txt` (nuevo).

### 9. Posición de las tablas en láminas generadas en bucle

Se descubrió que `flextable_to_rmd()` ignora los argumentos `ft.left` /
`ft.top` (solo lee las opciones del chunk); por eso la tabla por microred
quedaba en la posición por defecto. Nueva función `tabla_en_posicion()` en
`R/04_graficos_y_tablas.R`, usada en la tabla por microred y en la de
establecimientos de serotipos. Verificado: todas las tablas quedan dentro de
la lámina.

**Prueba completa:** el informe se generó aquí con **Render** y con **Source**
(`generar_reporte.R`); en ambos casos quedaron en `salidas/` el PPTX
`SE45_2026_INFORME_SEMANAL_DENGUE_LRRL.pptx` (13 láminas), el Excel de tablas
y el control de calidad, y el PPTX no tiene referencias rotas.
