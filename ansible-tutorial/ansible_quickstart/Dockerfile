FROM ubuntu:latest
LABEL authors="dino"

RUN apt-get update -y && apt-get install -y openssh-server

RUN mkdir -p /run/sshd
RUN echo "root:root" | chpasswd
RUN sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config


EXPOSE 22

ENTRYPOINT ["/usr/sbin/sshd", "-D"]