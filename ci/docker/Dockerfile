# ghcr.io/cloudfoundry/bosh/windows-stemcell-ci
ARG BASE_IMAGE=ubuntu:jammy
FROM ${BASE_IMAGE}

ARG BOSH_CLI_URL
ARG META4_CLI_URL
ARG GOLANGCI_LINT_INSTALL_URL
ARG GOVC_INSTALL_URL
ARG YQ_CLI_URL

ARG RUBY_INSTALL_URL
ARG GEM_HOME
ARG RUBY_VERSION

ENV DEBIAN_FRONTEND="noninteractive"
ENV LANGUAGE="en_US.UTF-8"
ENV LC_CTYPE="${LANGUAGE}"
ENV LC_ALL="${LANGUAGE}"
ENV LANG="${LANGUAGE}"
ENV TZ="Etc/UTC"

RUN echo "Using 'jammy' because Azure doesn't yet support 'noble'" \
    && apt-get update -y \
    && apt-get install -y --no-install-recommends \
        apt-transport-https \
        apt-utils \
        ca-certificates \
        curl \
        gnupg \
        locales \
        lsb-release \
        software-properties-common \
    && locale-gen "${LANGUAGE}" \
    && dpkg-reconfigure locales \
    && LSB_RELEASE="$(lsb_release -cs)" \
    && LSB_ID="$(lsb_release -rs)" \
    && echo "Add packages.cloud.google.com for: google-cloud-cli" \
    && curl -sL https://packages.cloud.google.com/apt/doc/apt-key.gpg \
      | gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" \
      | tee /etc/apt/sources.list.d/google-cloud-sdk.list \
    && echo "Add apt.releases.hashicorp.com for: packer" \
    && curl -fsSL https://apt.releases.hashicorp.com/gpg \
      | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg \
    && echo "deb [arch=amd64 signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com ${LSB_RELEASE} main" \
      | tee /etc/apt/sources.list.d/hashicorp.list \
    && echo "Add packages.microsoft.com key" \
    && curl -fsSL https://packages.microsoft.com/keys/microsoft.asc \
      | gpg --dearmor -o /usr/share/keyrings/microsoft.gpg \
    && echo "Add apt-list packages.microsoft.com for: azure-cli" \
    && echo "deb [arch=amd64 signed-by=/usr/share/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/azure-cli/ ${LSB_RELEASE} main" \
      | tee /etc/apt/sources.list.d/azure-cli-microsoft.list \
    && echo "Add apt-list packages.microsoft.com for: powershell" \
    && echo "deb [arch=amd64 signed-by=/usr/share/keyrings/microsoft.gpg] https://packages.microsoft.com/ubuntu/${LSB_ID}/prod ${LSB_RELEASE} main" \
      | tee /etc/apt/sources.list.d/powershell-microsoft.list \
    && echo "Add packages.cloudfoundry.org for: cf-cli" \
    && curl -sL https://packages.cloudfoundry.org/debian/cli.cloudfoundry.org.key  \
      | gpg --dearmor -o /usr/share/keyrings/cli.cloudfoundry.org.gpg \
    && echo "deb [arch=amd64 signed-by=/usr/share/keyrings/cli.cloudfoundry.org.gpg] https://packages.cloudfoundry.org/debian stable main" \
      | tee /etc/apt/sources.list.d/cli-cloudfoundry-org.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        awscli \
        azcopy \
        azure-cli \
        build-essential \
        cf-cli \
        freerdp2-x11 \
        git \
        google-cloud-cli \
        jq \
        libc6-dev \
        libncursesw5 \
        libpopt-dev \
        mingw-w64 \
        netcat-openbsd \
        packer \
        pigz \
        pkg-config \
        powershell \
        python3 \
        python3-all \
        python3-dev \
        python3-pip \
        python3-setuptools \
        rlwrap \
        rsync \
        ssh \
        unzip \
        vim \
        wget \
        zip


RUN packer plugins install github.com/hashicorp/amazon \
    && packer plugins install github.com/hashicorp/azure \
    && packer plugins install github.com/hashicorp/googlecompute \
    && packer plugins install github.com/hashicorp/vsphere


# Install https://github.com/CiscoCXSecurity/rdp-sec-check
#   Previously https://github.com/portcullislabs/rdp-sec-check
# Referenced by:
# - cloudfoundry/windows-utilities-release
# - cloudfoundry/windows-utilities-tests
RUN rdp_sec_check_path="/usr/local/bin/rdp-sec-check.pl" \
    && curl https://raw.githubusercontent.com/CiscoCXSecurity/rdp-sec-check/refs/heads/master/rdp-sec-check.pl \
      >  "${rdp_sec_check_path}" \
    && chmod +x "${rdp_sec_check_path}" \
    && export PERL_MM_USE_DEFAULT=1 \
    && cpan Encoding::BER


# Add Golang
COPY --from=golang:latest /usr/local/go /usr/local/go
ENV GOROOT=/usr/local/go
ENV PATH=/usr/local/go/bin:${PATH}


ENV PATH ${GEM_HOME}/bin:${GEM_HOME}/gems/bin:${PATH}
ENV BUNDLE_APP_CONFIG ${GEM_HOME}
RUN cd /tmp  \
    && curl --show-error -sL "${RUBY_INSTALL_URL}" \
      | tar -xzf - \
    && cd ruby-install-* \
    && make -s install \
    && cd - \
    && rm -rf ruby-install-* \
    && echo 'gem: --no-document' > /etc/gemrc \
    && echo 'gem: --no-document' > ~/.gemrc \
    && NUM_CPUS=$(grep -c ^processor /proc/cpuinfo) \
    && ruby-install --jobs=${NUM_CPUS} --cleanup --system ruby ${RUBY_VERSION} \
      -- --disable-install-doc --disable-install-rdoc \
    && gem update --system \
    && bundle config --global path "${GEM_HOME}" \
    && bundle config --global bin "${GEM_HOME}/bin"


RUN bosh_cli_path="/usr/bin/bosh" \
    && curl --show-error -sL "${BOSH_CLI_URL}" \
      > "${bosh_cli_path}" \
    && chmod +x "${bosh_cli_path}"

RUN meta4_cli_path="/usr/local/bin/meta4" \
    && curl --show-error -sL "${META4_CLI_URL}" \
      > "${meta4_cli_path}" \
    && chmod +x "${meta4_cli_path}"

RUN cd /tmp \
    && golangci_lint_path="/usr/local/bin/golangci-lint" \
    && curl --show-error -sL "${GOLANGCI_LINT_INSTALL_URL}" \
      | tar -xzf - \
    && mv golangci-lint-*-linux-amd64/golangci-lint "${golangci_lint_path}" \
    && rm -rf golangci-lint-*-linux-amd64 \
    && chmod +x "${golangci_lint_path}"

RUN govc_path="/usr/local/bin/govc" \
    && curl --show-error -sL "${GOVC_INSTALL_URL}" \
      | tar -xOzf - govc > "${govc_path}" \
    && chmod +x "${govc_path}"

RUN yq_cli_path="/usr/local/bin/yq" \
    && curl --show-error -sL "${YQ_CLI_URL}" \
      > "${yq_cli_path}" \
    && chmod +x "${yq_cli_path}"


# built by ci/tasks/build-azstemcell/run.sh
COPY azstemcell /usr/bin/azstemcell
