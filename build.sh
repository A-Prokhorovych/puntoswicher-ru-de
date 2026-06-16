#!/usr/bin/env bash
set -euo pipefail

mkdir -p .build
clang \
  -fobjc-arc \
  Sources/PuntoSwitcherRUDE/main.m \
  -framework AppKit \
  -framework Carbon \
  -framework ApplicationServices \
  -o .build/puntoswicher-ru-de

echo ".build/puntoswicher-ru-de"
