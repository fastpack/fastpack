FROM alpine:3.8

RUN apk --no-cache add ca-certificates wget

ENV GLIBC_VERSION 2.28-r0

RUN wget -q -O /etc/apk/keys/sgerrand.rsa.pub https://alpine-pkgs.sgerrand.com/sgerrand.rsa.pub
RUN wget "https://github.com/sgerrand/alpine-pkg-glibc/releases/download/$GLIBC_VERSION/glibc-$GLIBC_VERSION.apk"
RUN apk --no-cache add "glibc-$GLIBC_VERSION.apk"
RUN rm "glibc-$GLIBC_VERSION.apk"
RUN wget "https://github.com/sgerrand/alpine-pkg-glibc/releases/download/$GLIBC_VERSION/glibc-bin-$GLIBC_VERSION.apk"
RUN apk --no-cache add "glibc-bin-$GLIBC_VERSION.apk"
RUN rm "glibc-bin-$GLIBC_VERSION.apk"
RUN wget "https://github.com/sgerrand/alpine-pkg-glibc/releases/download/$GLIBC_VERSION/glibc-i18n-$GLIBC_VERSION.apk"
RUN apk --no-cache add "glibc-i18n-$GLIBC_VERSION.apk"
RUN rm "glibc-i18n-$GLIBC_VERSION.apk"

RUN apk add bash
RUN apk add nodejs
RUN apk add nodejs-npm
RUN apk add perl
RUN apk add m4
RUN apk add automake
RUN apk add autoconf
RUN apk add make
RUN apk add curl
RUN apk add gcc
RUN apk add g++
RUN apk add patch
RUN apk add libressl
RUN apk add libressl-dev
RUN apk add git
RUN apk add cmake

# esy uses this
COPY shasum /usr/bin
RUN chmod +x /usr/bin/shasum

RUN npm install --global --unsafe-perm=true esy@0.5.7
RUN npm install --global --unsafe-perm=true yarn
