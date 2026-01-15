# ---------- Build Stage ----------
FROM golang:1.22-alpine AS builder

WORKDIR /app

COPY go.mod ./
RUN go mod tidy

COPY . .

RUN go build -o main .

# ---------- Runtime Stage ----------
FROM gcr.io/distroless/base-debian12

WORKDIR /app

COPY --from=builder /app /app

EXPOSE 8080

CMD ["/app/main"]
