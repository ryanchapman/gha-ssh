FROM debian:buster-slim
COPY entrypoint.bash /entrypoint.bash
RUN apt-get -y update && \
    apt-get -y install curl locales-all openssh-client openssh-server vim wget xz-utils && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* && \
    wget https://github.com/tmate-io/tmate/releases/download/2.4.0/tmate-2.4.0-static-linux-amd64.tar.xz && \
    tar xvf tmate-2.4.0-static-linux-amd64.tar.xz && \
    mv tmate-2.4.0-static-linux-amd64/tmate /usr/bin && \
    tmate -V
ENTRYPOINT ["/entrypoint.bash"]
