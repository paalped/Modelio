# Modelio — produksjonsklar Apple Silicon build

Native macOS ARM64-build via **full Eclipse 4.24-oppgradering** (Strategy B).

## Arkitektur

| Komponent | Versjon | Merknad |
|-----------|---------|---------|
| Eclipse RCP | **4.24** (2022-06) | Remote p2 + valgfri lokal mirror |
| Tycho | **2.7.5** | Oppgradert fra 2.2.0 |
| Java (build) | **11** arm64 | Temurin via Homebrew |
| Java (runtime) | **11** | Bundles via Temurin JRE feature |
| SWT / Launcher | **4.24 native** | `cocoa.macosx.aarch64` inkludert |
| ECF HTTP | **httpclient5** | Erstatter httpclient45 fra 4.18 |

## Forutsetninger

```bash
./scripts/setup-macos-arm64.sh
cp AGGREGATOR/toolchains.xml ~/.m2/toolchains.xml
```

Verifiser:

```bash
export JAVA_HOME="/opt/homebrew/opt/openjdk@11/libexec/openjdk.jdk/Contents/Home"
export PATH="$JAVA_HOME/bin:$PATH"
export ECLIPSE_WS="$(pwd)"   # repo-rot
java -version && mvn -version && uname -m
```

## Byggeløp (produksjon)

### 1. Regenerer RCP-features (ved Eclipse-oppgradering)

```bash
python3 scripts/regenerate-modelio-rcp-features.py
```

Henter `org.eclipse.{e4.rcp,rcp,platform}` fra Eclipse 4.24 og mapper til `org.modelio.*`.

### 2. Valgfritt: lokal offline-mirror

```bash
./scripts/mirror-eclipse-platform.sh
```

### 3. Valgfritt: bundle JRE arm64 i produktet

```bash
chmod +x scripts/fetch-macos-aarch64-jre.sh
./scripts/fetch-macos-aarch64-jre.sh
```

### 4. Fiks manglende ressursmapper (upstream)

```bash
python3 scripts/fix-missing-bin-includes.py
```

### 5. Kompiler alle plugins

```bash
export ECLIPSE_WS="$(pwd)"
cd AGGREGATOR
mvn clean install -DskipTests
```

Varighet: 30–90 min første gang.

### 6. Pakk macOS ARM64-produkt

```bash
export ECLIPSE_WS="$(pwd)"
cd AGGREGATOR/products
mvn clean install -Pproduct.org,platform.mac.aarch64 -DskipTests
```

Output:

Artefakt (verifisert 2026-07-15):

```
products/target/products/org.modelio.product-macosx.cocoa.aarch64.tar.gz  (~199 MB)
```

Innhold: `Modelio 5.4.1.app` med `Mach-O 64-bit executable arm64`.

### 7. Verifiser native ARM64

```bash
PRODUCT="products/target/products/org.modelio.product/OpenSource/macosx/cocoa/aarch64/Modelio 5.4.1"
file "$PRODUCT/modelio.app/Contents/MacOS/modelio"
# → Mach-O 64-bit executable arm64
```

## Endringer i denne fork

### Plattform

- `pom.xml` / `maven/modelio-parent/pom.xml`: Eclipse 4.24 remote p2, fjernet separat SWT-repo
- `dev-platform/rcp-target/rcp.target`: Remote 4.24 IU-er med `includeAllPlatforms`
- `features/opensource/org.modelio.{e4.rcp,rcp,platform.feature}`: regenerert fra 4.24
- `products/modelio-os.product`: `httpclient5` feature
- `products/pom.xml`: `platform.mac.aarch64` profil + macOS tar.gz
- Tycho 2.7.5 overalt

### Scripts

| Script | Formål |
|--------|--------|
| `setup-macos-arm64.sh` | JDK 11, Maven, toolchains |
| `regenerate-modelio-rcp-features.py` | Synk Modelio RCP-features med Eclipse |
| `mirror-eclipse-platform.sh` | Offline p2-mirror av 4.24 |
| `fetch-macos-aarch64-jre.sh` | Temurin JRE 11 arm64 for produktbundle |

## Kjente begrensninger

1. **astyle** — kun x86_64 macOS native; Java-formatering kan feile på ARM64
2. **Babel FR** — fortsatt 4.18 NLS; de fleste strenger fungerer, noen kan mangle
3. **JavaSE-1.8 BREE** — plugins kompileres med JDK 11 toolchain (Java 8 ikke tilgjengelig på arm64 Homebrew)
4. **Code signing** — produktet er usignert; bruk `xattr -cr modelio.app` for lokal test
5. **macOS Dark Mode** — Modelio tvinger Light appearance + cocoa CSS (`default.cocoa.css`) for lesbar dialogtekst

## Feilsøking

| Problem | Løsning |
|---------|---------|
| `no toolchain JavaSE-1.8` | `cp AGGREGATOR/toolchains.xml ~/.m2/toolchains.xml` |
| `ECLIPSE_WS not set` | `export ECLIPSE_WS=/path/to/MODELIO` |
| Tycho-versjonskonflikt | `mvn install -N` fra repo-rot |
| Gatekeeper blokkerer app | `xattr -cr modelio.app` |
| Hvit tekst på hvit bakgrunn | `modelio.ini` skal ha `-Dorg.eclipse.swt.display.useSystemTheme=false`; cocoa CSS i `org.modelio.app.ui` |
| Unable to locate a Java Runtime | Legg til `-vm` + sti til Java 11 i `modelio.ini`, eller bundle JRE |

## Videre arbeid

- [ ] CI på `macos-latest` (GitHub Actions arm64)
- [ ] Oppgradere Babel FR til 4.24
- [ ] Bygge / erstatte astyle for arm64
- [ ] Code signing + notarization for distribusjon

## Referanser

- [Modelio Build Guide](https://github.com/ModelioOpenSource/Modelio/wiki/Build-Modelio-Index)
- [Issue #125 — Apple Silicon](https://github.com/ModelioOpenSource/Modelio/issues/125)
- [Eclipse 4.24 p2](https://download.eclipse.org/eclipse/updates/4.24/R-4.24-202206070700)
