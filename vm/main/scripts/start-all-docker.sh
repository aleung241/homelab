#!/bin/bash

BASE_DIRECTORY="/opt/docker-compose"

docker-compose -f $BASE_DIRECTORY/media/docker-compose.yml pull
docker-compose -f $BASE_DIRECTORY/reverse-proxy/docker-compose.yml pull
docker-compose -f $BASE_DIRECTORY/special/docker-compose.yml pull
docker-compose -f $BASE_DIRECTORY/torrent/docker-compose.yml pull


docker-compose -f $BASE_DIRECTORY/media/docker-compose.yml up -d
docker-compose -f $BASE_DIRECTORY/reverse-proxy/docker-compose.yml up -d
docker-compose -f $BASE_DIRECTORY/special/docker-compose.yml up -d
docker-compose -f $BASE_DIRECTORY/torrent/docker-compose.yml up -d
