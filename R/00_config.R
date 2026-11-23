# =============================================================================
#  00 · CONFIGURACIÓN FIJA DEL REPORTE
#  Se edita rara vez. Lo que cambia cada semana (la SE) está en generar_reporte.R
# =============================================================================

INSTITUCION <- "LABORATORIO DE REFERENCIA REGIONAL DE LORETO"
UNIDAD      <- "UNIDAD DE VIROLOGÍA"
FUENTE_V2   <- "Fuente: DIRESA Loreto: CPC. Dirección de Referencia Regional de Loreto. Unidad de Virología. NetLab v.2"
FUENTE_V1   <- "Fuente: NetLab v.1 (Mayaro, Oropouche)."

# Solo estos dos exámenes entran al reporte serológico de dengue. Todo lo
# molecular (RT-PCR, paneles, serotipificación) queda fuera: lo reporta
# vigilancia de serotipos.
EXAMENES_DENGUE <- c(
  IgM = "Virus Dengue Ac. IgM [Presencia] en Suero o Plasma por Inmunoensayo",
  NS1 = "Virus Dengue Ag NS1 [Presencia] en Suero o Plasma por Inmunoensayo"
)

# Laboratorios destino que NO forman parte de lo que procesa la red LRRL
# (es el filtro "Varios elementos" de las tablas dinámicas).
LABS_EXCLUIDOS <- c(
  '00000003 - HOSPITAL REGIONAL DE LORETO "FELIPE SANTIAGO ARRIOLA IGLESIAS"',
  "LRNMZVIR - LRN DE METAXENICAS Y ZOONOSIS VIRALES",
  "00013996 - LABORATORIO DE REFERENCIA REGIONAL EN SALUD PUBLICA"
)

# Diagnóstico diferencial que viene en la misma descarga de NetLab v2
PATRON_ZIKA_CHIK <- "zika|chikungunya"

# [Cambio 17.11.2026] Años que entran a la lámina de Zika y Chikungunya.
# 1 = el año del reporte y el anterior (en 2026: solo 2025 y 2026). Se cuenta
# hacia atrás desde ANIO, así el filtro avanza solo cuando cambie el año.
# Para volver a mostrar todos los años, pon Inf.
DIFERENCIAL_ANIOS_PREVIOS <- 1

# [Nuevo 17.11.2026] Serotipos del virus dengue (láminas finales, R/06_serotipos.R)
# Examen de RT-PCR que trae el serotipo en el resultado. Se compara sin tildes,
# espacios ni signos: "Presencia del ARN del virus dengue 1,2,3,4, por RT - PCR
# en tiempo real" y "Virus Dengue 1,2,3,4 [Presencia] ..." contienen "dengue1234".
PATRON_SEROTIPO <- "dengue1234"
SEROTIPOS_BASE  <- c("DENV-1", "DENV-2", "DENV-3")    # siempre se muestran
COLORES_SEROTIPO <- c("DENV-1" = "#2EA043", "DENV-2" = "#C2189B",
                      "DENV-3" = "#1F6FD1", "DENV-4" = "#D9822B")
# El gráfico comparativo con el año anterior solo aparece si las descargas de
# ese año cubren al menos estas semanas (si no, la línea saldría casi vacía).
SEMANAS_MIN_COMPARAR <- 40
FUENTE_SEROTIPOS <- "Fuente: INS, NetLab v.2, LRRL-Loreto, Unidad de Biología Molecular."

MESES       <- c("Ene", "Feb", "Mar", "Abr", "May", "Jun", "Jul", "Ago", "Set", "Oct", "Nov", "Dic")
MESES_LARGO <- c("enero", "febrero", "marzo", "abril", "mayo", "junio", "julio",
                 "agosto", "setiembre", "octubre", "noviembre", "diciembre")

# Colores: cada entidad conserva su color en todos los gráficos
COLORES <- c(NEGATIVO = "#2a78d6", POSITIVO = "#eb6834", IP = "#1baf7a")
TINTA   <- c(primaria = "#0b0b0b", secundaria = "#52514e", tenue = "#898781",
             grilla = "#e1e0d9", eje = "#c3c2b7", azul_lrrl = "#1F3864")

# --- formatos -----------------------------------------------------------------
pct <- function(x, dec = 1) ifelse(is.na(x), "", sprintf(paste0("%.", dec, "f%%"), 100 * x))
num <- function(x) format(as.integer(x), big.mark = ",", trim = TRUE)
fecha_larga <- function(f) {
  sprintf("%s de %s de %s", format(f, "%d"), MESES_LARGO[as.integer(format(f, "%m"))], format(f, "%Y"))
}
fecha_corta <- function(f) format(f, "%d.%m.%Y")
