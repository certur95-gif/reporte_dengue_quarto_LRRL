# =============================================================================
#  REPORTE SEMANAL DE DENGUE · Unidad de Virología, LRRL
#  Abre el proyecto (reporte_dengue_quarto.Rproj), abre este archivo y pulsa
#  "Source". Deja en salidas/ el PPTX, el Excel de tablas y el control de calidad.
# =============================================================================

# --- 1. LO ÚNICO QUE CAMBIAS CADA SEMANA --------------------------------------
ANIO  <- 2026
SE    <- 45            # [Cambio 17.11.2026] antes 44
CORTE <- NULL            # NULL = sábado de la SE. O una fecha: "2026-11-07"

# --- 2. CONFIGURACIÓN (se define una sola vez) --------------------------------
DIR_MENSUAL <- "datos/arbo_meses"     # descargas NetLab v2 por mes (Ene_2026.xlsx ...)
DIR_SEMANAL <- "datos/semanal"        # descarga NetLab v2 de cada SE nueva
DIR_V1      <- "datos/netlab_v1"      # export NetLab v1 de MAYARO y OROPOUCHE (.xls)
DIR_ANTERIOR <- "datos/anio_anterior" # [Nuevo 17.11.2026] NetLab v2 del año anterior
                                      # (opcional): activa la comparación de serotipos
SEMANAL_POR <- "coleccion"            # lámina por EESS: "coleccion" (muestras tomadas
                                      # en la SE) o "verificacion" (procesadas en la SE)

# --- 3. DE AQUÍ PARA ABAJO NO HACE FALTA TOCAR NADA ---------------------------
if (!file.exists("reporte_dengue.qmd")) {
  stop("Abre primero el proyecto con doble clic en reporte_dengue_quarto.Rproj", call. = FALSE)
}
invisible(lapply(list.files("R", pattern = "^0.*\\.R$", full.names = TRUE), source, encoding = "UTF-8"))

# 3.1 Cálculo + Excel de tablas + control de calidad
r   <- preparar_reporte(ANIO, SE, CORTE, c(DIR_MENSUAL, DIR_SEMANAL, DIR_ANTERIOR), DIR_V1, SEMANAL_POR)
pre <- escribir_salidas(r, "salidas")

# 3.2 Informe PPTX: Quarto ejecuta reporte_dengue.qmd con los parámetros de esta semana
archivo    <- paste0(prefijo_salida(r), "_INFORME_SEMANAL_DENGUE_LRRL.pptx")
parametros <- list(anio = ANIO, se = SE, corte = format(r$corte, "%Y-%m-%d"),
                   dir_mensual = DIR_MENSUAL, dir_semanal = DIR_SEMANAL,
                   dir_v1 = DIR_V1, dir_anterior = DIR_ANTERIOR, semanal_por = SEMANAL_POR)
if (requireNamespace("quarto", quietly = TRUE)) {
  quarto::quarto_render("reporte_dengue.qmd", output_file = archivo,
                        execute_params = parametros, as_job = FALSE)
} else {
  # Sin el paquete 'quarto': la misma orden por línea de comandos
  yml <- tempfile(fileext = ".yml")
  yaml::write_yaml(parametros, yml)
  estado <- system2("quarto", c("render", "reporte_dengue.qmd", "--execute-params", shQuote(yml),
                                "--output", shQuote(archivo)))
  if (estado != 0) stop("Quarto no pudo generar el informe. Instala el paquete: install.packages('quarto')", call. = FALSE)
}
# [Cambio 17.11.2026] Mover el informe a salidas/ con el nombre de la SE
# (p. ej. salidas/SE45_2026_INFORME_SEMANAL_DENGUE_LRRL.pptx).
# Normalmente ya lo copió R/mover_a_salidas.R al terminar Quarto; aquí solo se
# asegura y se borra la copia suelta de la carpeta principal.
destino <- file.path("salidas", archivo)
if (file.exists(archivo)) {
  if (file.exists(destino) && !suppressWarnings(file.remove(destino))) {
    stop("No se pudo reemplazar ", destino, ". Ciérralo en PowerPoint y vuelve a pulsar Source.", call. = FALSE)
  }
  if (!file.copy(archivo, destino)) stop("No se pudo copiar el informe a salidas/.", call. = FALSE)
  invisible(file.remove(archivo))
}
if (!file.exists(destino)) {
  stop("El informe no llegó a ", destino, ". Revisa los mensajes de Quarto de arriba.", call. = FALSE)
}

message("\nListo. Revisa primero el control de calidad:\n  ", pre, "_CONTROL_CALIDAD.txt\n  ",
        pre, "_TABLAS.xlsx\n  ", destino)
