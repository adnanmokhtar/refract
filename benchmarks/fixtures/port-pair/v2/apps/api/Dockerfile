FROM node:22.11-bookworm-slim
WORKDIR /srv/api
ENV NODE_ENV=production
COPY dist ./dist
COPY node_modules ./node_modules
USER node
CMD ["node", "dist/main.js"]
