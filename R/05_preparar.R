# =============================================================================
#  05 · PREPARAR EL REPORTE Y ESCRIBIR LAS SALIDAS DE CONTROL
#  preparar_reporte() hace todo el cálculo y devuelve una lista. La usan el
#  .qmd (para el informe) y generar_reporte.R (para el Excel y el control de
#  calidad), así que ambos muestran exactamente las mismas cifras.
# =============================================================================

preparar_reporte <- function(anio, se, corte = NULL, dirs_v2, dir_v1 = NULL,
                             semanal_por = "coleccion") {
  autotest_se()
  anio  <- as.integer(anio); se <- as.integer(se)
  rango <- rango_se(anio, se)
  corte <- if (is.null(corte) || is.na(corte) || !nzchar(as.character(corte))) rango$fin
           else as.Date(as.character(corte))

  # 1. Leer todas las descargas y quitar duplicados
  cruda <- leer_descargas_v2(dirs_v2)
  archivos <- cruda |>
    dplyr::group_by(Archivo = archivo_origen) |>
    dplyr::summarise(Registros = dplyr::n(),
                     `Verificación desde` = min(f_ver, na.rm = TRUE),
                     `Verificación hasta` = max(f_ver, na.rm = TRUE), .groups = "drop")
  dd   <- deduplicar(cruda)
  base <- dd$base

  # 2. Universo serológico de dengue y tablas
  u <- universo_dengue(base, anio, se, corte)
  if (!nrow(u$datos)) {
    stop(sprintf("No hay resultados IgM/NS1 con toma en %d hasta la SE %02d. ", anio, se),
         "Revisa que las descargas estén en la carpeta de datos.", call. = FALSE)
  }
  t_se   <- tabla_por_se(u$datos, se)
  t_tp   <- tabla_tipo_prueba(u$datos)
  t_prov <- tabla_provincia(u$datos)
  t_sem  <- tabla_semanal(u, anio, se, por = semanal_por)

  # 3. Diferencial que viene en la misma descarga: Zika y Chikungunya
  # [Cambio 17.11.2026] Solo entran las muestras tomadas desde el año
  # (anio - DIFERENCIAL_ANIOS_PREVIOS); en 2026 eso es 2025 y 2026. El filtro va
  # aquí y no en la tabla para que la tabla, el texto de la lámina y la hoja
  # zika_chik del Excel muestren las mismas cifras.
  anio_desde <- anio - DIFERENCIAL_ANIOS_PREVIOS
  zc <- base |>
    dplyr::filter(is.na(f_ver) | f_ver <= corte, !is.na(f_col), f_col <= corte,
                  as.integer(format(f_col, "%Y")) >= anio_desde,
                  grepl(PATRON_ZIKA_CHIK, examen, ignore.case = TRUE)) |>
    dplyr::mutate(prueba = examen,
                  virus  = dplyr::if_else(grepl("zika", examen, ignore.case = TRUE), "Zika", "Chikungunya"))
  zika_chik <- if (nrow(zc)) list(
    tabla   = tabla_periodos(zc, anio),
    resumen = zc |> dplyr::group_by(virus) |>
      dplyr::summarise(POSITIVO = sum(resultado_norm == "POSITIVO"),
                       INDETERMINADO = sum(resultado_norm == "INDETERMINADO"),
                       NEGATIVO = sum(resultado_norm == "NEGATIVO"), .groups = "drop")
  ) else NULL

  # 4. Diferencial de NetLab v1: Mayaro y Oropouche (si están los export)
  leer_v1 <- function(patron) {
    f <- if (is.null(dir_v1)) NA_character_ else archivo_mas_reciente(dir_v1, patron)
    if (is.na(f)) return(NULL)
    d <- leer_netlab_v1(f)
    d <- dplyr::filter(d, !is.na(f_col), f_col <= corte)
    list(archivo = basename(f), tabla = tabla_periodos(d, anio), positivos = tabla_positivos(d),
         sin_resultado = sum(!d$resultado_norm %in% c("INDETERMINADO", "NEGATIVO", "POSITIVO")))
  }
  mayaro    <- leer_v1("MAYARO.*\\.xls$")
  oropouche <- leer_v1("OROP.*\\.xls$")

  # 4b. [Nuevo 17.11.2026] Serotipos del virus dengue (RT-PCR), R/06_serotipos.R
  serotipos <- preparar_serotipos(base, anio, se, corte)

  # 5. Controles de integridad
  sero <- dplyr::filter(base, clave(examen) %in% clave(EXAMENES_DENGUE))
  varias_fechas <- sero |>
    dplyr::distinct(muestra, examen, f_ver) |>
    dplyr::count(muestra, examen) |>
    dplyr::filter(n > 1)
  integridad <- c(
    "sin fecha de colección"                        = sum(is.na(sero$f_col)),
    "sin fecha de verificación"                     = sum(is.na(sero$f_ver)),
    "demora colección -> verificación > 60 días"    = sum(sero$f_ver - sero$f_col > 60, na.rm = TRUE),
    "fecha de colección posterior a la verificación" = sum(sero$f_col > sero$f_ver, na.rm = TRUE),
    "microred vacía"                                = sum(is.na(sero$microred) | sero$microred == ""),
    "muestra + examen con más de una fecha de verificación" = nrow(varias_fechas)
  )

  list(
    anio = anio, se = se, corte = corte, rango = rango, semanal_por = semanal_por,
    archivos = archivos, n_leidos = nrow(cruda), duplicados = dd$duplicados,
    embudo = u$embudo, no_validos = u$no_validos, integridad = integridad,
    tablas = list(por_se = t_se, tipo_prueba = t_tp, provincia = t_prov, semanal = t_sem),
    campos = construir_campos(t_se, t_tp, t_prov, t_sem, anio, se),
    zika_chik = zika_chik, mayaro = mayaro, oropouche = oropouche,
    serotipos = serotipos
  )
}

# Prefijo común de los archivos de salida: "SE44_2026"
prefijo_salida <- function(r) sprintf("SE%02d_%d", r$se, r$anio)

# Excel con todas las tablas + TXT de control de calidad
escribir_salidas <- function(r, carpeta = "salidas") {
  dir.create(carpeta, showWarnings = FALSE, recursive = TRUE)
  pre <- file.path(carpeta, prefijo_salida(r))
  sin_nulos <- function(x) x[!vapply(x, is.null, logical(1))]

  hojas <- sin_nulos(list(
    por_SE        = r$tablas$por_se,
    tipo_prueba   = r$tablas$tipo_prueba,
    provincia     = r$tablas$provincia,
    semana_EESS   = r$tablas$semanal,
    zika_chik     = r$zika_chik$tabla,
    mayaro        = r$mayaro$tabla,
    oropouche     = r$oropouche$tabla,
    # [Nuevo 17.11.2026] serotipos
    serotipos_SE       = if (!is.null(r$serotipos)) tidyr::pivot_wider(r$serotipos$por_se,
                           names_from = serotipo, values_from = n, values_fill = 0L),
    serotipos_distrito = r$serotipos$distrito,
    serotipos_EESS     = r$serotipos$eess,
    archivos      = r$archivos,
    duplicados    = r$duplicados[, c("muestra", "examen", "f_col", "f_ver", "archivo_origen")],
    no_contabilizados = r$no_validos[, c("muestra", "examen", "resultado", "f_col", "f_ver", "eess")]
  ))
  writexl::write_xlsx(hojas, paste0(pre, "_TABLAS.xlsx"))

  k <- r$campos
  linea <- strrep("=", 76)
  bloque <- function(v) sprintf("   %7s  %s", format(unname(v), big.mark = ","), names(v))
  txt <- c(
    linea,
    sprintf(" CONTROL DE CALIDAD - REPORTE SEMANAL DE DENGUE | SE %02d - %d", r$se, r$anio),
    sprintf(" Generado: %s", format(Sys.time(), "%d/%m/%Y %H:%M")),
    linea, "",
    "1. PARÁMETROS",
    sprintf("   Semana epidemiológica ... SE %02d de %d (%s al %s)", r$se, r$anio,
            format(r$rango$inicio, "%d/%m/%Y"), format(r$rango$fin, "%d/%m/%Y")),
    sprintf("   Fecha de corte .......... %s (no entra nada verificado después)", format(r$corte, "%d/%m/%Y")),
    sprintf("   Lámina semanal por ...... fecha de %s",
            if (r$semanal_por == "coleccion") "colección (toma de muestra)" else "verificación (procesamiento)"), "",
    "2. ARCHIVOS LEÍDOS (revisa que no falte ningún mes ni semana)",
    sprintf("   %-34s %7s   verificados del %s al %s", r$archivos$Archivo,
            format(r$archivos$Registros, big.mark = ","),
            format(r$archivos$`Verificación desde`, "%d/%m/%Y"),
            format(r$archivos$`Verificación hasta`, "%d/%m/%Y")),
    sprintf("   Total leído: %s registros; duplicados retirados (descargas traslapadas): %s",
            format(r$n_leidos, big.mark = ","), format(nrow(r$duplicados), big.mark = ",")), "",
    "3. EMBUDO DE FILTRADO (de lo leído al universo del reporte)",
    bloque(r$embudo), "",
    "4. RESULTADOS NO CONTABILIZADOS (IgM / NS1 con resultado distinto de NEGATIVO / POSITIVO)",
    if (nrow(r$no_validos)) bloque(table(r$no_validos$resultado_norm)) else "   ninguno", "",
    "5. INTEGRIDAD DE LOS DATOS (registros IgM / NS1)",
    bloque(r$integridad), "",
    "6. CIFRAS PUBLICADAS",
    sprintf("   Acumulado SE 01 - SE %02d: %s pruebas, %s positivos, IP %s", r$se,
            format(k$total_acum, big.mark = ","), format(k$pos_acum, big.mark = ","), k$ip_acum),
    sprintf("   %s (por SE de toma): %s pruebas, %s positivos, IP %s", k$se_txt,
            k$total_se, k$pos_se, k$ip_se),
    sprintf("   %s: %s pruebas, %s positivos, IP %s", k$se_prev_txt, k$total_prev, k$pos_prev, k$ip_prev),
    "   Recuerda: las SE anteriores suben de denominador cuando entran muestras de",
    "   toma retrospectiva. Es esperado, no un error.", "",
    "7. DIAGNÓSTICO DIFERENCIAL",
    sprintf("   Zika / Chikungunya (NetLab v2): %s",
            if (is.null(r$zika_chik)) "sin registros en las descargas" else "incluido"),
    sprintf("   Mayaro (NetLab v1): %s",
            if (is.null(r$mayaro)) "no se encontró el export; la lámina se omite" else r$mayaro$archivo),
    sprintf("   Oropouche (NetLab v1): %s",
            if (is.null(r$oropouche)) "no se encontró el export; la lámina se omite" else r$oropouche$archivo),
    "",
    "8. SEROTIPOS (RT-PCR dengue 1,2,3,4)",
    if (is.null(r$serotipos)) "   sin registros de RT-PCR en las descargas; las láminas se omiten" else c(
      sprintf("   %d (SE 01 - SE %02d): %s positivos, %s negativos", r$anio, r$se,
              format(r$serotipos$campos$n_pos, big.mark = ","), format(r$serotipos$campos$n_neg, big.mark = ",")),
      sprintf("   %s: %s", names(r$serotipos$campos$n), r$serotipos$campos$n),
      sprintf("   Comparación con %d: %s", r$anio - 1L,
              if (r$serotipos$hay_anterior) sprintf("sí (%d semanas con datos)", r$serotipos$semanas_anterior)
              else sprintf("no (solo %d semanas con datos; pon la descarga de %d en datos/anio_anterior/)",
                           r$serotipos$semanas_anterior, r$anio - 1L))),
    "", linea
  )
  writeLines(enc2utf8(txt), paste0(pre, "_CONTROL_CALIDAD.txt"), useBytes = TRUE)
  invisible(pre)
}
