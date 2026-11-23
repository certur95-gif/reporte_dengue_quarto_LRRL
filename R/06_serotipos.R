# =============================================================================
#  06 · SEROTIPOS DEL VIRUS DENGUE (RT-PCR)            [Nuevo 17.11.2026]
#  Láminas finales del informe, siguiendo el modelo "REPORTE SEROTIPOS DE
#  DENGUE LRRL SE41.2026". Los datos salen de las MISMAS descargas de NetLab v2
#  (examen "Presencia del ARN del virus dengue 1,2,3,4, por RT - PCR en tiempo
#  real"); el serotipo se lee del texto del resultado ("Positivo : Serotipo 3").
#  Se comprobó que con el corte 17/10/2026 da exactamente las cifras del modelo
#  SE41 (DENV-1: 6, DENV-2: 16, DENV-3: 764, negativos: 425).
# =============================================================================

# "Positivo -  Positivo : Serotipo 3 -  24.9 -" -> "DENV-3".
# Si un resultado trae dos serotipos (coinfección) queda como "DENV-1/3".
serotipo_de <- function(resultado) {
  hallados <- regmatches(resultado, gregexpr("[Ss]erotipo\\s*[1-4]", resultado))
  vapply(hallados, function(v) {
    if (!length(v)) return(NA_character_)
    paste0("DENV-", paste(sort(unique(gsub("\\D", "", v))), collapse = "/"))
  }, character(1))
}

# Nombre del EESS sin el código RENIPRESS: "00000210 - HOSPITAL ..." -> "HOSPITAL ..."
sin_codigo <- function(x) trimws(gsub("\\s+", " ", sub("^\\s*\\d+\\s*-\\s*", "", x)))

# Cuenta negativos y cada serotipo por los grupos indicados
contar_serotipos <- function(d, niveles, ...) {
  d$col <- ifelse(d$resultado_norm == "NEGATIVO", "Negativo", d$serotipo)
  d$col <- factor(d$col, levels = c("Negativo", niveles))
  out <- d |>
    dplyr::count(..., col, .drop = FALSE) |>
    tidyr::pivot_wider(names_from = col, values_from = n, values_fill = 0L)
  for (n in c("Negativo", niveles)) if (!n %in% names(out)) out[[n]] <- 0L
  out$Total <- rowSums(out[, c("Negativo", niveles), drop = FALSE])
  out
}

preparar_serotipos <- function(base, anio, se_rep, corte) {
  d <- base |>
    dplyr::filter(grepl(PATRON_SEROTIPO, clave(examen)),
                  !is.na(f_col), f_col <= corte, is.na(f_ver) | f_ver <= corte,
                  resultado_norm %in% c("NEGATIVO", "POSITIVO"))
  if (!nrow(d)) return(NULL)
  d$serotipo <- ifelse(d$resultado_norm == "POSITIVO", serotipo_de(d$resultado), NA_character_)
  d$serotipo[d$resultado_norm == "POSITIVO" & is.na(d$serotipo)] <- "Sin serotipo"

  act <- dplyr::filter(d, anio_se == anio, se <= se_rep)
  if (!nrow(act)) return(NULL)
  pos <- dplyr::filter(act, resultado_norm == "POSITIVO")
  # DENV-1 a DENV-3 siempre (como el modelo); DENV-4 u otros solo si aparecen
  niveles <- union(SEROTIPOS_BASE, sort(unique(d$serotipo[!is.na(d$serotipo)])))

  # --- Positivos por SE: año del reporte y año anterior ----------------------
  ant <- dplyr::filter(d, anio_se == anio - 1L)
  # El año anterior solo se compara si la descarga cubre casi todo el año
  semanas_ant <- dplyr::n_distinct(ant$se)
  hay_anterior <- semanas_ant >= SEMANAS_MIN_COMPARAR
  max_se_ant <- if (hay_anterior) max(ant$se) else 0L
  rejilla <- dplyr::bind_rows(
    if (hay_anterior) tidyr::expand_grid(anio_se = anio - 1L, se = seq_len(max_se_ant), serotipo = niveles),
    tidyr::expand_grid(anio_se = anio, se = seq_len(se_rep), serotipo = niveles)
  )
  por_se <- dplyr::filter(d, resultado_norm == "POSITIVO",
                          (anio_se == anio & se <= se_rep) | (hay_anterior & anio_se == anio - 1L)) |>
    dplyr::count(anio_se, se, serotipo) |>
    dplyr::right_join(rejilla, by = c("anio_se", "se", "serotipo")) |>
    dplyr::mutate(n = dplyr::coalesce(n, 0L), serotipo = factor(serotipo, levels = niveles)) |>
    dplyr::arrange(anio_se, se, serotipo)

  # --- % acumulado por serotipo hasta la SE del reporte y la anterior --------
  acum <- function(hasta) {
    p <- dplyr::filter(pos, se <= hasta, serotipo %in% niveles)
    v <- vapply(niveles, function(s) sum(p$serotipo == s), integer(1))
    list(se = hasta, n = v, pct = if (sum(v)) v / sum(v) else v * NA_real_)
  }
  acumulados <- list(acum(se_rep), acum(se_rep - 1L))

  # --- Provincia y distrito ---------------------------------------------------
  distrito <- contar_serotipos(act, niveles, prov, dist) |>
    dplyr::arrange(prov, dist)
  # --- Establecimientos de las últimas 4 SE -----------------------------------
  desde <- max(1L, se_rep - 3L)
  eess <- contar_serotipos(dplyr::mutate(dplyr::filter(act, se >= desde), eess = sin_codigo(eess)),
                           niveles, se, eess) |>
    dplyr::arrange(se, eess)

  # --- Cifras para los textos -------------------------------------------------
  tot <- acumulados[[1]]
  orden <- order(-tot$n)
  pred <- niveles[orden[1]]
  serie_pred <- dplyr::filter(por_se, anio_se == anio, serotipo == pred)
  pico <- serie_pred[which.max(serie_pred$n), ]
  prov_pos <- pos |>
    dplyr::group_by(prov) |>
    dplyr::summarise(combo = paste(sort(unique(serotipo)), collapse = ", "), .groups = "drop")
  prov_todas <- sort(unique(act$prov))
  eess_pos <- unique(sin_codigo(dplyr::filter(act, se >= desde, resultado_norm == "POSITIVO")$eess))
  es_hosp <- grepl("HOSPITAL", eess_pos, ignore.case = TRUE)
  anterior_txt <- NULL
  if (hay_anterior) {
    pa <- dplyr::filter(por_se, anio_se == anio - 1L, se <= se_rep)
    va <- tapply(pa$n, pa$serotipo, sum)
    anterior_txt <- list(total = sum(va), pred = names(which.max(va)),
                         pct_pred = if (sum(va)) max(va) / sum(va) else NA_real_)
  }

  list(anio = anio, datos = d, niveles = niveles, por_se = por_se, hay_anterior = hay_anterior,
       semanas_anterior = semanas_ant, acumulados = acumulados,
       distrito = distrito, eess = eess, se_desde = desde,
       campos = list(n_pos = nrow(pos), n_neg = sum(act$resultado_norm == "NEGATIVO"),
                     pred = pred, pct_pred = tot$pct[pred], pico_se = pico$se, pico_n = pico$n,
                     otros = setdiff(niveles[orden][tot$n[orden] > 0], pred),
                     pct = tot$pct, n = tot$n,
                     prov_pos = prov_pos, prov_todas = prov_todas,
                     prov_sin = setdiff(prov_todas, prov_pos$prov),
                     n_hosp = sum(es_hosp), n_aps = sum(!es_hosp),
                     anterior = anterior_txt))
}

# --- Textos de las láminas ----------------------------------------------------
# "DATEM DEL MARAÑON" -> "Datem del Marañon"
nombre_propio <- function(x) {
  x <- tools::toTitleCase(tolower(x))
  gsub("\\b(Del|De|La|Las|Los|Y)\\b", "\\L\\1", x, perl = TRUE)
}
lista_y <- function(x) if (length(x) <= 1) x else paste(paste(x[-length(x)], collapse = ", "), "y", x[length(x)])
pct2 <- function(x) pct(x, 2)

texto_serotipos_temporal <- function(s, anio, se_rep) {
  k <- s$campos
  if (!k$n_pos) return(sprintf("Hasta la SE %02d del %d no se registran muestras positivas por RT-PCR.", se_rep, anio))
  txt <- sprintf("Hasta la SE %02d del %d se identificaron **%s muestras positivas** por RT-PCR, con predominio del serotipo **%s (%s)**, cuyo pico máximo fue de %s casos en la SE %02d.",
                 se_rep, anio, num(k$n_pos), k$pred, pct2(k$pct_pred), num(k$pico_n), k$pico_se)
  if (length(k$otros)) {
    txt <- paste0(txt, sprintf(" Los serotipos %s presentan una circulación esporádica.",
                               lista_y(sprintf("**%s (%s)**", k$otros, pct2(k$pct[k$otros])))))
  }
  if (!is.null(k$anterior)) {
    txt <- paste0(txt, sprintf(" En el mismo periodo de %d se registraron %s positivos, con predominio de %s (%s).",
                               anio - 1L, num(k$anterior$total), k$anterior$pred, pct2(k$anterior$pct_pred)))
  }
  txt
}

texto_serotipos_geo <- function(s, anio) {
  k <- s$campos
  if (!nrow(k$prov_pos)) return(sprintf("En %d no se registran muestras positivas por RT-PCR.", anio))
  grupos <- split(nombre_propio(k$prov_pos$prov), k$prov_pos$combo)
  partes <- vapply(names(grupos), function(cmb) {
    p <- grupos[[cmb]]
    sprintf("%s %s **%s**", lista_y(p), if (length(p) > 1) "registran" else "registra", cmb)
  }, character(1))
  txt <- sprintf("En %d, %d de las %d provincias con muestras procesadas registran casos positivos: %s.",
                 anio, nrow(k$prov_pos), length(k$prov_todas), paste(partes, collapse = "; "))
  if (length(k$prov_sin)) {
    txt <- paste0(txt, sprintf(" En %s no se reportan casos positivos.", lista_y(nombre_propio(k$prov_sin))))
  }
  txt
}

texto_serotipos_eess <- function(s, se_rep) {
  k <- s$campos
  n <- k$n_hosp + k$n_aps
  if (!n) return(sprintf("Entre la SE %02d y la SE %02d no se registran casos positivos.", s$se_desde, se_rep))
  sprintf("Entre la SE %02d y la SE %02d, los casos positivos proceden de %d establecimientos: %d %s y %d %s de atención primaria.",
          s$se_desde, se_rep, n, k$n_hosp, if (k$n_hosp == 1) "hospital" else "hospitales",
          k$n_aps, if (k$n_aps == 1) "establecimiento" else "establecimientos")
}

# --- Gráfico: distribución temporal --------------------------------------------
#  Arriba (si hay datos del año anterior): positivos por SE de los dos años en
#  una sola línea de tiempo. Abajo: positivos por SE del año del reporte.
grafico_serotipos <- function(s, anio) {
  col <- COLORES_SEROTIPO[s$niveles]
  col[is.na(col)] <- "#7f7f7f"; names(col) <- s$niveles
  ps <- s$por_se
  ps$x <- factor(sprintf("%d-%02d", ps$anio_se, ps$se), levels = unique(sprintf("%d-%02d", ps$anio_se, ps$se)))
  actual <- dplyr::filter(ps, anio_se == anio)
  actual$SE <- factor(sprintf("SE%02d", actual$se), levels = sprintf("SE%02d", sort(unique(actual$se))))

  p_bar <- ggplot2::ggplot(actual, ggplot2::aes(SE, n, fill = serotipo)) +
    ggplot2::geom_col(position = ggplot2::position_dodge(width = 0.8), width = 0.75) +
    ggplot2::scale_fill_manual(values = col, drop = FALSE) +
    ggplot2::scale_y_continuous(expand = ggplot2::expansion(mult = c(0, 0.1))) +
    ggplot2::labs(title = sprintf("Positivos por serotipo y SE de toma de muestra, %d", anio),
                  x = NULL, y = "N.° de casos") +
    tema_lrrl(10) +
    ggplot2::theme(axis.text.x = ggplot2::element_text(angle = 90, vjust = 0.5, hjust = 1, size = 6.5))
  if (!s$hay_anterior) return(p_bar)

  etiquetas <- sprintf("SE%02d", as.integer(sub(".*-", "", levels(ps$x))))
  cortes <- levels(ps$x)[seq(1, length(levels(ps$x)), by = 2)]
  inicio_anio <- which(levels(ps$x) == sprintf("%d-01", anio))
  p_lin <- ggplot2::ggplot(ps, ggplot2::aes(x, n, colour = serotipo, group = serotipo)) +
    ggplot2::geom_vline(xintercept = inicio_anio - 0.5, colour = TINTA[["eje"]], linetype = "dashed") +
    ggplot2::geom_line(linewidth = 0.7) +
    ggplot2::annotate("text", x = c(inicio_anio / 2, inicio_anio + (length(levels(ps$x)) - inicio_anio) / 2),
                      y = Inf, vjust = 1.3, label = c(anio - 1L, anio), colour = TINTA[["secundaria"]],
                      fontface = "bold", size = 3.2) +
    ggplot2::scale_colour_manual(values = col, drop = FALSE) +
    ggplot2::scale_x_discrete(breaks = cortes, labels = setNames(etiquetas, levels(ps$x))[cortes]) +
    ggplot2::scale_y_continuous(expand = ggplot2::expansion(mult = c(0, 0.2))) +
    ggplot2::labs(title = sprintf("Distribución temporal comparativa, %d y %d", anio - 1L, anio),
                  x = NULL, y = "N.° de casos") +
    tema_lrrl(10) +
    ggplot2::theme(axis.text.x = ggplot2::element_text(angle = 90, vjust = 0.5, hjust = 1, size = 6),
                   legend.position = "none")
  patchwork::wrap_plots(p_lin, p_bar, ncol = 1, heights = c(1, 1.15))
}

# --- Tablas (flextable) -----------------------------------------------------------
ft_acumulados <- function(s) {
  filas <- lapply(s$acumulados, function(a) {
    c(`Acumulado` = sprintf("SE%02d", a$se), setNames(pct2(a$pct), names(a$pct)))
  })
  df <- as.data.frame(do.call(rbind, filas), check.names = FALSE)
  n_s <- ncol(df) - 1
  ft <- ft_lrrl(df, anchos = c(1.0, rep(2.75 / n_s, n_s)), tam = 10, fila_total = FALSE, alto = 0.28) |>
    flextable::add_header_lines(sprintf("Datos acumulados %s (%% de positivos)", s$anio)) |>
    flextable::bg(i = 1, bg = "white", part = "header") |>
    flextable::color(i = 1, color = TINTA[["primaria"]], part = "header") |>
    flextable::align(i = 1, align = "left", part = "header")
  for (j in seq_len(n_s) + 1) {
    color <- COLORES_SEROTIPO[names(df)[j]]
    if (!is.na(color)) ft <- flextable::bg(ft, j = j, bg = color, part = "header")
  }
  ft
}

ft_distrito <- function(s) {
  t <- s$distrito
  tot <- t |> dplyr::summarise(dplyr::across(c("Negativo", dplyr::all_of(s$niveles), "Total"), sum))
  df <- dplyr::bind_rows(
    dplyr::transmute(t, Provincia = prov, Distrito = dist, dplyr::across(c("Negativo", dplyr::all_of(s$niveles), "Total"))),
    dplyr::mutate(tot, Provincia = "Total general", Distrito = "")
  )
  num_cols <- c("Negativo", s$niveles, "Total")
  df[num_cols] <- lapply(df[num_cols], num)
  n_s <- length(s$niveles)
  ft <- ft_lrrl(df, anchos = c(2.3, 2.0, 0.9, rep(0.8, n_s), 0.8), tam = 9, n_texto = 2, alto = 0.2) |>
    flextable::merge_v(j = 1) |>
    flextable::valign(j = 1, valign = "top", part = "body") |>
    flextable::merge_at(i = nrow(df), j = 1:2, part = "body") |>
    flextable::bold(j = 1, part = "body")
  # Los positivos en rojo, como en el modelo
  for (sero in s$niveles) {
    filas <- which(s$distrito[[sero]] > 0)
    if (length(filas)) ft <- flextable::color(ft, i = filas, j = sero, color = "#C00000", part = "body")
  }
  ft
}

# Establecimientos con casos positivos en las últimas 4 SE: una fila por EESS,
# positivos por SE, serotipos hallados, negativos y total. (El modelo listaba
# cada SE por separado; con 60+ filas no cabía, así que se resume por EESS.)
tabla_eess_serotipos <- function(s) {
  t <- s$eess
  t$pos <- t$Total - t$Negativo
  con_pos <- unique(t$eess[t$pos > 0])
  t <- t[t$eess %in% con_pos, ]
  semanas <- seq(s$se_desde, max(s$eess$se))
  pos_se <- tidyr::pivot_wider(t[, c("eess", "se", "pos")], names_from = se, values_from = pos,
                               values_fill = 0L, names_sort = TRUE)
  for (w in semanas) if (!as.character(w) %in% names(pos_se)) pos_se[[as.character(w)]] <- 0L
  pos_se <- pos_se[, c("eess", as.character(semanas))]
  names(pos_se) <- c("eess", sprintf("SE%02d", semanas))
  resumen <- t |>
    dplyr::group_by(eess) |>
    dplyr::summarise(Positivos = sum(pos), Negativos = sum(Negativo),
                     dplyr::across(dplyr::all_of(s$niveles), sum), .groups = "drop")
  hallados <- as.matrix(resumen[, s$niveles]) > 0
  resumen$Serotipo <- apply(hallados, 1, function(v) paste(s$niveles[v], collapse = ", "))
  df <- dplyr::inner_join(pos_se, resumen, by = "eess") |>
    dplyr::arrange(dplyr::desc(Positivos), eess) |>
    dplyr::rename(`Establecimiento notificante` = eess)
  se_cols <- sprintf("SE%02d", semanas)
  tot <- dplyr::summarise(df, dplyr::across(c(dplyr::all_of(se_cols), "Positivos", "Negativos"), sum))
  tot$`Establecimiento notificante` <- "Total general"
  tot$Serotipo <- paste(s$niveles[vapply(s$niveles, function(x) sum(s$eess[[x]][s$eess$eess %in% con_pos]) > 0, logical(1))],
                        collapse = ", ")
  df <- dplyr::bind_rows(df, tot)
  num_cols <- c(se_cols, "Positivos", "Negativos")
  df[num_cols] <- lapply(df[num_cols], num)
  df[, c("Establecimiento notificante", se_cols, "Positivos", "Serotipo", "Negativos")]
}

anchos_eess_serotipos <- function(p) c(5.6, rep(0.75, ncol(p) - 4), 1.0, 1.7, 1.0)

ft_eess_serotipos <- function(p, ultima) {
  ft <- ft_lrrl(p, anchos = anchos_eess_serotipos(p), tam = 9, n_texto = 1,
                fila_total = ultima, alto = 0.2)
  ft <- flextable::add_header_row(ft, values = c("", "Positivos por SE de toma", "", "", ""),
                                  colwidths = c(1, ncol(p) - 4, 1, 1, 1))
  ft <- flextable::bg(ft, bg = TINTA[["azul_lrrl"]], part = "header") |>
    flextable::color(color = "white", part = "header") |>
    flextable::bold(part = "header") |>
    flextable::align(align = "center", part = "header") |>
    flextable::fontsize(size = 9, part = "header") |>
    flextable::font(fontname = "Arial", part = "header") |>
    flextable::bold(j = "Positivos", part = "body") |>
    flextable::color(j = "Positivos", color = "#C00000", part = "body")
  ft
}
