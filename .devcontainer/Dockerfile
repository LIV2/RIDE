FROM stefanreinauer/amiga-gcc:latest

ARG DEBIAN_FRONTEND=noninteractive

RUN apt -y update && \
    apt -y install sudo vim jq verilator

COPY ./verible.sh /verible.sh

RUN /verible.sh
