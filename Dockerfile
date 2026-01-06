FROM ghcr.io/astral-sh/uv:latest AS uv

FROM debian:trixie-slim
ENV DEBIAN_FRONTEND="noninteractive" \
    UV_LINK_MODE="copy"

RUN bash -e <<EOF
apt-get install -Uy \
    curl gcc build-essential clang openssl checkinstall \
    libgdbm-dev libc6-dev libtool zlib1g-dev libffi-dev libxslt1-dev
EOF

COPY --from=uv /uv /uvx /bin/

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
