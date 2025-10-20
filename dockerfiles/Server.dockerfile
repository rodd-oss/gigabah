FROM debian:bookworm-slim
ARG VER=latest

COPY .dist/linux-dedicated_${VER}.x86_64 /app/linux-dedicated.x86_64
WORKDIR /app

EXPOSE 25445/udp
EXPOSE 25445/tcp

RUN chmod +x ./linux-dedicated.x86_64

CMD ["./linux-dedicated.x86_64", "--headless", "--server"]
