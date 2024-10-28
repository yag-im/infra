FROM debian:bookworm

ENV DEBIAN_FRONTEND noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        iproute2 \
        iputils-ping \
        net-tools \
        openssh-server \
        sudo

ARG USERNAME=infra
ARG USER_UID=1000
ARG USER_GID=$USER_UID

RUN groupadd --gid $USER_GID $USERNAME \
    && useradd --uid $USER_UID --gid $USER_GID -m $USERNAME -s /bin/bash \
    && usermod -aG sudo $USERNAME \
    && echo "${USERNAME} ALL=(ALL) NOPASSWD: ALL" | tee -a /etc/sudoers

COPY files/sshd_config /etc/ssh/sshd_config
COPY start.sh .

RUN service ssh restart

EXPOSE 2207

CMD exec /bin/bash -c "trap : TERM INT; ./start.sh & wait"
