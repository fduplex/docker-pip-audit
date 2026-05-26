ARG UV_VERSION=latest
FROM ghcr.io/astral-sh/uv:${UV_VERSION} AS uv

FROM debian:trixie-slim
ENV DEBIAN_FRONTEND="noninteractive" \
    UV_LINK_MODE="copy"

COPY --from=uv /uv /uvx /bin/

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
