# =============================================================================
#  03 · UNIVERSO DEL REPORTE Y TABLAS
#  Aquí está todo el cálculo. El .qmd solo presenta lo que devuelven estas
#  funciones, así las cifras del texto, de las tablas y de los gráficos salen
#  siempre del mismo sitio.
# =============================================================================

# Cuenta negativos / positivos por los grupos que se indiquen
contar_neg_pos <- function(d, ...) {
  d |>
    dplyr::group_by(...) |>
    dplyr::summarise(NEGATIVO = sum(resultado_norm == "NEGATIVO"),
                     POSITIVO = sum(resultado_norm == "POSITIVO"), .groups = "drop") |>
    dplyr::mutate(Total = NEGATIVO + POSITIVO,
                  IP    = dplyr::if_else(Total > 0, POSITIVO / Total, NA_real_))
}

# --- Embudo: de la base cruda al universo serológico de dengue ------------------
universo_dengue <- function(base, anio, se_rep, corte) {
  embudo <- c("registros leídos, sin duplicados" = nrow(base))

  d <- dplyr::filter(base, is.na(f_ver) | f_ver <= corte)
  embudo[sprintf("verificados hasta el corte (%s)", format(corte, "%d/%m/%Y"))] <- nrow(d)

  d$tipo <- names(EXAMENES_DENGUE)[match(clave(d$examen), clave(EXAMENES_DENGUE))]
  d <- dplyr::filter(d, !is.na(tipo))
  embudo["serológicos de dengue IgM / NS1 (fuera lo molecular y otros virus)"] <- nrow(d)

  d <- dplyr::filter(d, !clave(lab) %in% clave(LABS_EXCLUIDOS))
  embudo["tras excluir laboratorios ajenos a la red LRRL"] <- nrow(d)

  no_validos <- dplyr::filter(d, !resultado_norm %in% c("NEGATIVO", "POSITIVO"))
  d <- dplyr::filter(d, resultado_norm %in% c("NEGATIVO", "POSITIVO"))
  embudo["con resultado NEGATIVO o POSITIVO"] <- nrow(d)

  d_anio <- dplyr::filter(d, anio_se == anio, se <= se_rep)
  embudo[sprintf("con fecha de toma entre la SE 01 y la SE %02d de %d", se_rep, anio)] <- nrow(d_anio)

  list(datos = d_anio, todos_los_anios = d, no_validos = no_validos, embudo = embudo)
}

# --- Lámina 2: pruebas e IP por SE de toma de muestra ---------------------------
tabla_por_se <- function(d, se_max) {
  contar_neg_pos(d, se) |>
    tidyr::complete(se = seq_len(se_max), fill = list(NEGATIVO = 0L, POSITIVO = 0L, Total = 0L)) |>
    dplyr::arrange(se) |>
    dplyr::mutate(SE = etiqueta_se(se), .before = 1)
}

# --- Lámina 3: resultados por tipo de prueba -----------------------------------
tabla_tipo_prueba <- function(d) {
  cuerpo <- contar_neg_pos(d, tipo, examen) |> dplyr::arrange(tipo)
  total  <- contar_neg_pos(d) |> dplyr::mutate(tipo = "Total", examen = "Total general")
  dplyr::bind_rows(cuerpo, total)
}

# --- Lámina 4: positivos por provincia y tipo de prueba ------------------------
tabla_provincia <- function(d) {
  pos <- dplyr::filter(d, resultado_norm == "POSITIVO")
  cuerpo <- pos |>
    dplyr::group_by(PROVINCIA = prov) |>
    dplyr::summarise(IgM = sum(tipo == "IgM"), NS1 = sum(tipo == "NS1"), .groups = "drop") |>
    dplyr::arrange(PROVINCIA)
  total <- dplyr::tibble(PROVINCIA = "Total general", IgM = sum(cuerpo$IgM), NS1 = sum(cuerpo$NS1))
  dplyr::bind_rows(cuerpo, total) |>
    dplyr::mutate(Total = IgM + NS1,
                  pct_IgM = dplyr::if_else(Total > 0, IgM / Total, NA_real_),
                  pct_NS1 = dplyr::if_else(Total > 0, NS1 / Total, NA_real_))
}

# --- Lámina 5: la SE del reporte por microred y establecimiento ----------------
#  por = "coleccion":    muestras TOMADAS en la SE del reporte (como el informe actual)
#  por = "verificacion": muestras PROCESADAS (verificadas) en la SE del reporte,
#                        identificadas por la SE en que se tomó cada muestra
tabla_semanal <- function(u, anio, se_rep, por = c("coleccion", "verificacion")) {
  por <- match.arg(por)
  sub <- if (por == "coleccion") {
    dplyr::filter(u$datos, se == se_rep)
  } else {
    dplyr::filter(u$todos_los_anios, anio_se_ver == anio, se_ver == se_rep)
  }
  if (!nrow(sub)) return(NULL)
  cuerpo <- contar_neg_pos(sub, anio_se, se, microred, eess) |>
    dplyr::arrange(anio_se, se, microred, eess) |>
    dplyr::mutate(SE = dplyr::if_else(anio_se == anio, sprintf("%d", se),
                                      sprintf("%d (%d)", se, anio_se))) |>
    dplyr::select(SE, `Micro Red` = microred, `Establecimiento de origen` = eess,
                  NEGATIVO, POSITIVO, Total, IP)
  total <- contar_neg_pos(sub) |>
    dplyr::mutate(SE = "Total general", `Micro Red` = "Total general",
                  `Establecimiento de origen` = "Total general")
  dplyr::bind_rows(cuerpo, total)
}

# --- Diagnóstico diferencial: periodo (año / trimestre / mes) x resultado -------
#  Abre el año del reporte en trimestres y el último trimestre en meses; después
#  una fila por tipo de prueba y el total.
tabla_periodos <- function(d, anio) {
  d <- dplyr::filter(d, !is.na(f_col),
                     resultado_norm %in% c("INDETERMINADO", "NEGATIVO", "POSITIVO"))
  if (!nrow(d)) return(NULL)
  d$anio_cal <- as.integer(format(d$f_col, "%Y"))
  d$mes      <- as.integer(format(d$f_col, "%m"))
  d$trim     <- (d$mes - 1L) %/% 3L + 1L

  fila <- function(sub, etiqueta, nivel) {
    dplyr::tibble(Periodo = etiqueta, nivel = nivel,
                  INDETERMINADO = sum(sub$resultado_norm == "INDETERMINADO"),
                  NEGATIVO = sum(sub$resultado_norm == "NEGATIVO"),
                  POSITIVO = sum(sub$resultado_norm == "POSITIVO"), Total = nrow(sub))
  }
  filas <- list()
  for (a in sort(unique(d$anio_cal))) {
    sa <- d[d$anio_cal == a, ]
    filas <- c(filas, list(fila(sa, as.character(a), 0L)))
    if (a != anio) next
    for (t in sort(unique(sa$trim))) {
      st <- sa[sa$trim == t, ]
      filas <- c(filas, list(fila(st, sprintf("Trim. %d", t), 1L)))
      if (t == max(sa$trim)) {
        for (m in sort(unique(st$mes))) filas <- c(filas, list(fila(st[st$mes == m, ], MESES[m], 2L)))
      }
    }
  }
  for (p in sort(unique(d$prueba))) filas <- c(filas, list(fila(d[d$prueba == p, ], p, 0L)))
  out <- dplyr::bind_rows(c(filas, list(fila(d, "Total general", 0L))))
  if (sum(out$INDETERMINADO) == 0) out$INDETERMINADO <- NULL
  out
}

# Listado de positivos del diferencial con su SE de toma
tabla_positivos <- function(d) {
  pos <- dplyr::filter(d, resultado_norm == "POSITIVO")
  if (!nrow(pos)) return(NULL)
  pos |>
    dplyr::arrange(anio_se, se) |>
    dplyr::transmute(SE = sprintf("%s-%d", etiqueta_se(se), anio_se),
                     Establecimiento = sub('\\s*"[^"]*"\\s*$', "", eess), Prueba = prueba)
}

# --- Cifras para redactar los textos -------------------------------------------
construir_campos <- function(t_se, t_tp, t_prov, t_sem, anio, se) {
  act <- t_se[t_se$se == se, ]
  ant <- t_se[t_se$se == se - 1, ]
  tot <- t_tp[t_tp$tipo == "Total", ]
  # La SE en curso todavía está incompleta: no compite por el máximo IP del año
  previas <- t_se[t_se$se < se & t_se$Total > 0, ]
  maxip   <- if (nrow(previas)) previas[which.max(previas$IP), ] else act
  cuerpo  <- t_tp[t_tp$tipo != "Total", ]
  mayor   <- cuerpo[which.max(cuerpo$Total), ]
  prov    <- t_prov[t_prov$PROVINCIA != "Total general", ]
  prov    <- prov[order(-prov$Total), ]
  ptotal  <- t_prov[t_prov$PROVINCIA == "Total general", ]
  ip_tipo <- function(t) { f <- cuerpo[cuerpo$tipo == t, ]; if (nrow(f)) pct(f$IP) else "s/d" }

  campos <- list(
    anio = anio, se = se, se_txt = etiqueta_se(se), se_prev_txt = etiqueta_se(se - 1),
    total_se = act$Total, pos_se = act$POSITIVO, ip_se = pct(act$IP),
    total_prev = if (nrow(ant)) ant$Total else NA, pos_prev = if (nrow(ant)) ant$POSITIVO else NA,
    ip_prev = if (nrow(ant)) pct(ant$IP) else "",
    total_acum = tot$Total, pos_acum = tot$POSITIVO, ip_acum = pct(tot$IP),
    se_max_ip = maxip$SE, ip_max = pct(maxip$IP), pos_max_ip = maxip$POSITIVO,
    prueba_mayor = mayor$tipo, total_mayor = mayor$Total, pos_mayor = mayor$POSITIVO,
    pct_mayor = pct(mayor$Total / tot$Total), ip_igm = ip_tipo("IgM"), ip_ns1 = ip_tipo("NS1"),
    n_prov = nrow(prov), pct_ns1_total = pct(ptotal$pct_NS1),
    provincias = prov
  )
  # Tendencia del IP respecto a la semana anterior (en puntos porcentuales)
  campos$dif_ip <- if (nrow(ant) && !is.na(ant$IP) && !is.na(act$IP)) 100 * (act$IP - ant$IP) else NA_real_
  campos$tendencia <- if (is.na(campos$dif_ip)) "sin semana previa para comparar"
                 else if (abs(campos$dif_ip) < 1) "se mantiene estable"
                 else if (campos$dif_ip > 0) sprintf("sube %.1f puntos porcentuales", campos$dif_ip)
                 else sprintf("baja %.1f puntos porcentuales", abs(campos$dif_ip))
  if (!is.null(t_sem)) {
    cuerpo_sem <- t_sem[t_sem$SE != "Total general", ]
    tt <- t_sem[t_sem$SE == "Total general", ]
    campos$sem_total <- tt$Total; campos$sem_pos <- tt$POSITIVO; campos$sem_ip <- pct(tt$IP)
    campos$sem_n_eess <- dplyr::n_distinct(cuerpo_sem$`Establecimiento de origen`)
    campos$sem_n_se_toma <- dplyr::n_distinct(cuerpo_sem$SE)
  }
  campos
}
