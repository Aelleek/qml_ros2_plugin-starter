#!/usr/bin/env bash
set -Eeuo pipefail

: "${IMAGE:=qmlros2:humble-qt}"
: "${NAME:=qmlros2_hmi}"
: "${HOST_PORT:=6901}"
: "${CONTAINER_PORT:=6080}"
: "${SRC_DIR:=$PWD}"
: "${SHM_SIZE:=2g}"

if command -v lsof >/dev/null 2>&1; then
  lsof -iTCP:"$HOST_PORT" -sTCP:LISTEN >/dev/null 2>&1 && echo "[WARN] Host port ${HOST_PORT} already in LISTEN state."
fi

docker ps -a --format '{{.Names}}' | grep -q "^${NAME}$" && docker rm -f "${NAME}" >/dev/null 2>&1 || true

docker run --name "${NAME}" --rm -it \
  -p "${HOST_PORT}:${CONTAINER_PORT}" \
  --shm-size="${SHM_SIZE}" \
  -v "${SRC_DIR}":/ws/src/qml_ros2_plugin:rw \
  "${IMAGE}" \
  bash -lc '
set -Eeuo pipefail

: "${DISPLAY:=:0}"
: "${GEOM:=1280x800x24}"
: "${CONTAINER_PORT:=6080}"
: "${QT_QPA_PLATFORM:=xcb}"
: "${QT_QUICK_BACKEND:=software}"
: "${LIBGL_ALWAYS_SOFTWARE:=1}"
: "${QT_XCB_GL_INTEGRATION:=none}"
: "${QSG_RENDER_LOOP:=basic}"
export DISPLAY QT_QPA_PLATFORM QT_QUICK_BACKEND LIBGL_ALWAYS_SOFTWARE QT_XCB_GL_INTEGRATION QSG_RENDER_LOOP

# 로그 초기화
: > /tmp/xvfb.log; : > /tmp/fluxbox.log; : > /tmp/x11vnc.log; : > /tmp/novnc.log

# ROS env
set +u; [ -f /opt/ros/humble/setup.bash ] && source /opt/ros/humble/setup.bash; set -u

# 1) Xvfb/fluxbox/x11vnc/noVNC
Xvfb "${DISPLAY}" -screen 0 "${GEOM}" >/tmp/xvfb.log 2>&1 & sleep 0.2
fluxbox >/tmp/fluxbox.log 2>&1 & sleep 0.2
x11vnc -display "${DISPLAY}" -forever -shared -nopw -rfbport 5900 -localhost >/tmp/x11vnc.log 2>&1 & sleep 0.2
if [ -x /usr/share/novnc/utils/novnc_proxy ]; then
  /usr/share/novnc/utils/novnc_proxy --vnc localhost:5900 --listen "${CONTAINER_PORT}" >/tmp/novnc.log 2>&1 &
else
  websockify --web=/usr/share/novnc "${CONTAINER_PORT}" localhost:5900 >/tmp/novnc.log 2>&1 &
fi

# 2) qml_ros2_plugin 자동 빌드(없을 때만)
PLUGIN_SO="/ws/install/qml_ros2_plugin/lib/Ros2/libqml_ros2_plugin.so"
if [ ! -f "$PLUGIN_SO" ]; then
  echo "[INFO] First run: building qml_ros2_plugin..."
  cd /ws && rm -rf build install log
  # QoS::BestAvailable → Humble 호환 치환(있을 때만)
  if grep -RIl --exclude-dir=install --exclude-dir=build --exclude-dir=.git "BestAvailable" /ws/src/qml_ros2_plugin >/dev/null 2>&1; then
    sed -i.bak -E \
      "s/rclcpp::QoS::BestAvailable\\s*\\(\\s*\\)/rclcpp::QoS(rclcpp::KeepLast(10)).reliability(rmw_qos_reliability_policy_t::RMW_QOS_POLICY_RELIABILITY_RELIABLE).durability(rmw_qos_durability_policy_t::RMW_QOS_POLICY_DURABILITY_VOLATILE)/g" \
      /ws/src/qml_ros2_plugin/**/*.cpp /ws/src/qml_ros2_plugin/*.cpp 2>/dev/null || true
  fi
  colcon build --packages-select qml_ros2_plugin --symlink-install --event-handlers console_direct+
  set +u; source /ws/install/setup.bash; set -u
  export QML2_IMPORT_PATH=/ws/install/qml_ros2_plugin/lib
  ln -snf /ws/install/qml_ros2_plugin/lib/Ros2 /ws/install/qml_ros2_plugin/lib/Ros || true
  [ -f "$PLUGIN_SO" ] && echo "[OK] Built: $PLUGIN_SO" || { echo "[ERR] Plugin .so missing"; exit 2; }
else
  set +u; source /ws/install/setup.bash; set -u
  export QML2_IMPORT_PATH=/ws/install/qml_ros2_plugin/lib
  ln -snf /ws/install/qml_ros2_plugin/lib/Ros2 /ws/install/qml_ros2_plugin/lib/Ros || true
fi

echo "[READY] http://localhost:${CONTAINER_PORT}/vnc.html?autoconnect=1&resize=scale"
tail -f /tmp/fluxbox.log /tmp/x11vnc.log /tmp/novnc.log
'

