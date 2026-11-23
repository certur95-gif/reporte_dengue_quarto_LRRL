# Reporte semanal de dengue en RStudio + Quarto · Unidad de Virología, LRRL

Genera el informe semanal (PPTX), el Excel de tablas y el control de calidad a
partir de las descargas de NetLab. Es el mismo criterio del proyecto en Python
(`reporte_dengue_lrrl`), reescrito en R.

## 1. El flujo en una imagen

```
datos/arbo_meses/*.xlsx   (NetLab v2 por mes, histórico)
datos/semanal/*.xlsx      (NetLab v2 de cada SE nueva)
datos/netlab_v1/*.xls     (Mayaro y Oropouche, opcional)
        │
        ▼   R/02  leer todo, normalizar fechas y resultados, quitar duplicados
        ▼   R/03  filtrar el universo (IgM/NS1, red LRRL, corte) y armar las tablas
        ▼   R/04  gráficos (ggplot2) y formato de tablas (flextable)
        │
        ├── reporte_dengue.qmd ──► salidas/SE44_2026_INFORME_SEMANAL_DENGUE_LRRL.pptx
        └── R/05 ────────────────► salidas/SE44_2026_TABLAS.xlsx
                                   salidas/SE44_2026_CONTROL_CALIDAD.txt
```

No hay base acumulada que mantener: **la carpeta de descargas es la base**. Cada
corrida vuelve a leer todos los Excel (son segundos) y retira los duplicados.

## 2. Instalación (una sola vez)

1. Instala **R 4.2 o superior** y **RStudio** (RStudio ya trae Quarto incluido).
2. Abre el proyecto con doble clic en `reporte_dengue_quarto.Rproj`.
3. En RStudio abre `R/instalar_paquetes.R` y pulsa **Source**. Necesita internet.

Si la PC del laboratorio no tiene internet: haz estos pasos en una PC con
internet y la misma versión de R, y copia la carpeta de librerías (la que
muestra `.libPaths()[1]`) a la misma ruta de la PC del laboratorio.

## 3. Dónde van los datos

| Carpeta | Qué va | De dónde sale |
|---|---|---|
| `datos/arbo_meses/` | `Ene_2026.xlsx` … `Nov_2026_SE_44.xlsx` | tu carpeta `arbo_meses` de Drive |
| `datos/semanal/` | la descarga de cada SE nueva | NetLab v2, cada semana |
| `datos/netlab_v1/` | `…MAYARO….xls`, `…OROPOUCHE….xls` | NetLab v1 |

Los archivos se leen tal como salen de NetLab (hoja `Registros`). No hace falta
agregar las columnas Año / SE ni tablas dinámicas. Si prefieres no copiar nada,
cambia las rutas en `generar_reporte.R` para que apunten a tu Drive, por ejemplo
`DIR_MENSUAL <- "G:/Mi unidad/Resultado SE/arbo_meses"`.

## 4. Rutina semanal

1. Descarga la semana de NetLab v2 y guárdala en `datos/semanal/`.
2. Abre `generar_reporte.R`, cambia `SE <- 45` y pulsa **Source**.
3. En `salidas/` revisa primero `…_CONTROL_CALIDAD.txt`, luego abre el PPTX.
4. Pega al final las láminas de serotipos de Biología Molecular (no salen de
   esta base) y ajusta los párrafos que quieras matizar.

Para rehacer una semana anterior basta volver a poner su número: la fecha de
corte deja fuera todo lo verificado después de ese sábado.

## 5. Criterios programados

- **Semana epidemiológica:** norma MINSA/CDC, de domingo a sábado; la SE 01 es
  la que contiene el 4 de enero (`lubridate::epiweek`). Cada corrida comprueba
  el calendario con fechas fijas y se detiene si algo no coincide.
- **Universo de dengue:** solo `Virus Dengue Ac. IgM` y `Virus Dengue Ag NS1`,
  resultados NEGATIVO / POSITIVO, sin los tres laboratorios destino ajenos a la
  red LRRL. Lo molecular queda fuera. Todo esto se edita en `R/00_config.R`.
- **Corte:** sábado de la SE (o la fecha que pongas en `CORTE`). No entra nada
  verificado después.
- **SE de cada muestra:** la de la fecha de colección (toma).
- **Duplicados:** misma muestra + mismo examen + misma fecha de verificación.
- **Lámina por establecimiento:** `SEMANAL_POR <- "coleccion"` cuenta las
  muestras tomadas en la SE (como el informe actual); `"verificacion"` cuenta
  las procesadas en la SE, identificadas por su SE de toma (como el script Python).
- **Zika / Chikungunya:** sale de la misma descarga v2, por fecha de toma.
- **Datos personales:** nombre, documento, dirección y teléfonos del paciente
  no se leen; no llegan ni al Excel de tablas ni al informe.

## 6. Qué archivo tocar para cada cosa

| Quiero… | Archivo |
|---|---|
| Cambiar la SE, el corte o las carpetas | `generar_reporte.R` |
| Reescribir un párrafo o un título | `reporte_dengue.qmd` (las cifras son `` `r ...` ``) |
| Agregar o quitar una lámina | `reporte_dengue.qmd` (cada `##` es una lámina) |
| Cambiar exámenes, laboratorios excluidos, colores, fuente | `R/00_config.R` |
| Cambiar un gráfico o el formato de las tablas | `R/04_graficos_y_tablas.R` |
| Poner logos, fondo y tipografía institucional | `plantilla/plantilla_lrrl.pptx` |

**Plantilla:** ábrela en PowerPoint, entra a *Vista → Patrón de diapositivas*,
pon ahí los logos y colores y guarda. No cambies los nombres de los diseños
(Title Slide, Title and Content, Two Content…): Quarto los busca por nombre. El
ancho de las columnas de las láminas con gráfico + texto lo define el diseño
*Two Content* de la plantilla.

**Posición de las tablas:** cada tabla lleva `ft.left` y `ft.top` (pulgadas
desde la esquina superior izquierda de la lámina) en las opciones de su bloque.

## 7. Límites conocidos

- La lectura de NetLab v1 (Mayaro / Oropouche) está portada del script Python
  y probada con un export simulado, no con uno real. Si el export real cambia
  de columnas, el mensaje de error dice cuáles faltan.
- Los gráficos del PPTX son imágenes, no gráficos nativos editables de PowerPoint.
- El IP va en su propio panel sobre las barras, no en un segundo eje.

## 8. Problemas frecuentes

| Mensaje | Qué hacer |
|---|---|
| `Abre primero el proyecto…` | Doble clic en `reporte_dengue_quarto.Rproj` y vuelve a pulsar Source |
| `No hay descargas .xlsx en…` | Copia las descargas a `datos/arbo_meses/` o corrige las rutas |
| `…no es una descarga de NetLab v2… Se omite` | Hay un Excel que no es descarga en la carpeta de datos; solo es un aviso |
| `Calendario de SE incorrecto…` | No debería ocurrir; avisa antes de publicar |
| El PPTX no se sobrescribe | Cierra el PPTX anterior en PowerPoint y vuelve a correr |
| Una tabla tapa el texto | Sube o baja su `ft.top` en `reporte_dengue.qmd` |
