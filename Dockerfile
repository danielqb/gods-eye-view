# syntax=docker/dockerfile:1
#
# God's Eye View has no production server: every upstream API is brokered by
# Vite dev-server middleware defined in vite.config.js. `vite preview` only
# installs a subset of those proxies, so this image runs the Vite DEV server
# with HOST=0.0.0.0 - exactly what scripts/dev-fresh.sh does for LAN sharing.
#
# Build:
#   docker build -t gods-eye-view:local .
#
# For a self-hosted/Helm deployment, see the atalaya project's
# GodsEyeView_helm chart, which builds from this same source (by cloning a
# pinned GEV_REF rather than building the checkout directly, for
# reproducibility) and wires in the required API keys as Kubernetes Secrets.

ARG NODE_IMAGE=node:24-bookworm-slim

FROM ${NODE_IMAGE} AS build

# Puppeteer + sharp are devDependencies pulled in by `npm ci`. Puppeteer's
# postinstall would download a ~150 MB Chromium the dev server never uses.
ENV PUPPETEER_SKIP_DOWNLOAD=true \
    npm_config_fund=false \
    npm_config_audit=false

WORKDIR /app
COPY . .

RUN --mount=type=cache,target=/root/.npm \
    npm ci --include=dev

FROM ${NODE_IMAGE} AS runtime

LABEL org.opencontainers.image.title="God's Eye View" \
      org.opencontainers.image.source="https://github.com/bilawalsidhu/gods-eye-view" \
      org.opencontainers.image.description="God's Eye View - photorealistic 3D-globe intelligence console (Vite dev server)"

ENV NODE_ENV=development \
    HOST=0.0.0.0 \
    PORT=4173 \
    CI=true

WORKDIR /app

# The stock `node` user (uid/gid 1000) owns the tree so the Vite optimizer can
# write node_modules/.vite at runtime under a read-only-root-filesystem=false pod.
COPY --from=build --chown=node:node /app /app

USER node
EXPOSE 4173

# `npm run dev` == `vite`. vite.config.js reads HOST/PORT from the environment
# and sets server.allowedHosts=true when HOST=0.0.0.0, so an Ingress hostname
# is accepted.
CMD ["npm", "run", "dev"]
