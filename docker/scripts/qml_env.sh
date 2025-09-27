#!/usr/bin/env bash
# ROS & headless Qt env (set -u 안전)
set +u
[ -f /opt/ros/humble/setup.bash ] && source /opt/ros/humble/setup.bash
[ -f /ws/install/setup.bash ] && source /ws/install/setup.bash
set -u

: "${AMENT_TRACE_SETUP_FILES:=0}"
: "${AMENT_PYTHON_EXECUTABLE:=/usr/bin/python3}"
: "${COLCON_TRACE:=0}"

: "${DISPLAY:=:0}"
: "${QT_QPA_PLATFORM:=xcb}"
: "${QT_QUICK_BACKEND:=software}"
: "${LIBGL_ALWAYS_SOFTWARE:=1}"
: "${QT_XCB_GL_INTEGRATION:=none}"
: "${QSG_RENDER_LOOP:=basic}"

export AMENT_TRACE_SETUP_FILES AMENT_PYTHON_EXECUTABLE COLCON_TRACE
export DISPLAY QT_QPA_PLATFORM QT_QUICK_BACKEND LIBGL_ALWAYS_SOFTWARE QT_XCB_GL_INTEGRATION QSG_RENDER_LOOP

# QML import path & Ros 링크
if [ -d /ws/install/qml_ros2_plugin/lib ]; then
  export QML2_IMPORT_PATH=/ws/install/qml_ros2_plugin/lib
fi
if [ -n "${QML2_IMPORT_PATH:-}" ] && [ -d "${QML2_IMPORT_PATH}/Ros2" ] && [ ! -e "${QML2_IMPORT_PATH}/Ros" ]; then
  ln -s "${QML2_IMPORT_PATH}/Ros2" "${QML2_IMPORT_PATH}/Ros" 2>/dev/null || true
fi

: "${QT_DEBUG_PLUGINS:=0}"
: "${QML_IMPORT_TRACE:=0}"
: "${QSG_INFO:=0}"
export QT_DEBUG_PLUGINS QML_IMPORT_TRACE QSG_INFO

