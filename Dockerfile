FROM debian:bookworm-slim AS builder

# Install dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    wget \
    unzip \
    blender \
    python3 \
    python3-pip \
    && rm -rf /var/lib/apt/lists/*

# Install Godot 4.5 standard binary for exporting
WORKDIR /godot
RUN wget -q --show-progress https://github.com/godotengine/godot-builds/releases/download/4.5-stable/Godot_v4.5-stable_linux.x86_64.zip && \
    unzip Godot_v4.5-stable_linux.x86_64.zip && \
    rm Godot_v4.5-stable_linux.x86_64.zip && \
    mv Godot_v4.5-stable_linux.x86_64 godot && \
    chmod +x godot

# Install Godot 4.5 export templates (matching engine version)
RUN wget -q --show-progress https://github.com/godotengine/godot-builds/releases/download/4.5-stable/Godot_v4.5-stable_export_templates.tpz && \
    mkdir -p /root/.local/share/godot/export_templates/4.5.stable && \
    unzip Godot_v4.5-stable_export_templates.tpz && \
    mv templates/* /root/.local/share/godot/export_templates/4.5.stable/ && \
    rm -rf templates Godot_v4.5-stable_export_templates.tpz

WORKDIR /GIGABAH
COPY . /GIGABAH

ENV PATH="/godot:${PATH}"
RUN mkdir -p .dist/linux-server
RUN godot --headless --verbose --export-release "Linux Server"


FROM debian:bookworm-slim

COPY --from=builder /GIGABAH/.dist/linux-server/linux-dedicated.x86_64 /app/linux-dedicated.x86_64
WORKDIR /app

EXPOSE 25445/udp
EXPOSE 25445/tcp

RUN chmod +x ./linux-dedicated.x86_64

CMD ["./linux-dedicated.x86_64", "--headless", "--server"]
