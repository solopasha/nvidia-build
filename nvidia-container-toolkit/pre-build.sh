#!/bin/bash

source0="$(spectool --lf -s0 "${pkgname}.spec")"
source1="$(spectool --lf -s1 "${pkgname}.spec")"

go_vendor_archive create --config ./go-vendor-tools.toml ./"${source0##*/}" -O "${OUTPUT_DIR}/${source1#*: }"
