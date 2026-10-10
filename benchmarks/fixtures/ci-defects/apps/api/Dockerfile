# syntax=docker/dockerfile:1.7
# api: NestJS 11 on Fastify. Three stages: production dependencies, the build, the runtime.

FROM node:22-alpine AS deps
WORKDIR /app
COPY package.json pnpm-lock.yaml ./
RUN corepack enable && pnpm install --prod --frozen-lockfile

FROM node:22-alpine AS build
WORKDIR /app
ARG NPM_TOKEN
ENV NPM_TOKEN=${NPM_TOKEN}
COPY . .
RUN corepack enable && pnpm install --prefer-offline
RUN pnpm build

FROM node:22-bookworm-slim
WORKDIR /app
ENV NODE_ENV=production
COPY --from=deps /app/node_modules ./node_modules
COPY --from=build /app/dist ./dist
COPY package.json ./
USER node
EXPOSE 3000
HEALTHCHECK --interval=30s --timeout=3s CMD curl -fsS http://localhost:3000/health || exit 1
CMD npm start
