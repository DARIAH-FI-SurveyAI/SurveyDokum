# Using RAG with SurveyDokum

## What this guide covers

SurveyDokum’s LLM-based documentation
([`sd_document()`](https://dariah-fi-surveyai.github.io/SurveyDokum/reference/sd_document.md),
[`sd_generate_roxygen()`](https://dariah-fi-surveyai.github.io/SurveyDokum/reference/sd_generate_roxygen.md))
writes from the statistics computed by
[`sd_summarise()`](https://dariah-fi-surveyai.github.io/SurveyDokum/reference/sd_summarise.md)
alone, by default. RAG (*Retrieval-Augmented Generation*) lets you
additionally feed the model background material you choose yourself – a
survey methodology glossary, a controlled vocabulary, previous codebooks
used as style examples, a bilingual terminology list – so its writing
draws on more than the numbers and its own general knowledge.

RAG support in SurveyDokum is a deliberately thin, **optional** layer:
SurveyDokum does not build, ship, or maintain a knowledge store for you.
It only *consumes* one you build yourself with the
[ragnar](https://ragnar.tidyverse.org/) package, from whatever reference
material you choose – your own survey methodology documentation,
controlled vocabularies, previous codebooks, style guides, glossaries,
or anything else ragnar can turn into text. This guide walks through
building such a store with ragnar from scratch, then connecting it to
SurveyDokum’s own functions, in general terms that apply regardless of
what material you bring.

As a concrete example, this guide was developed against a small
prototype store built from a handful of European Social Survey (ESS)
documentation PDFs and a couple of reference web pages – the pitfalls
noted along the way are ones actually hit while building that prototype,
not hypothetical ones, and they apply the same way whatever your own
source material happens to be.

This vignette is a parallel English-language translation of the
package’s Finnish vignette (“RAGin käyttö SurveyDokumin kanssa”) – there
is also a Swedish version (“Använda RAG med SurveyDokum”). All three
cover the same workflow.

## Prerequisites

``` r

install.packages("ragnar")     # CRAN; brings in the duckdb dependency
install.packages("pdftools")   # fallback for reading PDFs, see Step 1
install.packages("rvest")      # fallback for reading web pages, see Step 1
```

ragnar needs an embedding model to turn text chunks into vectors. Since
SurveyDokum already relies on a local [Ollama](https://ollama.com/)
installation for
[`sd_document()`](https://dariah-fi-surveyai.github.io/SurveyDokum/reference/sd_document.md)/[`sd_generate_roxygen()`](https://dariah-fi-surveyai.github.io/SurveyDokum/reference/sd_generate_roxygen.md),
this guide uses an Ollama embedding model too, keeping the whole
pipeline offline – relevant when your reference material is sensitive
(e.g. restricted-access microdata documentation):

``` sh
ollama pull embeddinggemma:300m
```

Any other Ollama embedding model works too – just use its name in
[`embed_ollama()`](https://ragnar.tidyverse.org/reference/embed_ollama.html)
in Step 3 below. Make sure the Ollama server is running (default address
`http://localhost:11434`).

## Step 1: Read your source documents into Markdown

ragnar’s own
[`read_as_markdown()`](https://ragnar.tidyverse.org/reference/read_as_markdown.html)
uses MarkItDown, which downloads its own Python environment (via `uv`)
on first use, and preserves heading structure the best of the options
here. In practice it can fail on Windows with an error such as
`"Error loading Python module _ragnartools.markitdown"` – most likely
Windows or antivirus software blocking a downloaded native library
(e.g. `onnxruntime`). If you hit this, two fallbacks avoid the Python
environment entirely, at the cost of raw text without heading structure:

``` r

library(ragnar)

# PDFs, via pdftools:
read_pdf_fallback <- function(path) {
  pages <- pdftools::pdf_text(path)
  txt <- paste(pages, collapse = "\n\n---\n\n")
  MarkdownDocument(txt, origin = path)
}

# Web pages, via rvest:
read_html_fallback <- function(url) {
  page <- rvest::read_html(url)
  main_node <- rvest::html_element(page, "main")
  if (length(main_node) == 0 || is.na(main_node)) main_node <- page
  txt <- rvest::html_text2(main_node)
  MarkdownDocument(txt, origin = url)
}
```

Use whichever route works on your machine:

``` r

pdf_files <- list.files("path/to/reference_pdfs", pattern = "\\.pdf$", full.names = TRUE)
markdown_docs <- lapply(pdf_files, read_pdf_fallback)   # or read_as_markdown()
names(markdown_docs) <- basename(pdf_files)
```

## Step 2: Clean up repeated headers, footers and page numbers (PDFs only)

`pdftools::pdf_text()` returns raw page text, including running
headers/footers (e.g. a document title repeated on every page) and
page-number lines – these become noise in your chunks if left in. A
helper that removes lines which *repeat* across most pages (rather than
searching for specific text, so it works for any PDF) is worth writing
once and reusing:

``` r

strip_repeated_headers_footers <- function(pages, n_lines = 2, threshold = 0.5, prefix_len = 30) {
  split_pages <- strsplit(pages, "\n")
  n <- length(split_pages)

  get_candidates <- function(lines) {
    lines <- trimws(lines)
    lines <- lines[lines != ""]
    if (length(lines) == 0) return(character())
    unique(c(utils::head(lines, n_lines), utils::tail(lines, n_lines)))
  }
  candidate_lines <- unlist(lapply(split_pages, get_candidates))

  # Case A: the whole line repeats identically (short IDs, page numbers)
  line_counts <- table(candidate_lines)
  repeated_lines <- names(line_counts[line_counts >= threshold * n])

  # Case B: only the line's PREFIX repeats, while the rest varies by section
  # (e.g. "Annual Report 2024 -- Methodology  Chapter 3")
  prefixes <- substr(candidate_lines, 1, prefix_len)
  prefixes <- prefixes[nchar(trimws(prefixes)) >= 10]
  prefix_counts <- table(prefixes)
  repeated_prefixes <- names(prefix_counts[prefix_counts >= threshold * n])

  vapply(split_pages, function(lines) {
    trimmed <- trimws(lines)
    keep <- !trimmed %in% repeated_lines
    if (length(repeated_prefixes) > 0) {
      keep <- keep & !(substr(trimmed, 1, prefix_len) %in% repeated_prefixes)
    }
    keep <- keep & !grepl("^(page\\s*)?[0-9]{1,4}(\\s*(/|of)\\s*[0-9]{1,4})?$", trimmed, ignore.case = TRUE)
    paste(lines[keep], collapse = "\n")
  }, character(1))
}
```

Apply it before wrapping the text in
[`MarkdownDocument()`](https://ragnar.tidyverse.org/reference/MarkdownDocument.html),
i.e. inside `read_pdf_fallback()` above:
`pages <- strip_repeated_headers_footers(pages)`.

## Step 3: Chunk and build the store

``` r

store_path <- file.path("path/to", "my_reference.ragnar.duckdb")

store <- ragnar_store_create(
  location = store_path,
  embed = embed_ollama(model = "embeddinggemma:300m"),
  overwrite = TRUE,
  title = "My reference material"
)

for (doc_name in names(markdown_docs)) {
  chunks <- markdown_chunk(markdown_docs[[doc_name]])
  ragnar_store_insert(store, chunks)
}

ragnar_store_build_index(store)
```

Two pitfalls worth knowing about before you hit them:

- **Insert each document’s chunks separately, as a fresh
  [`markdown_chunk()`](https://ragnar.tidyverse.org/reference/markdown_chunk.html)
  result.** A version-2 store (the current default) adds heading context
  to each chunk’s text automatically during insert. If you combine
  chunks from several documents into one `data.frame` first (e.g. with
  `do.call(rbind, ...)`) before calling
  [`ragnar_store_insert()`](https://ragnar.tidyverse.org/reference/ragnar_store_insert.html),
  that automatic step breaks with
  `"modifying chunks$text is not supported with store@version == 2"`.
  Loop over documents and insert as you go, as above.
- **[`ragnar_store_build_index()`](https://ragnar.tidyverse.org/reference/ragnar_store_build_index.html)
  must run before
  [`ragnar_retrieve()`](https://ragnar.tidyverse.org/reference/ragnar_retrieve.html)
  works at all.** Without it, retrieval fails with an error naming
  DuckDB’s BM25 function (`match_bm25 does not exist`) – the index is
  what makes that full-text search possible, so it is not optional, and
  it needs to run again after any batch of new inserts.

Give `store_path` as an absolute path, not a relative one – if your
working directory happens to be some other project when you first build
the store, that is where the `.duckdb` file will land.

Once built, a store on disk should be *connected to*, not rebuilt, on
later runs:

``` r

if (file.exists(store_path)) {
  store <- ragnar_store_connect(store_path)
} else {
  # ... build as above ...
}
```

Rebuild (`overwrite = TRUE`) only when you change the embedding model or
add documents you want indexed from scratch.

## Step 4: Try retrieval directly

``` r

hits <- ragnar_retrieve(store, "your query here", top_k = 5)

# ragnar_retrieve() returns a tibble whose text column gets truncated when printed --
# use a small helper to see the full text of each hit:
print_ragnar_hits <- function(hits) {
  for (i in seq_len(nrow(hits))) {
    row <- hits[i, ]
    cat(sprintf("--- hit %d/%d: %s (chars %s-%s) ---\n",
                i, nrow(hits), basename(row$origin), row$start, row$end))
    cat(row$text, "\n\n")
  }
}
print_ragnar_hits(hits)
```

(In the ESS-based prototype, a query like *“How is political trust
measured?”* reliably surfaced the right codebook and questionnaire
chunks – what works well for you will depend entirely on what you’ve
indexed.)

[`ragnar_retrieve()`](https://ragnar.tidyverse.org/reference/ragnar_retrieve.html)
combines vector search with DuckDB’s BM25 full-text search. Worth
knowing if you mix conceptually different kinds of material in one store
(e.g. survey microdata documentation alongside an abstract metadata
standard): BM25 will surface matches on shared vocabulary
(e.g. “codebook”, “variable”, “documentation”) even between documents
that aren’t actually about the same thing. This is a property of hybrid
search, not a bug to clean up – it is exactly what happened, for
example, when mixing ESS survey documentation with DDI Alliance standard
pages in the prototype. If it becomes a problem, keeping “content” and
“reference standard” material in separate stores, or filtering retrieved
chunks by their `origin`, are both options; SurveyDokum does not do
either of these for you.

## Step 5: Connect the store to SurveyDokum

Once you have a working store, SurveyDokum’s own functions pick it up
via the `store` argument – everything from here on is a thin retrieval
step in front of the prompt SurveyDokum was already building:

``` r

library(SurveyDokum)

store <- ragnar_store_connect(store_path)
data <- sd_read("survey_data.csv")

# Retrieval alone, for inspection -- one query per variable, using its name and label:
context <- sd_retrieve_context(data, store, top_k = 2)
cat(context)

# Used automatically by the documentation functions:
sd_document(data, model = "gemma3:12b", store = store)
sd_generate_roxygen(data, "survey_data", store = store)
```

`store` defaults to `NULL` everywhere in SurveyDokum, which skips
retrieval entirely – every example in the “Getting started” vignette
that does not mention `store` behaves exactly as before this feature
existed. `top_k` (default `2`) controls how many chunks are retrieved
per variable;
[`sd_retrieve_context()`](https://dariah-fi-surveyai.github.io/SurveyDokum/reference/sd_retrieve_context.md)’s
`max_chars` (default `600`) truncates each retrieved chunk before it is
inserted into the prompt, so a handful of long reference entries can’t
dominate it.

If a query fails against the store (e.g. it is unreachable, or the
embedding model is not running),
[`sd_retrieve_context()`](https://dariah-fi-surveyai.github.io/SurveyDokum/reference/sd_retrieve_context.md)
turns that into a warning rather than an error and simply omits that
variable’s background material – an unavailable reference store never
blocks documentation from being generated.

## Summary – all commands in sequence

``` r

library(ragnar)
library(SurveyDokum)

# 1.-2. Read documents and clean PDF noise
pdf_files <- list.files("path/to/reference_pdfs", pattern = "\\.pdf$", full.names = TRUE)
markdown_docs <- lapply(pdf_files, read_pdf_fallback)
names(markdown_docs) <- basename(pdf_files)

# 3. Chunk and build the store (once)
store_path <- file.path("path/to", "my_reference.ragnar.duckdb")
store <- ragnar_store_create(
  location = store_path,
  embed = embed_ollama(model = "embeddinggemma:300m"),
  overwrite = TRUE
)
for (doc_name in names(markdown_docs)) {
  ragnar_store_insert(store, markdown_chunk(markdown_docs[[doc_name]]))
}
ragnar_store_build_index(store)

# On later runs, just connect:
store <- ragnar_store_connect(store_path)

# 4. Try it
print_ragnar_hits(ragnar_retrieve(store, "your query here", top_k = 5))

# 5. Use it with SurveyDokum
data <- sd_read("survey_data.csv")
sd_document(data, model = "gemma3:12b", store = store)
sd_generate_roxygen(data, "survey_data", store = store)
```
