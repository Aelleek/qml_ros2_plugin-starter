#!/usr/bin/env bash
set -e

# X11 허용(로컬 Xorg 기준; 테스트 후 xhost -local:root로 되돌리세요)
xhost +local:root 1>/dev/null 2>&1 || true

HOST_SRC="${HOST_SRC:-$HOME/Documents/Aelleek/qml_ros2_plugin}"

docker run --rm -it \
  --net=host \
  -e DISPLAY=$DISPLAY \
  -v /tmp/.X11-unix:/tmp/.X11-unix:rw \
  -v "$HOST_SRC":/ws/src/qml_ros2_plugin:rw \
  --workdir /ws \
  qmlros2:humble \
  bash -lc "source /opt/ros/humble/setup.bash && \
            colcon build --symlink-install && \
            source install/setup.bash && \
            bash"
