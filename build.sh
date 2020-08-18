#!/bin/sh

name=fixdockergid-builder
docker build -t $name -f build.Dockerfile .
docker run -d --name $name $name sleep infinity
docker cp fixdockergid-builder:/workspace/_fixdockergid _fixdockergid
docker rm -f $name
