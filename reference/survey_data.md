# survey_data

Kyselytutkimusaineisto, jossa on tietoja 200 vastaajasta. Aineisto on
kerätty avoimella kyselyllä ja sisältää demografisia tietoja sekä
vastauksia erilaisiin Likert-asteikkoihin ja avoimeen palautteeseen.

## Usage

``` r
survey_data
```

## Format

Dataframe, jossa 200 riviä ja 17 muuttujaa:

- vastaaja_id:

  Vastaajan tunnus. Tyyppi: id. Arvot: jatkuva / avoin. Puuttuvat: 0

- ika_luokka:

  Vastaajan ikäluokka. Tyyppi: nominal. Arvot: jatkuva / avoin.
  Puuttuvat: 0

- sukupuoli:

  Vastaajan sukupuoli. Tyyppi: nominal. Arvot: jatkuva / avoin.
  Puuttuvat: 0

- koulutus:

  Vastaajan koulutustaso. Tyyppi: nominal. Arvot: jatkuva / avoin.
  Puuttuvat: 0

- tyosuhde:

  Vastaajan työsopimuksen tyyppi. Tyyppi: nominal. Arvot: jatkuva /
  avoin. Puuttuvat: 0

- tyovuodet:

  Vastaajan työvuodet. Tyyppi: continuous. Arvot: jatkuva / avoin.
  Puuttuvat: 0

- tt1:

  Likert-asteikon 1 tulos. Tyyppi: likert. Arvot: jatkuva / avoin.
  Puuttuvat: 0

- tt2:

  Likert-asteikon 2 tulos. Tyyppi: likert. Arvot: jatkuva / avoin.
  Puuttuvat: 0

- tt3:

  Likert-asteikon 3 tulos. Tyyppi: likert. Arvot: jatkuva / avoin.
  Puuttuvat: 0

- tt4:

  Likert-asteikon 4 tulos. Tyyppi: likert. Arvot: jatkuva / avoin.
  Puuttuvat: 0

- joh1:

  Likert-asteikon 1 tulos johtamisyhteyksien arviointiin. Tyyppi:
  likert. Arvot: jatkuva / avoin. Puuttuvat: 0

- joh2:

  Likert-asteikon 2 tulos johtamisyhteyksien arviointiin. Tyyppi:
  likert. Arvot: jatkuva / avoin. Puuttuvat: 0

- joh3:

  Likert-asteikon 3 tulos johtamisyhteyksien arviointiin. Tyyppi:
  likert. Arvot: jatkuva / avoin. Puuttuvat: 0

- imu1:

  Likert-asteikon 1 tulos innovaatiokulttuurin arviointiin. Tyyppi:
  likert. Arvot: jatkuva / avoin. Puuttuvat: 0

- imu2:

  Likert-asteikon 2 tulos innovaatiokulttuurin arviointiin. Tyyppi:
  likert. Arvot: jatkuva / avoin. Puuttuvat: 0

- imu3:

  Likert-asteikon 3 tulos innovaatiokulttuurin arviointiin. Tyyppi:
  likert. Arvot: jatkuva / avoin. Puuttuvat: 0

- avoin_palaute:

  Vastaajan avoin palaute. Tyyppi: text. Arvot: jatkuva / avoin.
  Puuttuvat: 22
