# ============================================================
# Stage 1: Build RABCDAsm + download all tools
# (buildpack-deps:jammy has gcc, curl, unzip, git, liblzma-dev)
# ============================================================
FROM buildpack-deps:jammy AS builder

ARG JQ_VERSION=1.7.1
RUN curl -fsSL -o /usr/local/bin/jq \
        "https://github.com/jqlang/jq/releases/download/jq-${JQ_VERSION}/jq-linux-amd64" && \
    chmod +x /usr/local/bin/jq

ARG DMD_VERSION=2.109.1
RUN curl -fsSL "https://downloads.dlang.org/releases/2.x/${DMD_VERSION}/dmd.${DMD_VERSION}.linux.tar.xz" \
        | tar xJ -C /opt

RUN git clone --depth 1 https://github.com/CyberShadow/RABCDAsm.git /tmp/rabcdasm
WORKDIR /tmp/rabcdasm
RUN PATH="/opt/dmd2/linux/bin64:$PATH" \
    dmd -run build_rabcdasm.d abcexport rabcdasm rabcasm abcreplace

WORKDIR /
ARG AIR_VERSION=51.2.2.6
ARG AIR_SDK_BASE_URL=https://airsdk.harman.com/api/versions/${AIR_VERSION}/sdks
ARG APPIMAGETOOL_URL=https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage
ARG CACHE_BUST=default

SHELL ["/bin/bash", "-c"]
RUN echo "Downloading tools in parallel..." && \
    curl -fSL -o /tmp/air_sdk.zip       "${AIR_SDK_BASE_URL}/AIRSDK_Linux.zip?license=accepted" & \
    curl -fSL -o /tmp/air_win_sdk.zip   "${AIR_SDK_BASE_URL}/AIRSDK_Windows.zip?license=accepted" & \
    curl -fSL -o /tmp/appimagetool.AppImage "${APPIMAGETOOL_URL}" & \
    wait && \
    mkdir -p /opt/air_sdk && \
    unzip -o -q /tmp/air_sdk.zip -d /opt/air_sdk && \
    chmod -R +x /opt/air_sdk/bin && \
    mkdir -p /opt/air_win_sdk && \
    unzip -o -q /tmp/air_win_sdk.zip 'runtimes/air/win/*' -d /opt/air_win_sdk && \
    chmod +x /tmp/appimagetool.AppImage && \
    cd /tmp && ./appimagetool.AppImage --appimage-extract && \
    mv /tmp/squashfs-root /opt/appimagetool && \
    rm -f /tmp/air_sdk.zip /tmp/air_win_sdk.zip /tmp/appimagetool.AppImage

# Trim AIR SDK and create per-platform lib/ variants
RUN rm -rf \
        /opt/air_sdk/samples /opt/air_sdk/templates \
        /opt/air_sdk/asdoc /opt/air_sdk/atftools \
        /opt/air_sdk/include /opt/air_sdk/ant /opt/air_sdk/install \
        /opt/air_sdk/lib/legacy \
        /opt/air_sdk/runtimes/air/linux-arm64 \
        /opt/air_sdk/runtimes/air/linux \
        /opt/air_sdk/bin/adl* /opt/air_sdk/bin/apps \
        /opt/air_sdk/bin/aasdoc /opt/air_sdk/bin/asdoc \
        /opt/air_sdk/bin/fdb /opt/air_sdk/bin/fontswf \
        /opt/air_sdk/bin/optimizer /opt/air_sdk/bin/swcdepends \
        /opt/air_sdk/bin/swfdump /opt/air_sdk/bin/swfcompress \
        /opt/air_sdk/bin/swfencrypt /opt/air_sdk/bin/configure_linux.sh \
        /opt/air_sdk/*.pdf /opt/air_sdk/*.txt && \
    cp -a /opt/air_sdk/lib /opt/air_sdk_lib_noandroid && \
    rm -rf /opt/air_sdk_lib_noandroid/android \
           /opt/air_sdk_lib_noandroid/FlashRuntimeExtensions*

# ============================================================
# Stage 2: Extract android.jar (needs Java for sdkmanager)
# ============================================================
FROM eclipse-temurin:17-jre-jammy AS android-jar

ARG CMDLINE_TOOLS_URL=https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip
ARG ANDROID_PLATFORM=android-34
RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends unzip && \
    rm -rf /var/lib/apt/lists/* && \
    curl -fsSL -o /tmp/cmdline-tools.zip "${CMDLINE_TOOLS_URL}" && \
    mkdir -p /opt/android-sdk/cmdline-tools && \
    unzip -q /tmp/cmdline-tools.zip -d /opt/android-sdk/cmdline-tools && \
    mv /opt/android-sdk/cmdline-tools/cmdline-tools /opt/android-sdk/cmdline-tools/latest && \
    yes | /opt/android-sdk/cmdline-tools/latest/bin/sdkmanager --licenses > /dev/null 2>&1 || true && \
    /opt/android-sdk/cmdline-tools/latest/bin/sdkmanager "platforms;${ANDROID_PLATFORM}" && \
    rm -rf /opt/android-sdk/cmdline-tools /tmp/cmdline-tools.zip

# ============================================================
# Stage 3: Pre-compile Java tools + ANE jar (for JRE targets)
# ============================================================
FROM eclipse-temurin:17-jdk-jammy AS java-tools

COPY scripts/patch.java scripts/tools.java /tmp/src/
RUN javac -d /opt/java-tools /tmp/src/patch.java /tmp/src/tools.java

COPY --from=android-jar /opt/android-sdk/platforms/android-34/android.jar /tmp/ane-deps/android.jar
COPY --from=builder /opt/air_sdk/lib/android/FlashRuntimeExtensions.jar /tmp/ane-deps/FlashRuntimeExtensions.jar
COPY ane/android/src /tmp/ane-src/
RUN javac --release 8 \
        -cp "/tmp/ane-deps/android.jar:/tmp/ane-deps/FlashRuntimeExtensions.jar" \
        -d /tmp/ane-classes \
        /tmp/ane-src/com/aqw/foreground/*.java && \
    jar cf /opt/java-tools/foreground-ext.jar -C /tmp/ane-classes .

# ============================================================
# Stage 4: Android build environment (JRE — ANE pre-compiled)
# ============================================================
FROM eclipse-temurin:17-jre-jammy AS android

LABEL org.opencontainers.image.description="AQW Pocket Android build environment"
LABEL org.opencontainers.image.source="https://github.com/sachnun/aqw-pocket"

ARG CACHE_BUST=default

COPY --from=builder /usr/bin/unzip            /usr/bin/
COPY --from=builder /usr/local/bin/jq         /usr/local/bin/
COPY --from=builder /tmp/rabcdasm/abcexport   /usr/local/bin/
COPY --from=builder /tmp/rabcdasm/rabcdasm    /usr/local/bin/
COPY --from=builder /tmp/rabcdasm/rabcasm     /usr/local/bin/
COPY --from=builder /tmp/rabcdasm/abcreplace  /usr/local/bin/

COPY --from=builder /opt/air_sdk/bin                    /opt/air_sdk/bin
COPY --from=builder /opt/air_sdk/lib                    /opt/air_sdk/lib
COPY --from=builder /opt/air_sdk/frameworks             /opt/air_sdk/frameworks
COPY --from=builder /opt/air_sdk/runtimes/air/android   /opt/air_sdk/runtimes/air/android
COPY --from=builder /opt/air_sdk/air-sdk-description.xml /opt/air_sdk/air-sdk-description.xml
COPY --from=builder /opt/air_sdk/airsdk.xml             /opt/air_sdk/airsdk.xml

COPY --from=java-tools /opt/java-tools /opt/java-tools

ENV AIR_HOME=/opt/air_sdk
ENV PATH="${AIR_HOME}/bin:${PATH}"

WORKDIR /workspace

# ============================================================
# Stage 5: Linux build environment (JRE — tools pre-compiled)
# ============================================================
FROM eclipse-temurin:17-jre-jammy AS linux

LABEL org.opencontainers.image.description="AQW Pocket Linux build environment"
LABEL org.opencontainers.image.source="https://github.com/sachnun/aqw-pocket"

ARG CACHE_BUST=default

RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
        libgtk2.0-0 libgdk-pixbuf2.0-0 libpango-1.0-0 \
        libx11-6 libxcursor1 libxrender1 libxml2 \
        libnss3 libnspr4 libgl1 file && \
    rm -rf /var/lib/apt/lists/*

COPY --from=builder /usr/bin/unzip            /usr/bin/
COPY --from=builder /usr/local/bin/jq         /usr/local/bin/
COPY --from=builder /tmp/rabcdasm/abcexport   /usr/local/bin/
COPY --from=builder /tmp/rabcdasm/rabcdasm    /usr/local/bin/
COPY --from=builder /tmp/rabcdasm/rabcasm     /usr/local/bin/
COPY --from=builder /tmp/rabcdasm/abcreplace  /usr/local/bin/
COPY --from=builder /opt/appimagetool         /opt/appimagetool

COPY --from=builder /opt/air_sdk/bin                       /opt/air_sdk/bin
COPY --from=builder /opt/air_sdk_lib_noandroid             /opt/air_sdk/lib
COPY --from=builder /opt/air_sdk/frameworks                /opt/air_sdk/frameworks
COPY --from=builder /opt/air_sdk/runtimes/air/linux-x64    /opt/air_sdk/runtimes/air/linux-x64
COPY --from=builder /opt/air_sdk/air-sdk-description.xml   /opt/air_sdk/air-sdk-description.xml
COPY --from=builder /opt/air_sdk/airsdk.xml                /opt/air_sdk/airsdk.xml

COPY --from=java-tools /opt/java-tools /opt/java-tools

ENV AIR_HOME=/opt/air_sdk
ENV PATH="${AIR_HOME}/bin:${PATH}"
ENV APPIMAGETOOL=/opt/appimagetool/AppRun

WORKDIR /workspace

# ============================================================
# Stage 6: Windows build environment (JRE — tools pre-compiled)
# ============================================================
FROM eclipse-temurin:17-jre-jammy AS windows

LABEL org.opencontainers.image.description="AQW Pocket Windows build environment"
LABEL org.opencontainers.image.source="https://github.com/sachnun/aqw-pocket"

ARG CACHE_BUST=default

RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends p7zip-full && \
    rm -rf /var/lib/apt/lists/*

COPY --from=builder /usr/bin/unzip            /usr/bin/
COPY --from=builder /usr/local/bin/jq         /usr/local/bin/
COPY --from=builder /tmp/rabcdasm/abcexport   /usr/local/bin/
COPY --from=builder /tmp/rabcdasm/rabcdasm    /usr/local/bin/
COPY --from=builder /tmp/rabcdasm/rabcasm     /usr/local/bin/
COPY --from=builder /tmp/rabcdasm/abcreplace  /usr/local/bin/

COPY --from=builder /opt/air_sdk/bin                       /opt/air_sdk/bin
COPY --from=builder /opt/air_sdk_lib_noandroid             /opt/air_sdk/lib
COPY --from=builder /opt/air_sdk/frameworks                /opt/air_sdk/frameworks
COPY --from=builder /opt/air_sdk/air-sdk-description.xml   /opt/air_sdk/air-sdk-description.xml
COPY --from=builder /opt/air_sdk/airsdk.xml                /opt/air_sdk/airsdk.xml

COPY --from=builder /opt/air_win_sdk  /opt/air_win_sdk
COPY windows/7zSD.sfx                /opt/7z-sfx/7zSD.sfx

COPY --from=java-tools /opt/java-tools /opt/java-tools

ENV AIR_HOME=/opt/air_sdk
ENV AIR_WIN_RUNTIME=/opt/air_win_sdk/runtimes/air/win
ENV SFX_MODULE=/opt/7z-sfx/7zSD.sfx
ENV PATH="${AIR_HOME}/bin:${PATH}"

WORKDIR /workspace
