# ============================================================
# Stage 1: Build RABCDAsm + download all tools
# (buildpack-deps:jammy has gcc, curl, unzip, git, liblzma-dev
#  -- zero apt-get needed)
# ============================================================
FROM buildpack-deps:jammy AS builder

# Static jq binary (no apt needed)
ARG JQ_VERSION=1.7.1
RUN curl -fsSL -o /usr/local/bin/jq \
        "https://github.com/jqlang/jq/releases/download/jq-${JQ_VERSION}/jq-linux-amd64" && \
    chmod +x /usr/local/bin/jq

# Download dmd binary directly
ARG DMD_VERSION=2.109.1
RUN curl -fsSL "https://downloads.dlang.org/releases/2.x/${DMD_VERSION}/dmd.${DMD_VERSION}.linux.tar.xz" \
        | tar xJ -C /opt

# Build RABCDAsm
RUN git clone --depth 1 https://github.com/CyberShadow/RABCDAsm.git /tmp/rabcdasm
WORKDIR /tmp/rabcdasm
RUN PATH="/opt/dmd2/linux/bin64:$PATH" \
    dmd -run build_rabcdasm.d abcexport rabcdasm rabcasm abcreplace

# Download all tools (no local SDK copy needed)
WORKDIR /
ARG BUNDLETOOL_VERSION=1.18.2
ARG CMDLINE_TOOLS_URL=https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip
ARG APPIMAGETOOL_URL=https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage

# AIR SDK version — single ARG controls both Linux and Windows downloads
ARG AIR_VERSION=51.0.1.3
ARG AIR_SDK_BASE_URL=https://airsdk.harman.com/api/versions/${AIR_VERSION}/sdks

SHELL ["/bin/bash", "-c"]
RUN echo "Downloading tools in parallel..." && \
    curl -fSL -o /tmp/air_sdk.zip       "${AIR_SDK_BASE_URL}/AIRSDK_Linux.zip?license=accepted" & \
    curl -fSL -o /tmp/air_win_sdk.zip   "${AIR_SDK_BASE_URL}/AIRSDK_Windows.zip?license=accepted" & \
    curl -fSL -o /tmp/cmdline-tools.zip "${CMDLINE_TOOLS_URL}" & \
    curl -fSL -o /tmp/bundletool.jar \
        "https://github.com/google/bundletool/releases/download/${BUNDLETOOL_VERSION}/bundletool-all-${BUNDLETOOL_VERSION}.jar" & \
    curl -fSL -o /tmp/appimagetool.AppImage "${APPIMAGETOOL_URL}" & \
    wait && \
    # Install AIR SDK (Linux — compiler toolchain + Linux runtime)
    mkdir -p /opt/air_sdk && \
    unzip -o -q /tmp/air_sdk.zip -d /opt/air_sdk && \
    chmod -R +x /opt/air_sdk/bin && \
    # Install AIR SDK Windows runtime (for cross-packaging Windows bundles)
    mkdir -p /opt/air_win_sdk && \
    unzip -o -q /tmp/air_win_sdk.zip 'runtimes/air/win/*' -d /opt/air_win_sdk && \
    # Install Android cmdline-tools
    mkdir -p /opt/android-sdk/cmdline-tools && \
    unzip -q /tmp/cmdline-tools.zip -d /opt/android-sdk/cmdline-tools && \
    mv /opt/android-sdk/cmdline-tools/cmdline-tools /opt/android-sdk/cmdline-tools/latest && \
    # Install bundletool
    mkdir -p /opt/bundletool && \
    mv /tmp/bundletool.jar /opt/bundletool/bundletool.jar && \
    # Extract appimagetool (--appimage-extract works without FUSE)
    chmod +x /tmp/appimagetool.AppImage && \
    cd /tmp && ./appimagetool.AppImage --appimage-extract && \
    mv /tmp/squashfs-root /opt/appimagetool && \
    # Cleanup
    rm -f /tmp/air_sdk.zip /tmp/air_win_sdk.zip /tmp/cmdline-tools.zip /tmp/appimagetool.AppImage

# ============================================================
# Stage 2: Final image (zero apt-get!)
# JDK 17 already included in eclipse-temurin base
# ============================================================
FROM eclipse-temurin:17-jdk-jammy

LABEL org.opencontainers.image.description="AQW Pocket build environment"
LABEL org.opencontainers.image.source="https://github.com/sachnun/aqw-pocket"

ARG ANDROID_PLATFORM=android-34
ARG ANDROID_BUILD_TOOLS=34.0.0

# -----------------------------------------------------------
# Copy all tools from builder (no apt-get needed)
# -----------------------------------------------------------
COPY --from=builder /usr/bin/unzip             /usr/bin/
COPY --from=builder /usr/local/bin/jq         /usr/local/bin/
COPY --from=builder /tmp/rabcdasm/abcexport   /usr/local/bin/
COPY --from=builder /tmp/rabcdasm/rabcdasm    /usr/local/bin/
COPY --from=builder /tmp/rabcdasm/rabcasm     /usr/local/bin/
COPY --from=builder /tmp/rabcdasm/abcreplace  /usr/local/bin/
COPY --from=builder /opt/air_sdk              /opt/air_sdk
COPY --from=builder /opt/air_win_sdk          /opt/air_win_sdk
COPY --from=builder /opt/android-sdk          /opt/android-sdk
COPY --from=builder /opt/bundletool           /opt/bundletool
COPY --from=builder /opt/appimagetool         /opt/appimagetool

# 7-Zip SFX stub for Windows portable exe (committed to repo)
COPY windows/7zSD.sfx                         /opt/7z-sfx/7zSD.sfx

# -----------------------------------------------------------
# Linux desktop runtime dependencies (for AIR runtime + ldd lib bundling)
# -----------------------------------------------------------
RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
        libgtk2.0-0 libgdk-pixbuf2.0-0 libpango-1.0-0 \
        libx11-6 libxcursor1 libxrender1 libxml2 \
        libnss3 libnspr4 libgl1 file p7zip-full && \
    rm -rf /var/lib/apt/lists/*

# -----------------------------------------------------------
# Android SDK platform and build-tools (needs Java from base)
# -----------------------------------------------------------
RUN yes | /opt/android-sdk/cmdline-tools/latest/bin/sdkmanager --licenses > /dev/null 2>&1 || true && \
    /opt/android-sdk/cmdline-tools/latest/bin/sdkmanager \
        "platform-tools" \
        "platforms;${ANDROID_PLATFORM}" \
        "build-tools;${ANDROID_BUILD_TOOLS}"

# -----------------------------------------------------------
# Environment
# -----------------------------------------------------------
ENV AIR_HOME=/opt/air_sdk
ENV AIR_WIN_RUNTIME=/opt/air_win_sdk/runtimes/air/win
ENV SFX_MODULE=/opt/7z-sfx/7zSD.sfx
ENV ANDROID_SDK_ROOT=/opt/android-sdk
ENV ANDROID_JAR=/opt/android-sdk/platforms/android-34/android.jar
ENV BUNDLETOOL_JAR=/opt/bundletool/bundletool.jar
ENV PATH="${AIR_HOME}/bin:${PATH}"
ENV APPIMAGETOOL=/opt/appimagetool/AppRun

WORKDIR /workspace
