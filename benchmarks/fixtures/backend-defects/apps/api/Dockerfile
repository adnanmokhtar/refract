FROM node:22.14-bookworm-slim
WORKDIR /app
ENV NODE_ENV=production
ENV TZ=America/New_York
COPY dist ./dist
COPY node_modules ./node_modules
USER 10001
CMD ["node", "dist/main.js"]
