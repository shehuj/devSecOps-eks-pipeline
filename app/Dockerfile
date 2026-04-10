# syntax=docker/dockerfile:1.7
FROM python:3.13-alpine3.21 AS base

# Create non-root user
RUN addgroup -S -g 10001 appgroup && adduser -S -u 10001 -G appgroup appuser

WORKDIR /app

# ── Build stage: install dependencies ──────────────────────────────────────────
FROM base AS builder

COPY requirements.txt .
# Upgrade pip + setuptools first to avoid bundled-version CVEs (e.g. CVE-2024-6345 in setuptools <70)
RUN pip install --no-cache-dir --upgrade pip setuptools && \
    pip install --no-cache-dir --user -r requirements.txt

# ── Final stage: minimal runtime image ─────────────────────────────────────────
FROM base AS final

# Copy installed packages from builder (avoids pip in final image)
COPY --from=builder /root/.local /home/appuser/.local

COPY src/ ./src/

USER appuser

ENV PATH=/home/appuser/.local/bin:$PATH \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

EXPOSE 5000

HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD wget -q --spider http://localhost:5000/health || exit 1

CMD ["gunicorn", "--bind", "0.0.0.0:5000", "--workers", "2", "src.app:app"]
