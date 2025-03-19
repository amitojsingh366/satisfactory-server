FROM debian:12.4-slim

ARG GID=1000
ARG UID=1000

# Set environment variables. DEBUGGER is set for steamcmd.
ENV AUTOSAVENUM="5" \
    DEBIAN_FRONTEND="noninteractive" \
    DEBUG="false" \
    DISABLESEASONALEVENTS="false" \
    GAMECONFIGDIR="/config/gamefiles/FactoryGame/Saved" \
    GAMESAVESDIR="/home/steam/.config/Epic/FactoryGame/Saved/SaveGames" \
    LOG="false" \
    MAXOBJECTS="2162688" \
    MAXPLAYERS="4" \
    MAXTICKRATE="30" \
    MULTIHOME="::" \
    PGID="1000" \
    PUID="1000" \
    SERVERGAMEPORT="7777" \
    SERVERSTREAMING="true" \
    SKIPUPDATE="false" \
    STEAMAPPID="1690800" \
    STEAMBETA="false" \
    TIMEOUT="30" \
    VMOVERRIDE="false" \
    DEBUGGER="/usr/local/bin/box86"

# Add armhf architecture and install required packages.
RUN dpkg --add-architecture armhf && \
    apt-get update && \
    apt-get install -y \
      curl \
      libc6:armhf \
      vim \
      git \
      cmake \
      python3 \
      gcc-arm-linux-gnueabihf \
      gosu \
      xdg-user-dirs \
      jq \
      procps \
      tzdata && \
    rm -rf /var/lib/apt/lists/*

# Set working directory.
WORKDIR /root

# Build and install Box86.
RUN git clone https://github.com/ptitSeb/box86 && \
    cd box86 && \
    mkdir build && cd build && \
    cmake .. -DARM64=1 -DCMAKE_BUILD_TYPE=RelWithDebInfo && \
    make -j$(nproc) && \
    make install

# Install steamcmd into /steamcmd.
RUN mkdir -p /steamcmd && \
    cd /steamcmd && \
    curl -sqL "https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz" | tar zxvf -

# Build and install Box64.
WORKDIR /root
RUN git clone https://github.com/ptitSeb/box64 && \
    cd box64 && \
    mkdir build && cd build && \
    cmake .. -DARM_DYNAREC=ON -DCMAKE_BUILD_TYPE=RelWithDebInfo && \
    make -j$(nproc) && \
    make install

# Clean up build directories and remove unneeded packages.
RUN rm -rf /root/box86 /root/box64 && \
    apt-get autoremove --purge -y curl vim git cmake python3 gcc-arm-linux-gnueabihf

# Create steam group and user.
RUN set -x && \
    groupadd -g ${GID} steam && \
    useradd -u ${UID} -g ${GID} -ms /bin/bash steam && \
    chown -R ${UID}:${GID} /steamcmd && \
    gosu nobody true

# Create configuration directory.
RUN mkdir -p /config && \
    chown steam:steam /config

RUN mkdir -p /tmp/dump && \
    chown steam:steam /tmp/dump

# Copy init, healthcheck, and run scripts.
COPY init.sh healthcheck.sh /
COPY --chown=steam:steam run.sh /home/steam/

# Set healthcheck.
HEALTHCHECK --timeout=30s --start-period=300s CMD bash /healthcheck.sh

WORKDIR /config

ARG VERSION="DEV"
ENV VERSION=$VERSION
LABEL version=$VERSION

STOPSIGNAL SIGINT
EXPOSE 7777/udp 7777/tcp

# Set entrypoint.
ENTRYPOINT [ "/init.sh" ]
