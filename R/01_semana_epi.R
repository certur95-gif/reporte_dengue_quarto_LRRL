# =============================================================================
#  01 · SEMANA EPIDEMIOLÓGICA
#  Norma MINSA / CDC: semanas de domingo a sábado; la SE 01 es la semana que
#  contiene el 4 de enero. Es el mismo calendario de lubridate::epiweek().
# =============================================================================

# Domingo en que arranca la SE 01 del año epidemiológico dado
inicio_se01 <- function(anio) {
  cuatro <- as.Date(sprintf("%d-01-04", as.integer(anio)))
  cuatro - as.integer(format(cuatro, "%w"))        # %w: domingo = 0 ... sábado = 6
}

# Año epidemiológico y número de SE de un vector de fechas
semana_epi <- function(fecha) {
  fecha <- as.Date(fecha)
  data.frame(anio_se = as.integer(lubridate::epiyear(fecha)),
             se      = as.integer(lubridate::epiweek(fecha)))
}

# Domingo y sábado que delimitan una SE
rango_se <- function(anio, se) {
  ini <- inicio_se01(anio) + 7 * (as.integer(se) - 1)
  list(inicio = ini, fin = ini + 6)
}

etiqueta_se <- function(se) sprintf("SE %02d", as.integer(se))

# Pruebas fijas del calendario. Si algo no coincide, el reporte se detiene:
# es preferible no generar nada a publicar semanas corridas.
autotest_se <- function() {
  casos <- data.frame(
    fecha = as.Date(c("2026-01-04", "2026-01-10", "2026-01-11", "2026-08-30",
                      "2026-09-05", "2026-09-06", "2026-11-01", "2026-11-07",
                      "2025-12-28", "2026-01-03", "2024-12-29")),
    anio  = c(2026, 2026, 2026, 2026, 2026, 2026, 2026, 2026, 2025, 2025, 2025),
    se    = c(1, 1, 2, 35, 35, 36, 44, 44, 53, 53, 1)
  )
  obt <- semana_epi(casos$fecha)
  mal <- which(obt$anio_se != casos$anio | obt$se != casos$se)
  if (length(mal)) {
    stop("Calendario de SE incorrecto para: ",
         paste(format(casos$fecha[mal], "%d/%m/%Y"), collapse = ", "), call. = FALSE)
  }
  r <- rango_se(2026, 44)
  stopifnot(r$inicio == as.Date("2026-11-01"), r$fin == as.Date("2026-11-07"))
  invisible(TRUE)
}
