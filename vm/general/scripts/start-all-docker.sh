#!/bin/bash

docker-compose -f /opt/docker-compose/docker-compose.yml pull
docker-compose -f /opt/docker-compose/docker-compose.yml up -d