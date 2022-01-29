FROM debian:latest

RUN apt-get -y update && \
    apt-get -y upgrade

WORKDIR /app

# setup perl dependencies
RUN apt-get install -y carton make
COPY cpanfile ./
RUN carton install
COPY bin/enphase-metrics.pl ./bin/

EXPOSE 8080

CMD carton exec perl bin/enphase-metrics.pl