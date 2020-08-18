FROM buildpack-deps:focal

WORKDIR /workspace

RUN apt-get update \
  && apt-get install -y --no-install-recommends software-properties-common \
  && add-apt-repository -y ppa:neurobin/ppa \
  && apt-get update \
  && apt-get install -y shc

COPY _fixdockergid.sh .

RUN shc -S -r -f _fixdockergid.sh -o _fixdockergid
