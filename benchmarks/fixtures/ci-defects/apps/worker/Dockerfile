# worker: the BullMQ consumer for invoices and e-mails.
FROM node:20-bookworm-slim AS base
WORKDIR /app
USER root
RUN mkdir -p /app/tmp

FROM base AS build
COPY package.json package-lock.json ./
RUN npm install
COPY . .
RUN npm run build

FROM base
ENV NODE_ENV=production
ENV PORT=8081
COPY --from=build /app/node_modules ./node_modules
COPY --from=build /app/dist ./dist
COPY entrypoint.sh ./
EXPOSE 8081
HEALTHCHECK --interval=30s CMD ["node", "-e", "fetch('http://localhost:3000/healthz').then(r => process.exit(r.ok ? 0 : 1)).catch(() => process.exit(1))"]
ENTRYPOINT ["./entrypoint.sh"]
