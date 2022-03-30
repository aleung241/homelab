#!/bin/bash

BASE_DIRECTORY="/opt/docker-compose"

docker-compose $(find $BASE_DIRECTORY -maxdepth 1 -type f -name '*.yml' -printf "-f $BASE_DIRECTORY/%f ") pull
docker-compose $(find $BASE_DIRECTORY -maxdepth 1 -type f -name '*.yml' -printf "-f $BASE_DIRECTORY/%f ") up -d