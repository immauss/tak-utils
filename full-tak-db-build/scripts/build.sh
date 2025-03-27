#!/bin/bash
if [ -z "$1" ]; then
    echo "Usage: $0 <version> <push|load>"
    exit 1
fi
tag=$1
docker buildx build -t immauss/tak-tak:$tag -f Dockerfile.tak . --$2
docker buildx build -t immauss/tak-db:$tag -f Dockerfile.db . --$2