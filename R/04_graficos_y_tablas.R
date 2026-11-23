# =============================================================================
#  04 · GRÁFICOS (ggplot2) Y FORMATO DE TABLAS (flextable)
# =============================================================================

tema_lrrl <- function(base = 11) {
  ggplot2::theme_minimal(base_size = base) +
    ggplot2::theme(
      panel.grid.major.x = ggplot2::element_blank(),
      panel.grid.minor   = ggplot2::element_blank(),
      panel.grid.major.y = ggplot2::element_line(colour = TINTA[["grilla"]], linewidth = 0.3),
      axis.line.x  = ggplot2::element_line(colour = TINTA[["eje"]], linewidth = 0.3),
      axis.text    = ggplot2::element_text(colour = TINTA[["tenue"]]),
      axis.title   = ggplot2::element_text(colour = TINTA[["secundaria"]], size = ggplot2::rel(0.9)),
      legend.position = "top", legend.justification = "left",
      legend.title = ggplot2::element_blank(),
      legend.text  = ggplot2::element_text(colour = TINTA[["secundaria"]]),
      legend.key.size = grid::unit(0.35, "cm"),
      legend.margin = ggplot2::margin(0, 0, 0, 0),
      plot.title   = ggplot2::element_text(colour = TINTA[["primaria"]], face = "bold",
                                           size = ggplot2::rel(0.95)),
      plot.title.position = "plot"
    )
}

# --- Lámina 2: IP y número de muestras por SE ---------------------------------
#  Dos paneles alineados sobre el mismo eje de semanas: arriba el IP (%), abajo
#  las muestras negativas y positivas. Cada medida tiene su propia escala, así
#  no hay un segundo eje cuya alineación con las barras sería arbitraria.
#  Se rotulan solo la SE del reporte y el máximo del año; todas las cifras van
#  en el Excel de tablas (hoja por_SE).
grafico_por_se <- function(t_se) {
  t_se$SE <- factor(t_se$SE, levels = t_se$SE)
  ult     <- t_se[nrow(t_se), ]
  rot_ip  <- unique(rbind(ult, t_se[which.max(t_se$IP), ]))
  rot_n   <- unique(rbind(ult, t_se[which.max(t_se$Total), ]))
  largo <- tidyr::pivot_longer(t_se[, c("SE", "NEGATIVO", "POSITIVO")], -SE,
                               names_to = "Resultado", values_to = "n")
  largo$Resultado <- factor(largo$Resultado, levels = c("POSITIVO", "NEGATIVO"))

  p_ip <- ggplot2::ggplot(t_se, ggplot2::aes(SE, IP, group = 1)) +
    ggplot2::geom_line(colour = COLORES[["IP"]], linewidth = 0.8, lineend = "round",
                       linejoin = "round", na.rm = TRUE) +
    ggplot2::geom_point(data = rot_ip, colour = "white", size = 3.6, na.rm = TRUE) +
    ggplot2::geom_point(data = rot_ip, colour = COLORES[["IP"]], size = 2.6, na.rm = TRUE) +
    ggplot2::geom_text(data = rot_ip, ggplot2::aes(label = pct(IP)), vjust = -1.1, size = 3.1,
                       colour = TINTA[["primaria"]], na.rm = TRUE) +
    ggplot2::scale_x_discrete(drop = FALSE) +
    ggplot2::scale_y_continuous(labels = scales::label_percent(accuracy = 1), limits = c(0, NA),
                                expand = ggplot2::expansion(mult = c(0, 0.3))) +
    ggplot2::coord_cartesian(clip = "off") +
    ggplot2::labs(title = "Índice de positividad (IP %)", x = NULL, y = NULL) +
    tema_lrrl() +
    ggplot2::theme(axis.text.x = ggplot2::element_blank(),
                   plot.margin = ggplot2::margin(5, 22, 8, 5))

  p_n <- ggplot2::ggplot(largo, ggplot2::aes(SE, n, fill = Resultado)) +
    ggplot2::geom_col(width = 0.62, colour = "white", linewidth = 0.3) +
    ggplot2::geom_text(data = rot_n, ggplot2::aes(SE, Total, label = num(Total)),
                       inherit.aes = FALSE, vjust = -0.6, size = 3.1, colour = TINTA[["primaria"]]) +
    ggplot2::scale_fill_manual(values = COLORES[c("NEGATIVO", "POSITIVO")],
                               breaks = c("NEGATIVO", "POSITIVO")) +
    ggplot2::scale_x_discrete(drop = FALSE) +
    ggplot2::scale_y_continuous(labels = scales::label_comma(),
                                expand = ggplot2::expansion(mult = c(0, 0.14))) +
    ggplot2::coord_cartesian(clip = "off") +
    ggplot2::labs(title = "Número de muestras", x = NULL, y = NULL) +
    tema_lrrl() +
    ggplot2::theme(axis.text.x = ggplot2::element_text(angle = 90, vjust = 0.5, hjust = 1, size = 7),
                   plot.margin = ggplot2::margin(2, 22, 5, 5))

  patchwork::wrap_plots(p_ip, p_n, ncol = 1, heights = c(1, 2))
}

# --- Lámina 3: resultados por tipo de prueba ----------------------------------
grafico_tipo_prueba <- function(t_tp) {
  cuerpo <- t_tp[t_tp$tipo != "Total", ]
  cuerpo$tipo <- factor(cuerpo$tipo, levels = rev(cuerpo$tipo))
  largo <- tidyr::pivot_longer(cuerpo[, c("tipo", "NEGATIVO", "POSITIVO")], -tipo,
                               names_to = "Resultado", values_to = "n")
  largo$Resultado <- factor(largo$Resultado, levels = c("POSITIVO", "NEGATIVO"))
  # El número va dentro del segmento solo si cabe; si no, queda en la tabla
  largo$rotulo <- ifelse(largo$n >= 0.09 * max(cuerpo$Total), num(largo$n), "")

  ggplot2::ggplot(largo, ggplot2::aes(n, tipo, fill = Resultado)) +
    ggplot2::geom_col(width = 0.42, colour = "white", linewidth = 0.6) +
    ggplot2::geom_text(ggplot2::aes(label = rotulo), colour = "white", size = 3.6,
                       position = ggplot2::position_stack(vjust = 0.5)) +
    ggplot2::geom_text(data = cuerpo, inherit.aes = FALSE, hjust = -0.08, size = 3.6,
                       colour = TINTA[["primaria"]],
                       ggplot2::aes(Total, tipo, label = sprintf("%s pruebas · IP %s", num(Total), pct(IP)))) +
    ggplot2::scale_fill_manual(values = COLORES[c("NEGATIVO", "POSITIVO")],
                               breaks = c("NEGATIVO", "POSITIVO")) +
    ggplot2::scale_x_continuous(labels = scales::label_comma(),
                                expand = ggplot2::expansion(mult = c(0, 0.42))) +
    ggplot2::labs(x = "Número de muestras", y = NULL) +
    tema_lrrl(12) +
    ggplot2::theme(panel.grid.major.y = ggplot2::element_blank(),
                   panel.grid.major.x = ggplot2::element_line(colour = TINTA[["grilla"]], linewidth = 0.3),
                   axis.line.x = ggplot2::element_blank(),
                   axis.line.y = ggplot2::element_line(colour = TINTA[["eje"]], linewidth = 0.3),
                   axis.text.y = ggplot2::element_text(colour = TINTA[["primaria"]], face = "bold"))
}

# --- Formato común de las tablas ----------------------------------------------
#  anchos: ancho de cada columna en pulgadas.  n_texto: cuántas columnas
#  iniciales son de texto (alineadas a la izquierda); el resto va centrado.
ft_lrrl <- function(df, anchos, tam = 10, n_texto = 1, fila_total = TRUE, alto = 0.24) {
  borde <- officer::fp_border(color = TINTA[["grilla"]], width = 0.75)
  ft <- flextable::flextable(df) |>
    flextable::font(fontname = "Arial", part = "all") |>
    flextable::fontsize(size = tam, part = "all") |>
    flextable::border_remove() |>
    flextable::hline(border = borde, part = "body") |>
    flextable::bg(bg = TINTA[["azul_lrrl"]], part = "header") |>
    flextable::color(color = "white", part = "header") |>
    flextable::bold(part = "header") |>
    flextable::align(align = "center", part = "all") |>
    flextable::align(j = seq_len(n_texto), align = "left", part = "all") |>
    flextable::valign(valign = "center", part = "all") |>
    flextable::padding(padding.top = 1.5, padding.bottom = 1.5, padding.left = 4,
                       padding.right = 4, part = "all") |>
    flextable::width(j = seq_along(anchos), width = anchos) |>
    flextable::height_all(height = alto)
  if (fila_total && nrow(df) > 1) {
    ft <- ft |>
      flextable::bold(i = nrow(df), part = "body") |>
      flextable::bg(i = nrow(df), bg = "#EEF3FA", part = "body")
  }
  ft
}

# Tabla de periodos del diferencial: sangra trimestres y meses
ft_periodos <- function(t, etiqueta, anchos, tam = 10) {
  nivel <- t$nivel
  df <- t[, setdiff(names(t), "nivel")]
  df$Periodo <- paste0(strrep("    ", nivel), df$Periodo)
  num_cols <- setdiff(names(df), "Periodo")
  df[num_cols] <- lapply(df[num_cols], num)   # el 0 se escribe: una celda vacía agranda la fila
  names(df)[names(df) == "Periodo"] <- etiqueta
  names(df)[names(df) == "Total"]   <- "Total general"
  ft <- ft_lrrl(df, anchos = anchos, tam = tam)
  flextable::bold(ft, i = which(nivel == 0), j = 1, part = "body")
}

# [Cambio 17.11.2026] Escribe una tabla en una posición fija de la lámina
# (pulgadas desde la esquina superior izquierda) dentro de un chunk con
# "output: asis" (bucles). flextable solo toma la posición de las opciones
# ft.left / ft.top del chunk e ignora los argumentos de flextable_to_rmd(), por
# eso se arma un mini-chunk con esas opciones y se procesa con knit_child().
tabla_en_posicion <- function(ft, left, top) {
  e <- new.env()
  e$ft <- ft
  chunk <- sprintf("```{r, ft.left=%.3f, ft.top=%.3f, echo=FALSE}\nft\n```", left, top)
  cat(knitr::knit_child(text = chunk, envir = e, quiet = TRUE), "\n")
}

# Parte una tabla larga en páginas parejas (una por lámina), de modo que la
# fila de total nunca quede sola en la última.
paginar <- function(df, filas = 20) {
  n <- nrow(df)
  if (n <= filas) return(list(df))
  por_pagina <- ceiling(n / ceiling(n / filas))
  unname(split(df, ceiling(seq_len(n) / por_pagina)))
}
