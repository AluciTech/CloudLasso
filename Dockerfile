FROM ubuntu:24.04

RUN apt-get update -qq && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    wget curl ca-certificates sudo fuse3 libnotify-bin unzip && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

RUN useradd -m -s /bin/bash Talos && \
    echo "Talos ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

USER Talos

WORKDIR /workspace
COPY --chown=Talos:Talos . /workspace

SHELL ["/bin/bash", "-l", "-c"]
CMD ["bash"]
