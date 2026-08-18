FROM golang:1.25-bookworm AS build
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -trimpath -ldflags="-s -w" -o /out/sample-service ./cmd/sample-service

FROM gcr.io/distroless/static-debian12:nonroot
WORKDIR /
COPY --from=build /out/sample-service /sample-service
USER nonroot:nonroot
EXPOSE 8080
ENTRYPOINT ["/sample-service"]
