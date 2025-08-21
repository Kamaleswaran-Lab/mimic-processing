#!/bin/bash
psql -h localhost -p 15432 -U labuser -d mimiciv "$@"
