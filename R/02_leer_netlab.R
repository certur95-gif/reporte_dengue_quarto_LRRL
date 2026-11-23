# =============================================================================
#  02 · LECTURA DE LAS DESCARGAS DE NETLAB
#  - NetLab v2 (.xlsx, hoja "Registros"): dengue, zika, chikungunya
#  - NetLab v1 (.xls que en realidad es una tabla HTML): mayaro, oropouche
# =============================================================================

# Clave robusta para comparar nombres: sin tildes, sin espacios, en minúsculas.
# "Fecha Colección" y "fecha coleccion" dan la misma clave.
clave <- function(x) {
  x <- stringi::stri_trans_general(as.character(x), "Latin-ASCII")
  gsub("[^a-z0-9]", "", tolower(x))
}

# ' NEGATIVO - ' -> 'NEGATIVO'   ' Negativo - ' -> 'NEGATIVO'
# 'Positivo - Positivo : Serotipo 3 - 21.36 - ' -> 'POSITIVO'
norm_resultado <- function(x) {
  s <- toupper(trimws(stringi::stri_trans_general(as.character(x), "Latin-ASCII")))
  dplyr::case_when(
    is.na(s) | s == ""             ~ "SIN RESULTADO",
    startsWith(s, "INDETERMINADO") ~ "INDETERMINADO",
    startsWith(s, "NEGATIVO")      ~ "NEGATIVO",
    startsWith(s, "POSITIVO")      ~ "POSITIVO",
    startsWith(s, "NO REACTIVO")   ~ "NO REACTIVO",
    startsWith(s, "REACTIVO")      ~ "REACTIVO",
    TRUE                           ~ trimws(sub("-.*$", "", s))
  )
}

# Convierte a fecha tolerando las tres formas en que llegan las descargas:
#   texto "03/09/2026" (descarga tal cual), texto con hora "03/09/2026 12:00:00 a.m."
#   y número de serie de Excel (cuando el archivo se abrió y se guardó en Excel).
a_fecha <- function(x) {
  if (inherits(x, c("Date", "POSIXct"))) return(as.Date(x))
  x   <- trimws(as.character(x))
  out <- rep(as.Date(NA), length(x))
  serial <- !is.na(x) & grepl("^[0-9]{5}(\\.[0-9]+)?$", x)
  out[serial] <- as.Date(floor(as.numeric(x[serial])), origin = "1899-12-30")
  texto <- !is.na(x) & x != "" & !serial
  if (any(texto)) {
    solo_fecha <- sub("[ T].*$", "", x[texto])
    out[texto] <- as.Date(lubridate::parse_date_time(solo_fecha, orders = c("dmY", "Ymd"),
                                                     quiet = TRUE))
  }
  out
}

# Columnas que se conservan de NetLab v2. A propósito NO se leen nombre,
# documento, dirección ni teléfonos del paciente: el reporte no los necesita.
COLS_V2 <- c(
  orden = "Codigo De Orden", muestra = "Codigo de Muestra",
  examen = "Nombre de Examen", resultado = "Resultado",
  f_col = "Fecha Colección", f_rec = "Fecha Recepción ROM", f_ver = "Fecha Verificación",
  lab = "Laboratorio Destino", eess = "Establecimiento de Origen",
  microred = "Micro Red EE.SS Origen", red = "Red EE.SS Origen",
  dist = "Distrito EE.SS Origen", prov = "Provincia EE.SS Origen",
  dpto = "Departamento EE.SS Origen", estatus = "Estatus Resultado",
  edad = "Edad", tipo_muestra = "Tipo de Muestra"
)
COLS_CRITICAS <- c("muestra", "examen", "resultado", "f_col", "f_ver", "lab", "eess")

# Lee UNA descarga de NetLab v2 y devuelve columnas canónicas.
# Si el archivo no es una descarga (p. ej. un Excel de tablas dinámicas) devuelve NULL.
leer_netlab_v2 <- function(ruta) {
  hojas <- readxl::excel_sheets(ruta)
  hoja  <- if ("Registros" %in% hojas) "Registros" else hojas[1]
  crudo <- readxl::read_excel(ruta, sheet = hoja, col_types = "text",
                              .name_repair = "minimal")
  pos   <- match(clave(COLS_V2), clave(names(crudo)))
  names(pos) <- names(COLS_V2)
  if (anyNA(pos[COLS_CRITICAS])) {
    warning(basename(ruta), ": no es una descarga de NetLab v2 (faltan columnas: ",
            paste(COLS_V2[COLS_CRITICAS][is.na(pos[COLS_CRITICAS])], collapse = ", "),
            "). Se omite.", call. = FALSE)
    return(NULL)
  }
  pos <- pos[!is.na(pos)]
  d   <- as.data.frame(crudo[, pos], stringsAsFactors = FALSE)
  names(d) <- names(pos)

  for (col in intersect(c("f_col", "f_rec", "f_ver"), names(d))) d[[col]] <- a_fecha(d[[col]])
  for (col in setdiff(names(d), c("f_col", "f_rec", "f_ver"))) d[[col]] <- trimws(d[[col]])
  d <- d[!is.na(d$muestra) & d$muestra != "", , drop = FALSE]

  d$resultado_norm <- norm_resultado(d$resultado)
  toma <- semana_epi(d$f_col); d$anio_se     <- toma$anio_se; d$se     <- toma$se
  veri <- semana_epi(d$f_ver); d$anio_se_ver <- veri$anio_se; d$se_ver <- veri$se
  d$archivo_origen <- basename(ruta)
  tibble::as_tibble(d)
}

# Lee TODAS las descargas .xlsx de una o más carpetas y las apila.
leer_descargas_v2 <- function(carpetas) {
  carpetas <- carpetas[dir.exists(carpetas)]
  archivos <- unlist(lapply(carpetas, list.files, pattern = "\\.xlsx$",
                            full.names = TRUE, ignore.case = TRUE))
  archivos <- archivos[!startsWith(basename(archivos), "~$")]   # temporales de Excel abierto
  if (!length(archivos)) {
    stop("No hay descargas .xlsx en: ", paste(carpetas, collapse = ", "), call. = FALSE)
  }
  partes <- lapply(archivos, leer_netlab_v2)
  names(partes) <- basename(archivos)
  partes <- partes[!vapply(partes, is.null, logical(1))]
  if (!length(partes)) stop("Ningún archivo tenía el formato de NetLab v2.", call. = FALSE)
  dplyr::bind_rows(partes)
}

# Una misma muestra + examen + fecha de verificación cargada dos veces es un
# duplicado: pasa cuando dos descargas se traslapan (mes completo + semana).
CLAVE_DEDUP <- c("muestra", "examen", "f_ver")
deduplicar <- function(base) {
  dup <- duplicated(base[, CLAVE_DEDUP])
  list(base = base[!dup, , drop = FALSE], duplicados = base[dup, , drop = FALSE])
}

# -----------------------------------------------------------------------------
#  NetLab v1 (Mayaro / Oropouche). El ".xls" que exporta es una tabla HTML.
#  Portado del script Python: las columnas de resultado son las que vienen
#  después de "iNumProceso"; cada fila tiene resultado en una sola de ellas.
# -----------------------------------------------------------------------------
leer_netlab_v1 <- function(ruta) {
  html <- tryCatch(rvest::read_html(ruta),
                   error = function(e) rvest::read_html(ruta, encoding = "windows-1252"))
  tablas <- rvest::html_table(html, convert = FALSE)
  if (!length(tablas)) stop(basename(ruta), ": no contiene ninguna tabla.", call. = FALSE)
  df <- as.data.frame(tablas[[which.max(vapply(tablas, nrow, integer(1)))]],
                      stringsAsFactors = FALSE, check.names = FALSE)
  if (!"FechaMuestra" %in% trimws(names(df)) && "FechaMuestra" %in% trimws(unlist(df[1, ]))) {
    names(df) <- unlist(df[1, ]); df <- df[-1, , drop = FALSE]   # encabezado en la 1.ª fila
  }
  names(df) <- trimws(names(df))
  if (!all(c("FechaMuestra", "iNumProceso") %in% names(df))) {
    stop(basename(ruta), ": no se reconocen las columnas del export de NetLab v1 ",
         "(se esperaban 'FechaMuestra' e 'iNumProceso').", call. = FALSE)
  }
  despues  <- names(df)[seq_along(names(df)) > match("iNumProceso", names(df))]
  res_cols <- despues[!clave(despues) %in% clave(c("Fecha de resultado", "Observaciones"))]

  valores <- as.matrix(df[, res_cols, drop = FALSE])
  valores[is.na(valores) | trimws(valores) == ""] <- NA
  primera <- apply(valores, 1, function(f) which(!is.na(f))[1])
  out <- tibble::tibble(
    f_col     = a_fecha(df$FechaMuestra),
    prueba    = res_cols[primera],
    resultado = valores[cbind(seq_len(nrow(valores)), primera)],
    eess      = if ("NombreRenipress" %in% names(df)) df$NombreRenipress
                else if ("Establecimiento" %in% names(df)) df$Establecimiento else NA_character_
  )
  out$resultado_norm <- norm_resultado(out$resultado)
  toma <- semana_epi(out$f_col); out$anio_se <- toma$anio_se; out$se <- toma$se
  out$archivo_origen <- basename(ruta)
  out
}

# Devuelve el archivo más reciente de la carpeta cuyo nombre calza con el patrón
archivo_mas_reciente <- function(carpeta, patron) {
  if (!dir.exists(carpeta)) return(NA_character_)
  f <- list.files(carpeta, pattern = patron, full.names = TRUE, ignore.case = TRUE)
  f <- f[!startsWith(basename(f), "~$")]
  if (!length(f)) return(NA_character_)
  f[which.max(file.mtime(f))]
}
