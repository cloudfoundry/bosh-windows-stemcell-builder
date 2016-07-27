#docker pull pivotalgreenhouse/packer-base
FROM ruby:2.1

RUN apt-get update && apt-get -y install zip unzip wget git-core
# gcc for cgo
RUN apt-get update && apt-get install -y --no-install-recommends \
		g++ \
		gcc \
		libc6-dev \
		make \
	&& rm -rf /var/lib/apt/lists/*

ENV GOLANG_VERSION 1.6.3
ENV GOLANG_DOWNLOAD_URL https://golang.org/dl/go$GOLANG_VERSION.linux-amd64.tar.gz
ENV GOLANG_DOWNLOAD_SHA256 cdde5e08530c0579255d6153b08fdb3b8e47caabbe717bc7bcd7561275a87aeb

RUN curl -fsSL "$GOLANG_DOWNLOAD_URL" -o golang.tar.gz \
	&& echo "$GOLANG_DOWNLOAD_SHA256  golang.tar.gz" | sha256sum -c - \
	&& tar -C /usr/local -xzf golang.tar.gz \
	&& rm golang.tar.gz

ENV GOPATH /go
ENV PATH $GOPATH/bin:/usr/local/go/bin:$PATH

RUN mkdir -p "$GOPATH/src" "$GOPATH/bin" && chmod -R 777 "$GOPATH"

WORKDIR $GOPATH


ENV PATH $GOROOT/bin:$GOPATH/bin:$PATH
ENV INSTALL_DIR "$GOPATH/src/github.com/mitchellh"
RUN mkdir -p $INSTALL_DIR
RUN git clone https://github.com/charlievieth/packer.git "$INSTALL_DIR/packer"
RUN cd $INSTALL_DIR/packer && git checkout esxi-builder && make deps && make generate && make dev

#ENV PACKER_URL "https://releases.hashicorp.com/packer/0.10.1/packer_0.10.1_linux_amd64.zip"
#RUN wget ${PACKER_URL} -O packer.zip
#RUN unzip packer.zip && mv packer /usr/local/bin/packer && rm packer.zip
