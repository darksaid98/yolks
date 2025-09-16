FROM --platform=$TARGETOS/$TARGETARCH golang:1.23.3 AS builder

ENV         DEBIAN_FRONTEND=noninteractive


WORKDIR /appbuild/yagpdb

RUN apt update -y \
	&& apt upgrade -y \
	&& apt install -y apt-transport-https wget curl git tar

RUN git clone https://github.com/botlabs-gg/yagpdb.git .

RUN go mod download

COPY . .

WORKDIR /appbuild/yagpdb/cmd/yagpdb
RUN CGO_ENABLED=0 GOOS=linux go build -v -ldflags "-X github.com/botlabs-gg/yagpdb/v2/common.VERSION=$(git describe --tags)"



FROM --platform=$TARGETOS/$TARGETARCH debian:bookworm-slim

ENV         DEBIAN_FRONTEND=noninteractive

RUN           mkdir -p /usr/bin/
RUN           mkdir -p /usr/local/bin/


# Dependencies: ca-certificates for client TLS, tzdata for timezone and ffmpeg for soundboard support
RUN apt update -y \
	&& apt upgrade -y \
	&& apt install -y \
		git \
		ca-certificates \
		dnsutils \
		iproute2 \
		wget \
		curl \
		xz-utils \
		ffmpeg \
		tzdata \
		tini

COPY --from=builder /appbuild/yagpdb/cmd/yagpdb/yagpdb /usr/local/bin/yagpdb
RUN         chmod +x /usr/local/bin/yagpdb

## Setup user and working directory
RUN         useradd -m -d /home/container -s /bin/bash container
USER        container
ENV         USER=container HOME=/home/container
WORKDIR     /home/container

STOPSIGNAL SIGINT

COPY        --chown=container:container ./entrypoint.sh /entrypoint.sh
RUN         chmod +x /entrypoint.sh
ENTRYPOINT    ["/usr/bin/tini", "-g", "--"]
CMD         ["/entrypoint.sh"]
