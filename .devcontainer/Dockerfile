FROM mcr.microsoft.com/devcontainers/python:0-3.11

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install --no-install-recommends -y \
        jq \
        vim \
        wget \  
    && apt-get clean -y \
    && rm -rf /var/lib/apt/lists/* /var/cache/apt/*

RUN pip install --upgrade pip

# ansible
RUN python3 -m pip install ansible

# nodejs install (required by aws-cdk)
ENV NVM_DIR /usr/local/share/nvm
ENV NODE_VERSION 18
RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.3/install.sh | bash
RUN echo "source $NVM_DIR/nvm.sh && \
    nvm install $NODE_VERSION && \
    nvm alias default $NODE_VERSION && \
    nvm use default" | bash
ENV NODE_PATH $NVM_DIR/v$NODE_VERSION/lib/node_modules
ENV PATH $NVM_DIR/versions/node/v$NODE_VERSION/bin:$PATH

# aws-cdk
RUN npm install -g aws-cdk

# ovh
# deps below are only applicable for OVH dev/prod deployments

RUN python3 -m pip install python-openstackclient

## opentofu
RUN wget https://github.com/opentofu/opentofu/releases/download/v1.6.2/tofu_1.6.2_amd64.deb \
    && dpkg -i tofu_1.6.2_amd64.deb

## kubectl
RUN curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" \
    && install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

## helm
RUN curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 \
    && chmod 700 get_helm.sh \
    && ./get_helm.sh
