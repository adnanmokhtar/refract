# syntax=docker/dockerfile:1.6

FROM node:20-bookworm AS build
WORKDIR /app
COPY package.json package-lock.json .npmrc ./
# The private @marketly packages need a registry token; it is passed as a BuildKit secret
# so it never lands in a layer.
RUN --mount=type=secret,id=npm_token NPM_TOKEN="$(cat /run/secrets/npm_token)" npm ci
COPY . .
RUN npx prisma generate && npm run build

FROM node:20-bookworm
WORKDIR /app
ENV NODE_ENV=production
# ImageMagick and git back the thumbnail and theme-install features.
RUN apt-get update && apt-get install -y --no-install-recommends imagemagick webp git \
    && rm -rf /var/lib/apt/lists/*
ARG NPM_TOKEN
ENV NPM_TOKEN=${NPM_TOKEN}
COPY --from=build /app/package.json /app/package-lock.json /app/.npmrc ./
RUN npm ci --omit=dev
COPY --from=build /app/dist ./dist
COPY --from=build /app/prisma ./prisma
COPY --from=build /app/node_modules/.prisma ./node_modules/.prisma
RUN mkdir -p public/uploads storage/attachments storage/exports storage/themes
EXPOSE 3000
CMD ["node", "dist/main.js"]
