FROM golang

ENV JQ_VERSION=1.5

# download jq
RUN wget -qO /bin/jq https://github.com/stedolan/jq/releases/download/jq-${JQ_VERSION}/jq-linux64 && \
    chmod u+x /bin/jq

# download the latest oauth2_proxy release
RUN mkdir -p /go/src/app && \
    curl -sSL https://api.github.com/repos/bitly/oauth2_proxy/releases/latest | \
    jq -r .tarball_url | \
    xargs -n 1 curl -sSL | \
    tar -xzf - --strip 1 -C /go/src/app

# get all the dependencies
RUN go get -d -v github.com/bitly/oauth2_proxy && \
    go install -v github.com/bitly/oauth2_proxy

VOLUME /config

EXPOSE 4180

CMD ["oauth2_proxy", "-config", "/config/oauth2_proxy.cfg"]
