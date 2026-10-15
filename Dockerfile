# Bitcoin Core 31.1 (release oficial) para el lab regtest.
# Descarga el tarball de bitcoincore.org y verifica su SHA256 contra los hashes
# fijados abajo (tomados de SHA256SUMS, firmado por 11 builders de guix.sigs).
FROM debian:bookworm-slim

ARG BITCOIN_VERSION=31.1
ARG TARGETARCH
ARG SHA256_AMD64=b80d9c3e04da78fb6f0569685673418cf686fadba9042d926d13fb87ff503f9e
ARG SHA256_ARM64=dcf1873f2208ba4f962f3398d47e154c39c0084be8f4553e05c940d0ace3d004

RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl python3 python3-zmq jq \
 && rm -rf /var/lib/apt/lists/*

RUN set -eu; \
    case "${TARGETARCH:-amd64}" in \
      amd64) ARCH=x86_64;  SHA256="$SHA256_AMD64" ;; \
      arm64) ARCH=aarch64; SHA256="$SHA256_ARM64" ;; \
      *) echo "arquitectura no soportada: $TARGETARCH" >&2; exit 1 ;; \
    esac; \
    TARBALL="bitcoin-${BITCOIN_VERSION}-${ARCH}-linux-gnu.tar.gz"; \
    curl -fsSLO "https://bitcoincore.org/bin/bitcoin-core-${BITCOIN_VERSION}/${TARBALL}"; \
    echo "${SHA256}  ${TARBALL}" | sha256sum -c -; \
    tar -xzf "$TARBALL" --strip-components=1 -C /usr/local \
        "bitcoin-${BITCOIN_VERSION}/bin" "bitcoin-${BITCOIN_VERSION}/libexec"; \
    rm "$TARBALL"; \
    bitcoind --version | head -n1

RUN useradd --create-home --uid 1000 bitcoin
USER bitcoin
WORKDIR /home/bitcoin
RUN mkdir -p /home/bitcoin/.bitcoin

CMD ["bitcoind"]
