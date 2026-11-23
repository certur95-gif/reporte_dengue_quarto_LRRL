# Se ejecuta UNA sola vez en cada computadora (necesita internet).
# No empieza con "0" a propósito: así el reporte no lo ejecuta cada semana.
paquetes <- c("quarto", "rmarkdown", "knitr", "yaml",
              "readxl", "writexl", "rvest", "stringi",
              "dplyr", "tidyr", "tibble", "lubridate",
              "ggplot2", "scales", "patchwork",
              "flextable", "officer")
faltan <- setdiff(paquetes, rownames(installed.packages()))
if (length(faltan)) install.packages(faltan)
v <- tryCatch(as.character(quarto::quarto_version()), error = function(e) NA_character_)
if (is.na(v)) {
  message("Paquetes listos, pero no se encontró Quarto. Actualiza RStudio o instala Quarto desde https://quarto.org")
} else {
  message("Paquetes listos. Versión de Quarto: ", v)
}
