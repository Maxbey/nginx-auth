FROM golang:1.6-alpine

RUN apk update && \
    apk add jq curl tar git && \
    rm -rf /var/cache/apk/*

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

CMD ["/go/bin/oauth2_proxy", "-config", "/config/oauth2_proxy.cfg"]
