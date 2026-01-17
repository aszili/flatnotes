# ----------------------------
# Fetch source
# ----------------------------
FROM alpine:3.23 AS source

ARG FLATNOTES_VERSION=v5.5.4
WORKDIR /src

RUN apk add --no-cache curl tar

RUN echo "Downloading version: $FLATNOTES_VERSION"

RUN curl -fsSL "https://github.com/dullage/flatnotes/archive/refs/tags/${FLATNOTES_VERSION}.tar.gz" \
    -o flatnotes.tar.gz \
 && tar -xzf flatnotes.tar.gz --strip-components=1 \
 && rm flatnotes.tar.gz \
 && test -d server \
 && test -d client

# ----------------------------
# Frontend build stage
# ----------------------------
FROM node:25-alpine AS frontend-builder

WORKDIR /build
COPY --from=source /src/client ./client
RUN cd client && npm ci && npm run build

# ----------------------------
# Backend build stage
# ----------------------------
FROM python:3.14-alpine AS backend-builder

WORKDIR /build
COPY --from=source /src/server ./server
COPY --from=source /src/pyproject.toml ./pyproject.toml
COPY --from=source /src/poetry.lock ./poetry.lock
RUN pip install --prefix=/install --no-cache-dir .

# ----------------------------
# Runtime image (distroless)
# ----------------------------

FROM gcr.io/distroless/python3-debian12

WORKDIR /opt/flatnotes

COPY --from=backend-builder /install /usr/local
COPY --from=backend-builder /build/server ./server
COPY --from=frontend-builder /build/client/dist ./client/dist
COPY docker-entrypoint.py /entrypoint.py

ENTRYPOINT ["python", "/entrypoint.py"]