# RAGin käyttö SurveyDokumin kanssa

## Mitä tämä opas kattaa

SurveyDokumin LLM-pohjainen dokumentaatio
([`sd_document()`](https://dariah-fi-surveyai.github.io/SurveyDokum/reference/sd_document.md),
[`sd_generate_roxygen()`](https://dariah-fi-surveyai.github.io/SurveyDokum/reference/sd_generate_roxygen.md))
kirjoittaa oletuksena pelkästään
[`sd_summarise()`](https://dariah-fi-surveyai.github.io/SurveyDokum/reference/sd_summarise.md):n
laskemista tilastoista. RAG (*Retrieval-Augmented Generation*)
mahdollistaa sen, että mallille syötetään lisäksi itse valitsemaasi
taustamateriaalia – survey-metodologian sanasto, kontrolloitu sanasto,
aiemmat koodikirjat tyylimalleina, kaksikielinen termistö – jotta
kirjoitus nojaa muuhunkin kuin pelkkiin lukuihin ja mallin omaan
yleistietoon.

RAG-tuki SurveyDokumissa on tarkoituksella ohut, **valinnainen** kerros:
SurveyDokum ei rakenna, toimita eikä ylläpidä tietovarastoa puolestasi.
Se ainoastaan *käyttää* sellaista, jonka rakennat itse
[ragnar](https://ragnar.tidyverse.org/)-paketilla valitsemastasi
lähdemateriaalista – omasta survey-metodologian dokumentaatiostasi,
kontrolloiduista sanastoista, aiemmista koodikirjoista, tyylioppaista,
sanastoista tai mistä tahansa muusta, minkä ragnar osaa muuttaa
tekstiksi. Tämä opas käy läpi tällaisen tietovaraston rakentamisen
ragnarilla alusta asti ja sen kytkemisen SurveyDokumin omiin
funktioihin, yleisellä tasolla riippumatta siitä millaista materiaalia
itse tuot mukaan.

Konkreettisena esimerkkinä tämä opas kehitettiin pientä
prototyyppitietovarastoa vasten, joka rakennettiin kourallisesta
European Social Survey (ESS) -dokumentaatio-PDF:iä ja parista
lähdesivustosta – matkan varrella mainitut sudenkuopat ovat sellaisia,
joihin prototyyppiä rakennettaessa oikeasti törmättiin, ei
hypoteettisia, ja ne pätevät samalla tavalla riippumatta siitä millaista
sinun oma lähdemateriaalisi on.

Tämä vinjetti on paketin englanninkielisen vinjetin (“Using RAG with
SurveyDokum”) rinnakkainen suomennos – saatavilla on myös
ruotsinkielinen versio (“Använda RAG med SurveyDokum”). Kaikki kolme
kattavat saman työnkulun.

## Ennakkovaatimukset

``` r

install.packages("ragnar")     # CRAN; tuo mukanaan duckdb-riippuvuuden
install.packages("pdftools")   # varavaihtoehto PDF-lukuun, ks. Vaihe 1
install.packages("rvest")      # varavaihtoehto verkkosivujen lukuun, ks. Vaihe 1
```

ragnar tarvitsee embedding-mallin, joka muuttaa tekstipalat vektoreiksi.
Koska SurveyDokum nojaa jo paikalliseen
[Ollama](https://ollama.com/)-asennukseen
[`sd_document()`](https://dariah-fi-surveyai.github.io/SurveyDokum/reference/sd_document.md)/[`sd_generate_roxygen()`](https://dariah-fi-surveyai.github.io/SurveyDokum/reference/sd_generate_roxygen.md)-funktioissa,
tässä oppaassa käytetään myös Ollama-embedding-mallia, jolloin koko
putki pysyy offline-yhteensopivana – relevanttia kun taustamateriaali on
arkaluontoista (esim. rajoitetun käyttöoikeuden mikrodatan
dokumentaatio):

``` sh
ollama pull embeddinggemma:300m
```

Myös mikä tahansa muu Ollama-embedding-malli toimii – käytä sen nimeä
[`embed_ollama()`](https://ragnar.tidyverse.org/reference/embed_ollama.html)-kutsussa
Vaiheessa 3 alla. Varmista, että Ollama-palvelin on käynnissä
(oletusosoite `http://localhost:11434`).

## Vaihe 1: Lue lähdedokumentit Markdowniksi

ragnarin oma
[`read_as_markdown()`](https://ragnar.tidyverse.org/reference/read_as_markdown.html)
käyttää MarkItDownia, joka lataa oman Python-ympäristönsä (`uv`:n
kautta) ensimmäisellä käyttökerralla, ja säilyttää otsikkorakenteen
parhaiten näistä vaihtoehdoista. Käytännössä se voi kaatua Windowsilla
virheeseen kuten `"Error loading Python module _ragnartools.markitdown"`
– todennäköisesti Windows tai virustorjunta estää jonkin ladatun
natiivikirjaston (esim. `onnxruntime`) suorittamisen. Jos törmäät tähän,
kaksi varapolkua ohittavat Python-ympäristön kokonaan, hinnalla että
tulos on raakaa tekstiä ilman otsikkorakennetta:

``` r

library(ragnar)

# PDF:t, pdftoolsin kautta:
read_pdf_fallback <- function(path) {
  pages <- pdftools::pdf_text(path)
  txt <- paste(pages, collapse = "\n\n---\n\n")
  MarkdownDocument(txt, origin = path)
}

# Verkkosivut, rvestin kautta:
read_html_fallback <- function(url) {
  page <- rvest::read_html(url)
  main_node <- rvest::html_element(page, "main")
  if (length(main_node) == 0 || is.na(main_node)) main_node <- page
  txt <- rvest::html_text2(main_node)
  MarkdownDocument(txt, origin = url)
}
```

Käytä kumpaa reittiä tahansa, joka toimii omalla koneellasi:

``` r

pdf_tiedostot <- list.files("polku/lahdepdft", pattern = "\\.pdf$", full.names = TRUE)
markdown_docs <- lapply(pdf_tiedostot, read_pdf_fallback)   # tai read_as_markdown()
names(markdown_docs) <- basename(pdf_tiedostot)
```

## Vaihe 2: Siivoa toistuvat ylä-/alatunnisteet ja sivunumerot (vain PDF:t)

`pdftools::pdf_text()` palauttaa raa’an sivutekstin, mukaan lukien
toistuvat ylä-/alatunnisteet (esim. dokumentin nimi joka toistuu
jokaisella sivulla) ja sivunumerorivit – nämä päätyvät kohinana
chunkkeihin, jos ne jätetään mukaan. Apufunktio, joka poistaa rivit
jotka *toistuvat* useimmilla sivuilla (sen sijaan että etsittäisiin
tiettyä tekstiä, joten se toimii mille tahansa PDF:lle), kannattaa
kirjoittaa kerran ja käyttää uudelleen:

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

  # Tapaus A: koko rivi toistuu identtisena (lyhyet tunnisteet, sivunumerot)
  line_counts <- table(candidate_lines)
  repeated_lines <- names(line_counts[line_counts >= threshold * n])

  # Tapaus B: vain rivin ALKUOSA toistuu, loppuosan vaihdellessa osioittain
  # (esim. "Vuosikertomus 2024 -- Menetelmät  Luku 3")
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

Käytä sitä ennen tekstin kääräisyä
[`MarkdownDocument()`](https://ragnar.tidyverse.org/reference/MarkdownDocument.html)-kutsuun
eli `read_pdf_fallback()`-funktion sisällä yllä:
`pages <- strip_repeated_headers_footers(pages)`.

## Vaihe 3: Pilko ja rakenna tietovarasto

``` r

store_path <- file.path("polku/kansioon", "oma_tausta.ragnar.duckdb")

store <- ragnar_store_create(
  location = store_path,
  embed = embed_ollama(model = "embeddinggemma:300m"),
  overwrite = TRUE,
  title = "Oma taustamateriaali"
)

for (doc_name in names(markdown_docs)) {
  chunks <- markdown_chunk(markdown_docs[[doc_name]])
  ragnar_store_insert(store, chunks)
}

ragnar_store_build_index(store)
```

Kaksi sudenkuoppaa, jotka kannattaa tietää etukäteen:

- **Lisää jokaisen dokumentin chunkit erikseen, tuoreena
  [`markdown_chunk()`](https://ragnar.tidyverse.org/reference/markdown_chunk.html)-tuloksena.**
  Version 2 -tietovarasto (nykyinen oletus) lisää otsikkokontekstin
  jokaisen chunkin tekstiin automaattisesti insert-vaiheessa. Jos
  yhdistät usean dokumentin chunkit ensin yhdeksi `data.frame`:ksi
  (esim. `do.call(rbind, ...)`) ennen
  [`ragnar_store_insert()`](https://ragnar.tidyverse.org/reference/ragnar_store_insert.html)-kutsua,
  tämä automatiikka rikkoutuu virheeseen
  `"modifying chunks$text is not supported with store@version == 2"`.
  Käy dokumentit läpi silmukassa ja lisää ne sitä mukaa, kuten yllä.
- **[`ragnar_store_build_index()`](https://ragnar.tidyverse.org/reference/ragnar_store_build_index.html)
  täytyy ajaa ennen kuin
  [`ragnar_retrieve()`](https://ragnar.tidyverse.org/reference/ragnar_retrieve.html)
  toimii lainkaan.** Ilman sitä haku kaatuu virheeseen, joka nimeää
  DuckDB:n BM25-funktion (`match_bm25 does not exist`) – indeksi on se,
  joka tekee täystekstihausta mahdollisen, joten se ei ole valinnainen,
  ja se pitää ajaa uudelleen jokaisen uuden lisäyserän jälkeen.

Anna `store_path` absoluuttisena polkuna, ei suhteellisena
tiedostonimenä – jos työhakemisto sattuu olemaan jokin toinen projekti
kun rakennat tietovaraston ensimmäistä kertaa, sinne `.duckdb`-tiedosto
päätyy.

Kun tietovarasto on kerran rakennettu, siihen kannattaa myöhemmillä
ajokerroilla *yhdistää*, ei rakentaa sitä uudelleen:

``` r

if (file.exists(store_path)) {
  store <- ragnar_store_connect(store_path)
} else {
  # ... rakenna kuten yllä ...
}
```

Rakenna uudelleen (`overwrite = TRUE`) vain kun vaihdat embedding-mallia
tai lisäät dokumentteja, jotka haluat indeksoida tyhjästä.

## Vaihe 4: Kokeile hakua suoraan

``` r

osumat <- ragnar_retrieve(store, "kyselysi tähän", top_k = 5)

# ragnar_retrieve() palauttaa tibblen, jossa text-sarake typistyy tulostuksessa --
# käytä pientä apufunktiota nähdäksesi jokaisen osuman koko tekstin:
print_ragnar_hits <- function(hits) {
  for (i in seq_len(nrow(hits))) {
    row <- hits[i, ]
    cat(sprintf("--- osuma %d/%d: %s (merkit %s-%s) ---\n",
                i, nrow(hits), basename(row$origin), row$start, row$end))
    cat(row$text, "\n\n")
  }
}
print_ragnar_hits(osumat)
```

(ESS-pohjaisessa prototyypissä kysely kuten *“Miten poliittista
luottamusta mitataan?”* toi luotettavasti oikeat koodikirjan ja
kyselylomakkeen chunkit – se mikä toimii sinulla hyvin, riippuu täysin
siitä mitä olet indeksoinut.)

[`ragnar_retrieve()`](https://ragnar.tidyverse.org/reference/ragnar_retrieve.html)
yhdistää vektorihaun ja DuckDB:n BM25-täystekstihaun. Tämä kannattaa
tietää, jos yhdistät samaan tietovarastoon käsitteellisesti erilaista
materiaalia (esim. survey-mikrodatan dokumentaatiota ja abstraktin
metadatastandardin kuvausta): BM25 löytää osumia jaetusta sanastosta
(esim. “codebook”, “variable”, “documentation”) vaikka dokumentit eivät
oikeasti käsittelisi samaa asiaa. Tämä on hybridihaun ominaisuus, ei
siivottava bugi – juuri näin kävi esimerkiksi, kun prototyypissä
yhdistettiin ESS-survey-dokumentaatiota DDI Alliance -standardisivujen
kanssa. Jos siitä tulee ongelma, vaihtoehtoja ovat “sisällön” ja
“standarditiedon” pitäminen erillisissä tietovarastoissa, tai osumien
suodattaminen `origin`-kentän perusteella; SurveyDokum ei tee kumpaakaan
puolestasi.

## Vaihe 5: Kytke tietovarasto SurveyDokumiin

Kun tietovarasto toimii, SurveyDokumin omat funktiot ottavat sen
käyttöön `store`-parametrin kautta – kaikki tästä eteenpäin on vain ohut
hakuaskel ennen kehotetta, jonka SurveyDokum rakensi jo muutenkin:

``` r

library(SurveyDokum)

store <- ragnar_store_connect(store_path)
aineisto <- sd_read("aineistoni.csv")

# Pelkkä haku, tarkastelua varten -- yksi kysely per muuttuja, sen nimeä ja
# labelia käyttäen:
tausta <- sd_retrieve_context(aineisto, store, top_k = 2)
cat(tausta)

# Dokumentaatiofunktiot käyttävät sitä automaattisesti:
sd_document(aineisto, model = "gemma3:12b", store = store)
sd_generate_roxygen(aineisto, "survey_data", store = store)
```

`store` on oletuksena `NULL` kaikkialla SurveyDokumissa, mikä ohittaa
haun kokonaan – jokainen “Uuden surveypaketin perustaminen”-vinjetin
esimerkki, jossa `store`:a ei mainita, toimii täsmälleen kuten ennen
tätä ominaisuutta. `top_k` (oletus `2`) ohjaa kuinka monta chunkkia
haetaan per muuttuja;
[`sd_retrieve_context()`](https://dariah-fi-surveyai.github.io/SurveyDokum/reference/sd_retrieve_context.md):n
`max_chars` (oletus `600`) typistää jokaisen haetun chunkin ennen kuin
se lisätään kehotteeseen, jotta muutama pitkä lähdeteksti ei pääse
hallitsemaan sitä.

Jos kysely epäonnistuu tietovarastoa vasten (esim. se ei ole
tavoitettavissa tai embedding-malli ei ole käynnissä),
[`sd_retrieve_context()`](https://dariah-fi-surveyai.github.io/SurveyDokum/reference/sd_retrieve_context.md)
muuttaa sen varoitukseksi kaatumisen sijaan ja jättää yksinkertaisesti
kyseisen muuttujan taustamateriaalin pois – tavoittamaton tietovarasto
ei koskaan estä dokumentaation syntymistä.

## Yhteenveto – kaikki komennot peräkkäin

``` r

library(ragnar)
library(SurveyDokum)

# 1.-2. Lue dokumentit ja siivoa PDF-kohina
pdf_tiedostot <- list.files("polku/lahdepdft", pattern = "\\.pdf$", full.names = TRUE)
markdown_docs <- lapply(pdf_tiedostot, read_pdf_fallback)
names(markdown_docs) <- basename(pdf_tiedostot)

# 3. Pilko ja rakenna tietovarasto (kerran)
store_path <- file.path("polku/kansioon", "oma_tausta.ragnar.duckdb")
store <- ragnar_store_create(
  location = store_path,
  embed = embed_ollama(model = "embeddinggemma:300m"),
  overwrite = TRUE
)
for (doc_name in names(markdown_docs)) {
  ragnar_store_insert(store, markdown_chunk(markdown_docs[[doc_name]]))
}
ragnar_store_build_index(store)

# Myöhemmillä ajokerroilla riittää yhdistäminen:
store <- ragnar_store_connect(store_path)

# 4. Kokeile
print_ragnar_hits(ragnar_retrieve(store, "kyselysi tähän", top_k = 5))

# 5. Käytä SurveyDokumin kanssa
aineisto <- sd_read("aineistoni.csv")
sd_document(aineisto, model = "gemma3:12b", store = store)
sd_generate_roxygen(aineisto, "survey_data", store = store)
```
