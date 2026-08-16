#!/bin/sh
set -eu

command -v xcodegen >/dev/null 2>&1 || {
  echo "请先安装 XcodeGen：brew install xcodegen" >&2
  exit 1
}
xcodegen generate --spec project.yml
