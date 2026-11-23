# =============================================================================
#  [Cambio 17.11.2026] Lo ejecuta Quarto solo, después de cada render
#  (ver _quarto.yml). No hace falta abrirlo ni correrlo a mano.
#
#  Copia el PPTX recién generado a salidas/ con el nombre de la semana:
#      salidas/SE45_2026_INFORME_SEMANAL_DENGUE_LRRL.pptx
#  El prefijo (SE45_2026) lo deja el propio reporte_dengue.qmd en
#  salidas/.prefijo_ultimo_render, así que siempre coincide con la SE usada.
#  Si algo falla avisa en la consola, pero nunca rompe el render.
# =============================================================================
tryCatch({
  marca <- file.path("salidas", ".prefijo_ultimo_render")
  if (!file.exists(marca)) stop("no se encontró ", marca)
  prefijo <- trimws(readLines(marca, warn = FALSE, encoding = "UTF-8")[1])
  nombre  <- paste0(prefijo, "_INFORME_SEMANAL_DENGUE_LRRL.pptx")
  destino <- file.path("salidas", nombre)

  # Archivos que Quarto acaba de generar (uno por línea) + los nombres posibles
  generados <- strsplit(Sys.getenv("QUARTO_PROJECT_OUTPUT_FILES"), "\n", fixed = TRUE)[[1]]
  candidatos <- unique(c(generados[grepl("\\.pptx$", generados, ignore.case = TRUE)],
                         "reporte_dengue.pptx", nombre))
  candidatos <- candidatos[file.exists(candidatos)]
  candidatos <- candidatos[normalizePath(candidatos, mustWork = FALSE) !=
                           normalizePath(destino, mustWork = FALSE)]
  if (!length(candidatos)) stop("Quarto no dejó ningún .pptx en la carpeta principal")
  origen <- candidatos[which.max(file.mtime(candidatos))]   # el más reciente

  if (file.exists(destino) && !suppressWarnings(file.remove(destino))) {
    stop(destino, " está abierto en PowerPoint. Ciérralo y vuelve a generar el reporte")
  }
  if (!file.copy(origen, destino)) stop("no se pudo copiar ", origen, " a ", destino)
  message("\n>> Informe guardado en: ", destino, "\n")
}, error = function(e) {
  message("\n>> AVISO: el informe NO se copió a salidas/: ", conditionMessage(e), "\n")
})
