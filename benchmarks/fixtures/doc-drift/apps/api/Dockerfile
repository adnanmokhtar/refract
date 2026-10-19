FROM node:22-alpine AS build
WORKDIR /app
RUN corepack enable
COPY . .
RUN pnpm install --frozen-lockfile && pnpm --filter @tallyhook/api build

FROM node:22-alpine
WORKDIR /app
COPY --from=build /app/apps/api/dist ./dist
COPY --from=build /app/node_modules ./node_modules
EXPOSE 3000
CMD ["node", "dist/main.js"]
