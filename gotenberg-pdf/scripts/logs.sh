#!/bin/bash
CONTAINER="${GOTENBERG_CONTAINER:-gotenberg}"
docker logs "$CONTAINER" "${@:---tail 50}"
