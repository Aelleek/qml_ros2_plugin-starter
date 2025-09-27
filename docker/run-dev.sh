#!/usr/bin/env bash
set -euo pipefail

# === Host paths ===
HOST_SRC="${HOST_SRC:-$HOME/Documents/Aelleek/qml_ros2_plugin}"

# === X11 / Auth (host side values) ===
DISPLAY_VAL="${DISPLAY:-:0}"
XAUTH_HOST="${XAUTHORITY:-$HOME/.Xauthority}"

if [ ! -f "$XAUTH_HOST" ]; then
  echo "[ERR] Xauthority not found: $XAUTH_HOST"
  echo "      GUI 로그인 세션의 터미널에서 실행하고 있는지 확인하세요."
  echo "      (원격 SSH면 X 포워딩/VNC 등 별도 설정 필요)"
  exit 1
fi

docker run --rm -it \
  --net=host \
  -e DISPLAY="${DISPLAY_VAL}" \
  -e XAUTHORITY=/tmp/.Xauthority \
  -e QT_QPA_PLATFORM=xcb \
  -e QT_SELECT=qt5 \
  -v "$XAUTH_HOST":/tmp/.Xauthority:ro \
  -v /tmp/.X11-unix:/tmp/.X11-unix:rw \
  -v "$HOST_SRC":/ws/src/qml_ros2_plugin:rw \
  --workdir /ws \
  qmlros2:humble \
  bash -lc 'set -e
    # ROS env
    source /opt/ros/humble/setup.bash

    # 빌드(루트 권한으로 /ws 에 산출물 생성)
    colcon build --symlink-install

    # 오버레이 활성화
    source install/setup.bash

    # 인터랙티브 셸 유지
    bash'

