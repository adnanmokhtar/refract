FROM golang:1.27 AS build
WORKDIR /src
COPY . .
RUN CGO_ENABLED=0 go build -o /out/edge ./cmd/edge

FROM gcr.io/distroless/static-debian12
ENV TZ=Europe/London
COPY --from=build /out/edge /edge
USER 65532
ENTRYPOINT ["/edge"]
