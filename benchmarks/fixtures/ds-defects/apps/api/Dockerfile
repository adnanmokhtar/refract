FROM node:22.20-bookworm-slim AS build
WORKDIR /app
COPY package.json pnpm-lock.yaml ./
RUN corepack enable && pnpm install --frozen-lockfile
COPY . .
RUN pnpm build

FROM node:22.20-bookworm-slim
WORKDIR /app
ENV NODE_ENV=production
ENV TZ=Europe/Berlin
COPY --from=build /app/node_modules ./node_modules
COPY --from=build /app/dist ./dist
USER 10001
CMD ["node", "dist/main.js"]
