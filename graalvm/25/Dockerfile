FROM ubuntu:24.04

ARG TARGETPLATFORM
ARG JAVA_VERSION=25

LABEL author="darksaid98" maintainer="kontakt@riko.dev"

LABEL org.opencontainers.image.source="https://github.com/darksaid98/yolks"
LABEL org.opencontainers.image.licenses=MIT

ENV DEBIAN_FRONTEND=noninteractive
ENV JAVA_HOME=/opt/java/graalvm
ENV PATH=$JAVA_HOME/bin:$PATH

# Default to UTF-8 file.encoding
ENV LANG='en_US.UTF-8' LANGUAGE='en_US:en' LC_ALL='en_US.UTF-8'

# Java base environment
RUN set -eux; \
	apt update -y; \
	DEBIAN_FRONTEND=noninteractive apt install -y --no-install-recommends \
	# curl required for historical reasons, see https://github.com/adoptium/containers/issues/255
	curl \
	wget \
	# gnupg required to verify the signature
	gnupg \
	# java.lang.UnsatisfiedLinkError: libfontmanager.so: libfreetype.so.6: cannot open shared object file: No such file or directory
	# java.lang.NoClassDefFoundError: Could not initialize class sun.awt.X11FontManager
	# https://github.com/docker-library/openjdk/pull/235#issuecomment-424466077
	fontconfig \
	# utilities for keeping Ubuntu and OpenJDK CA certificates in sync
	# https://github.com/adoptium/containers/issues/293
	ca-certificates p11-kit \
	# jlink --strip-debug on 13+ needs objcopy: https://github.com/docker-library/openjdk/issues/351
	# Error: java.io.IOException: Cannot run program "objcopy": error=2, No such file or directory
	binutils \
	tzdata \
	# locales ensures proper character encoding and locale-specific behaviors using en_US.UTF-8
	locales \
	; \
	echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen; \
	locale-gen en_US.UTF-8; \
	rm -rf /var/lib/apt/lists/*

# GraalVM Install
RUN set -eux; \
	case ${TARGETPLATFORM} in \
	"linux/amd64")  ARCH=x64  ;; \
	"linux/arm64")  ARCH=aarch64  ;; \
	esac; \
	wget --progress=dot:giga -O /tmp/graalvm.tar.gz https://download.oracle.com/graalvm/${JAVA_VERSION}/latest/graalvm-jdk-${JAVA_VERSION}_linux-${ARCH}_bin.tar.gz; \
	mkdir -p "$JAVA_HOME"; \
	tar --extract \
	--file /tmp/graalvm.tar.gz \
	--directory "$JAVA_HOME" \
	--strip-components 1 \
	--no-same-owner \
	; \
	rm -rf /tmp/graalvm.tar.gz; \
	# https://github.com/docker-library/openjdk/issues/331#issuecomment-498834472
	find "$JAVA_HOME/lib" -name '*.so' -exec dirname '{}' ';' | sort -u > /etc/ld.so.conf.d/docker-openjdk.conf; \
	ldconfig; \
	# https://github.com/docker-library/openjdk/issues/212#issuecomment-420979840
	# https://openjdk.java.net/jeps/341
	java -Xshare:dump;

# Verify Java installation
RUN set -eux; \
	echo "Verifying install ..."; \
	fileEncoding="$(echo 'System.out.println(System.getProperty("file.encoding"))' | jshell -s -)"; [ "$fileEncoding" = 'UTF-8' ]; rm -rf ~/.java; \
	echo "javac --version"; javac --version; \
	echo "java --version"; java --version; \
	echo "Complete."

# Misc standard packages to ship with image
RUN set -eux; \
	apt update -y; \
	DEBIAN_FRONTEND=noninteractive apt install -y \
	curl \
	lsof \
	ca-certificates \
	openssl \
	git \
	git-lfs \
	tar \
	sqlite3 \
	fontconfig \
	tzdata \
	iproute2 \
	libfreetype6 \
	tini \
	zip \
	unzip \
	# WebP utilities for encoding/decoding WebP images
	webp

## Setup user and working directory
RUN         useradd -m -d /home/container -s /bin/bash container
USER        container
ENV         USER=container HOME=/home/container
WORKDIR     /home/container

STOPSIGNAL SIGINT

COPY        --chown=container:container ./../entrypoint.sh /entrypoint.sh
RUN         chmod +x /entrypoint.sh
ENTRYPOINT    ["/usr/bin/tini", "-g", "--"]
CMD         ["/entrypoint.sh"]
