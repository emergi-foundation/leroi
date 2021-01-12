# Script to render Rmd to PDF and docx

# Define custom functions ----

#' Convert latex file to docx
#' 
#' Requires pandoc to be installed and on command line
#'
#' @param latex Path to input latex file.
#' @param docx Path to output docx file.
#' @param template Path to template docx file.
#' @param wd Working directory to run conversion. Should be same as
#' directory containing any files needed to render latex to pdf.
#'
#' @return List including STDOUT of pandoc; externally, the
#' docx file will be rendered in `wd`.
#' 
latex2docx <- function(latex, docx, template = NULL, wd = getwd()) {
  
  assertthat::assert_that(assertthat::is.readable(latex))
  
  assertthat::assert_that(assertthat::is.dir(fs::path_dir(docx)))
  
  latex <- fs::path_abs(latex)
  
  docx <- fs::path_abs(docx)
  
  template <- if (!is.null(template)) {
    glue::glue("--reference-doc={fs::path_abs(template)}")
  } else {
    NULL
  }
  
  processx::run(
    command = "pandoc",
    args = c("-s", latex, template, "-o", docx),
    wd = wd
  )
  
}

# Render docs ----

# - PDF
rmarkdown::render(
  "net_energy_equity_springer/net_energy_equity_springer.Rmd",
  output_dir = "net_energy_equity_springer"
)

# - docx
latex2docx(
  latex = "net_energy_equity_springer/net_energy_equity_springer.tex",
  docx = "net_energy_equity_springer/net_energy_equity_springer.docx",
  template = "sv-journ.dot",#here::here("ms/new-phytologist.docx"),
  wd = getwd()#here::here("net_energy_equity_springer")
)

