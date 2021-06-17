FROM debian:buster-slim
COPY entrypoint.bash /entrypoint.bash
RUN apt-get -y update && \
    apt-get -y install curl locales-all openssh-client openssh-server vim wget xz-utils && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
ENV VER 2.4.0
ENV HASHSUM 6e503a1a3b0f9117bce6ff7cc30cf61bdc79e9b32d074cf96deb0264e067a60d
ENV HURL https://github.com/tmate-io/tmate/releases/download/$VER/tmate-$VER-static-linux-amd64.tar.xz
ENV HFILE /tmp/tmate.tar.xz
ENV HASHcmd sha256sum
RUN printf "HFILE=$HFILE HASHcmd=$HASHcmd HASHSUM=$HASHSUM HURL=$HURL"
RUN ( curl -o $HFILE -LR -C- -f -S --connect-timeout 15 --max-time 600 --retry 3 --dump-header - --compressed --verbose $HURL ; (printf %b CHECKSUM\\072\\040expect\\040this\\040$HASHcmd\\072\\040$HASHSUM\\040\\052$HFILE\\012 ; printf %b $HASHSUM\\040\\052$HFILE\\012 | $HASHcmd -c - ;) || (printf %b ERROR\\072\\040CHECKSUMFAILD\\072\\040the\\040file\\040has\\040this\\040$HASHcmd\\072\\040 ; $HASHcmd -b $HFILE ; exit 1) )
RUN tar --strip-components=1 -axvf $HFILE && rm $HFILE && mv tmate /usr/bin && tmate -V
ENTRYPOINT ["/entrypoint.bash"]
