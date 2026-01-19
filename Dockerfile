FROM debian:bookworm-slim AS source

ARG FLATNOTES_VERSION=5.5.4
WORKDIR /src

RUN apt-get update && apt-get install -y --no-install-recommends \
        git ca-certificates \
    && rm -rf /var/lib/apt/lists/*

RUN git clone --branch v${FLATNOTES_VERSION} --depth 1 https://github.com/dullage/flatnotes.git .


# ----------------------------
# Frontend build stage
# ----------------------------
FROM node:25-bullseye-slim AS frontend-builder

WORKDIR /build
COPY --from=source /src ./

RUN npm install && npm run build

# ----------------------------
# Backend build stage
# ----------------------------
FROM python:3.14-slim AS backend-builder

WORKDIR /build

# Install Python deps into a relocatable directory
RUN pip install --no-cache-dir \
        --target /opt/python \
        fastapi \
        uvicorn \
        pydantic \
        python-multipart \
        python-jose \
        sqlalchemy \
        aiosqlite \
        jinja2 \
        whoosh

# Copy backend source
COPY --from=source /src/server ./server


# ----------------------------
# Runtime image (distroless)
# ----------------------------
FROM gcr.io/distroless/python3-debian12

WORKDIR /opt/flatnotes

# Python dependencies
COPY --from=backend-builder /opt/python /opt/python

# Application code
COPY --from=backend-builder /build/server ./server
COPY --from=frontend-builder /build/client/dist ./client/dist
COPY docker-entrypoint.py /entrypoint.py

# Make Python see /opt/python
ENV PYTHONPATH=/opt/python:/opt/flatnotes:/opt/flatnotes/server

ENV FLATNOTES_HOST=0.0.0.0
ENV FLATNOTES_PORT=8080
ENV FLATNOTES_STATE_DIR=/state

ENTRYPOINT ["python3", "/entrypoint.py"]
