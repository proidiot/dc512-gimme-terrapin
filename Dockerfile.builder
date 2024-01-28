FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

ADD downloads/*.dsc /opt/

RUN apt-get update \
	&& apt-get install -y \
		build-essential \
		debian-goodies \
		devscripts \
		dpkg-dev \
	&& apt-get build-dep -y \
		/opt/*.dsc \
	&& apt-get clean
