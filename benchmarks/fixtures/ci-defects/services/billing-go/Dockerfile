# billing-go: the invoicing API. Built static, shipped distroless.
ARG APP_VERSION=dev

FROM --platform=linux/amd64 golang:1.24-bookworm AS build
WORKDIR src
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN cd cmd/billing && go vet ./...
RUN CGO_ENABLED=0 go build -ldflags "-X main.version=${APP_VERSION}" -o /out/billing ./cmd/billing

FROM gcr.io/distroless/static-debian12:nonroot
COPY --from=build /out/billing /billing
CMD ["/billing", "migrate"]
EXPOSE 8080
CMD ["/billing"]
