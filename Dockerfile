# syntax=docker/dockerfile:1
FROM node:22-alpine
WORKDIR /app

# Устойчивость к нестабильной сети при скачивании пакетов (ETIMEDOUT / read timeout)
ENV NPM_CONFIG_FETCH_RETRIES=10 \
    NPM_CONFIG_FETCH_RETRY_MINTIMEOUT=20000 \
    NPM_CONFIG_FETCH_RETRY_MAXTIMEOUT=120000 \
    NPM_CONFIG_FETCH_TIMEOUT=300000

# Опционально: зеркало registry (см. README). Пример: --build-arg NPM_REGISTRY=https://registry.npmmirror.com
ARG NPM_REGISTRY=
RUN if [ -n "$NPM_REGISTRY" ]; then npm config set registry "$NPM_REGISTRY"; fi

# Важно: prisma/ ДО npm ci — иначе postinstall (prisma generate) не найдёт schema.prisma
COPY package.json package-lock.json* ./
COPY prisma ./prisma

# Кэш npm между сборками (нужен BuildKit: DOCKER_BUILDKIT=1 или Docker по умолчанию)
RUN --mount=type=cache,target=/root/.npm \
    npm ci --no-audit --no-fund --loglevel=warn

COPY . .

RUN npx prisma generate
RUN npm run build

ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1
EXPOSE 3000

CMD ["sh", "-c", "npx prisma migrate deploy && npm run start"]
