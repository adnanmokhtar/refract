FROM caddy:2.11.7-builder AS build
RUN xcaddy build v2.11.7 \
    --with github.com/pberkel/caddy-storage-redis@v1.4.0 \
    --with github.com/caddyserver/cache-handler@v0.16.0 \
    --with github.com/caddy-dns/route53@v1.6.0

FROM caddy:2.11.7
COPY --from=build /usr/bin/caddy /usr/bin/caddy
