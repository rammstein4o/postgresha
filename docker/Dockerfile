FROM postgres:13-alpine

ENV BUILD_DEPS "cmake make musl-dev gcc gettext-dev libintl gettext"
ENV RUNTIME_DEPS "libintl"

RUN apk --no-cache add --update ${RUNTIME_DEPS} && \
    apk add --virtual build_deps ${BUILD_DEPS} && \
    wget https://gitlab.com/rilian-la-te/musl-locales/-/archive/master/musl-locales-master.zip && \
    unzip musl-locales-master.zip && \
    cd musl-locales-master && \
    cmake -DLOCALE_PROFILE=OFF -D CMAKE_INSTALL_PREFIX:PATH=/usr . && make && make install && \
    cd .. && rm -r musl-locales-master && \
    cp /usr/bin/envsubst /usr/local/bin/envsubst && \
    apk del build_deps


COPY --chown=postgres:postgres conf /tmp/conf
COPY *.sh /usr/bin/
