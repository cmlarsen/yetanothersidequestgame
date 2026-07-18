# syntax=docker/dockerfile:1
# yas-server — two-stage build (DESIGN §Ops), shape ported from the SideQuestAppV2
# Dockerfile. The whole package runs as .ts via tsx (no emit step), so the build
# stage only exists to compile better-sqlite3's native addon on the target base.
# Typecheck + tests deliberately do NOT run here — `npm run deploy` runs ci:fast
# locally first, where it fails before any image is built.

# ---- build stage: install deps (native toolchain for better-sqlite3) ----
FROM node:22-slim AS build
RUN apt-get update \
  && apt-get install -y --no-install-recommends python3 make g++ \
  && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci

# ---- runtime stage: the single game process ----
FROM node:22-slim AS runtime
WORKDIR /app
ENV NODE_ENV=production \
    PORT=8080 \
    DATA_DIR=/data \
    TICK_HZ=10 \
    AUTOSAVE_MS=15000
# Reuse the natively-built node_modules from the build stage.
COPY --from=build /app/node_modules ./node_modules
COPY package.json package-lock.json tsconfig.json main.ts config.ts app.ts ./
COPY shared ./shared
COPY sim ./sim
COPY net ./net
COPY persistence ./persistence
# The sqlite volume mounts here (fly.toml [[mounts]] destination = "/data").
RUN mkdir -p /data
EXPOSE 8080
# npm start === "tsx main.ts" — config → db → world → loop → http → gateway → listen.
CMD ["npm", "start"]
