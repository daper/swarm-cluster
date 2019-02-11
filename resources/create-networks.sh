#!/bin/sh

docker network create -d overlay \
  --subnet=192.168.0.0/28 \
  --opt com.docker.network.driver.mtu=9216 \
  --opt encrypted=true \
  dbnet

sleep 2

docker network create -d overlay \
  --subnet=192.168.0.16/28 \
  --opt com.docker.network.driver.mtu=9216 \
  --opt encrypted=true \
  appnet

 sleep 2

 docker network create -d overlay \
  --subnet=192.168.0.32/28 \
  --opt com.docker.network.driver.mtu=9216 \
  --opt encrypted=true \
  frontnet