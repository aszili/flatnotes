ARG FLATNOTES_VERSION=v5.5.4

# ----------------------------
# Fetch source
# ----------------------------
FROM alpine:3.23 AS source

ARG FLATNOTES_VERSION
WORKDIR /src

RUN apk add --no-cache curl tar

RUN curl -fsSL \
    https://github.com/dullage/flatnotes/archive/refs/tags/${FLATNOTES_VERSION}.tar.gz \
  | tar -xz --strip-components=1

# ----------------------------
# Frontend build stage
# ----------------------------
FROM node:20-alpine AS frontend-builder

WORKDIR /build
COPY client ./client
RUN cd client && npm ci && npm run build

# ----------------------------
# Backend build stage
# ----------------------------
FROM python:3.11-alpine AS backend-builder

WORKDIR /build
COPY server ./server
COPY pyproject.toml poetry.lock ./
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