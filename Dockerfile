FROM ubuntu:22.04 AS builder-base

# Install dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    wget \
    unzip \
    xz-utils \
    blender \
    python3 \
    python3-pip \
    xorg \
    && rm -rf /var/lib/apt/lists/*

# Install Godot 4.5 standard binary for exporting
WORKDIR /godot
RUN wget -q https://github.com/godotengine/godot-builds/releases/download/4.5-stable/Godot_v4.5-stable_linux.x86_64.zip && \
    unzip Godot_v4.5-stable_linux.x86_64.zip && \
    rm Godot_v4.5-stable_linux.x86_64.zip && \
    mv Godot_v4.5-stable_linux.x86_64 godot && \
    chmod +x godot

# Install Godot 4.5 export templates (matching engine version)
RUN wget -q https://github.com/godotengine/godot-builds/releases/download/4.5-stable/Godot_v4.5-stable_export_templates.tpz && \
    mkdir -p /root/.local/share/godot/export_templates/4.5.stable && \
    unzip Godot_v4.5-stable_export_templates.tpz && \
    mv templates/* /root/.local/share/godot/export_templates/4.5.stable/ && \
    rm -rf templates Godot_v4.5-stable_export_templates.tpz

ENV PATH="/godot:${PATH}"

# Install Blender 4.4
RUN wget -q https://mirrors.dotsrc.org/blender/release/Blender4.4/blender-4.4.0-linux-x64.tar.xz \
    && tar xvf blender-4.4.0-linux-x64.tar.xz && mv -v $(ls -d */ | grep blender) /usr/local/bin/blender \
    && rm -f blender-4.4.0-linux-x64.tar.xz

RUN /usr/local/bin/blender/blender --background --python-expr "import bpy; bpy.ops.wm.save_as_mainfile(filepath='/tmp/import_check.blend')"

# Set Blender path in Godot editor settings
RUN godot --headless --verbose --editor --quit
RUN echo 'filesystem/import/blender/blender_path = "/usr/local/bin/blender/blender"' >> ~/.config/godot/editor_settings-4.5.tres


# Build the binary
FROM builder-base AS builder

WORKDIR /GIGABAH
COPY . /GIGABAH

RUN mkdir -p .dist/linux-server
RUN godot --headless --verbose --export-release --quit   "Linux Server"


# Final image for deployment
FROM debian:bookworm-slim

COPY --from=builder /GIGABAH/.dist/linux-dedicated.x86_64 /app/linux-dedicated.x86_64
WORKDIR /app

EXPOSE 25445/udp
EXPOSE 25445/tcp

RUN chmod +x ./linux-dedicated.x86_64

CMD ["./linux-dedicated.x86_64", "--headless", "--server"]
