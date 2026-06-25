FROM rocker/r-ver:4.6

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    gnupg \
    git \
    && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && apt-get purge -y gnupg \
    && rm -rf /var/lib/apt/lists/*

RUN npm install -g markdownlint-cli2@0.22.1 \
    && npm cache clean --force

ARG QUARTO_VERSION=1.9.38
ARG TARGETARCH=amd64
RUN curl -fsSL "https://github.com/quarto-dev/quarto-cli/releases/download/v${QUARTO_VERSION}/quarto-${QUARTO_VERSION}-linux-${TARGETARCH}.deb" \
        -o quarto.deb \
    && dpkg -i quarto.deb \
    && rm quarto.deb

ARG TYPOS_VERSION=1.47.2
RUN case "${TARGETARCH}" in \
        amd64) TYPOS_ARCH="x86_64-unknown-linux-musl" ;; \
        arm64) TYPOS_ARCH="aarch64-unknown-linux-musl" ;; \
        *) echo "WARNING: typos not available for arch ${TARGETARCH}, skipping" && exit 0 ;; \
    esac \
    && curl -fSL "https://github.com/crate-ci/typos/releases/download/v${TYPOS_VERSION}/typos-v${TYPOS_VERSION}-${TYPOS_ARCH}.tar.gz" \
        -o /tmp/typos.tar.gz \
    && tar xz -C /usr/local/bin -f /tmp/typos.tar.gz ./typos \
    && rm /tmp/typos.tar.gz

RUN install2.r --error --ncpus -1 \
    languageserver \
    knitr \
    rmarkdown \
    jsonlite \
    pwr \
    WebPower \
    Superpower
