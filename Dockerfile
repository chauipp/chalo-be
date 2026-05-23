ARG PNPM_VERSION=11.1.3
ARG NODE_VERSION=24-alpine

# 1. Base stage
FROM node:${NODE_VERSION} AS base
ARG PNPM_VERSION
RUN npm install -g pnpm@${PNPM_VERSION}

# 2. Deps stage
FROM base AS deps
WORKDIR /app
COPY package.json pnpm-lock.yaml ./
RUN pnpm install --frozen-lockfile

# 3. Prod-deps stage
FROM base AS prod-deps
WORKDIR /app
COPY package.json pnpm-lock.yaml ./
RUN pnpm install --frozen-lockfile --prod

# 4. Builder stage
FROM base AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .
RUN pnpm run build

# 5. Runner stage
FROM node:24-alpine AS runner

RUN addgroup -S appgroup && adduser -S appuser -G appgroup

WORKDIR /app

RUN mkdir -p /app/uploads

COPY --from=builder /app/dist ./dist
COPY --from=prod-deps /app/node_modules ./node_modules
COPY --from=builder /app/package.json ./package.json

# chown 1 lần sau khi copy xong
RUN chown -R appuser:appgroup /app

ENV NODE_ENV=production
ENV PORT=8080

USER appuser

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
  CMD wget -qO- http://localhost:8080/api/health || exit 1

CMD ["node", "dist/main.js"]