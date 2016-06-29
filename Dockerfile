#docker pull pivotalgreenhouse/packer-base
FROM bosh/init

ENV PACKER_URL "https://releases.hashicorp.com/packer/0.10.1/packer_0.10.1_linux_amd64.zip"
RUN apt-get update && apt-get -y install zip unzip wget
RUN wget ${PACKER_URL} -O packer.zip
RUN unzip packer.zip && mv packer /usr/local/bin/packer && rm packer.zip
