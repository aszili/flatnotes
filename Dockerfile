# ----------------------------
# Fetch source from git
# ----------------------------
FROM alpine:3.23 AS source

ARG FLATNOTES_VERSION=5.5.4
WORKDIR /src

RUN apk add --no-cache git

# Clone the repo and checkout the specific tag
RUN git clone --depth 1 --branch v$FLATNOTES_VERSION https://github.com/dullage/flatnotes.git . \
    && test -d server \
    && test -d client

# ----------------------------
# Frontend build stage
# ----------------------------
FROM node:25-alpine AS frontend-builder

WORKDIR /build

# Copy frontend source from previous stage
COPY --from=source /src/client ./client

# Build frontend (dist folder)
RUN cd client \
    && npm install \
    && npm run build

# ----------------------------
# Backend build stage
# ----------------------------
FROM python:3.14-alpine AS backend-builder

WORKDIR /build

# Copy backend source from previous stage
COPY --from=source /src/server ./server
COPY --from=source /src/pyproject.toml ./pyproject.toml
COPY --from=source /src/poetry.lock ./poetry.lock

# Install backend into /install for later copying
RUN pip install --prefix=/install --no-cache-dir ./server

# ----------------------------
# Runtime image (distroless)
# ----------------------------
FROM gcr.io/distroless/python3-debian12

WORKDIR /opt/flatnotes

# Copy backend
COPY --from=backend-builder /install /usr/local
COPY --from=backend-builder /build/server ./server

# Copy frontend dist
COPY --from=frontend-builder /build/client/dist ./client/dist

# Copy entrypoint
COPY docker-entrypoint.py /entrypoint.py

# Run entrypoint
ENTRYPOINT ["python", "/entrypoint.py"]
