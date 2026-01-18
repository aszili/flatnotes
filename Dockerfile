# ----------------------------
# Fetch source from git
# ----------------------------
FROM alpine:3.23 AS source

ARG FLATNOTES_VERSION=5.5.4
WORKDIR /src

RUN apk add --no-cache git curl unzip nodejs npm python3 py3-pip build-base

RUN git clone --branch v${FLATNOTES_VERSION} --depth 1 https://github.com/dullage/flatnotes.git .

# ----------------------------
# Frontend build stage
# ----------------------------
FROM node:25-alpine AS frontend-builder

WORKDIR /build

# Copy frontend source from previous stage
COPY --from=source /src ./

# Build frontend (dist folder)
RUN npm install && npm run build

# ----------------------------
# Backend build stage
# ----------------------------
FROM python:3.14-alpine AS backend-builder

WORKDIR /build

RUN pip install --no-cache-dir fastapi uvicorn pydantic python-multipart python-jose sqlalchemy aiosqlite jinja2

COPY --from=source /src/server ./server

# ----------------------------
# Runtime image (distroless)
# ----------------------------
FROM gcr.io/distroless/python3-debian12

WORKDIR /opt/flatnotes

COPY --from=backend-builder /install /usr/local
COPY --from=backend-builder /build/server ./server
COPY --from=frontend-builder /build/client/dist ./client/dist
COPY docker-entrypoint.py /entrypoint.py

ENV FLATNOTES_HOST=0.0.0.0
ENV FLATNOTES_PORT=8080
ENV FLATNOTES_STATE_DIR=/state

ENTRYPOINT ["python", "/entrypoint.py"]
