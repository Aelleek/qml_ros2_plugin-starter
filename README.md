# qml_ros2_plugin-starter

ROS 2 × QML 헤드리스 HMI 스타터 (Humble/Jammy)

[![ROS 2](https://img.shields.io/badge/ROS2-Humble-blue)](#)
[![Ubuntu](https://img.shields.io/badge/Ubuntu-22.04-orange)](#)
[![Headless](https://img.shields.io/badge/Headless-Xvfb%2BnoVNC-success)](#)
[![Dockerized](https://img.shields.io/badge/Docker-ready-informational)](#)
[![License: MIT](https://img.shields.io/badge/License-MIT-lightgrey.svg)](#license)

> 이 포크는 **헤드리스 환경에서도 “항상 뜨는” QML 데모**와, **영상/카메라 오버레이 HMI 예제**를 빠르게 구동하도록 강화한 스타터 템플릿입니다.
> 아래에는 우리의 개선사항과 실행법을 정리했고, 맨 마지막에는 **Upstream(원본) README**를 그대로 보존했습니다.

---

## 이 포크에서 달라진 점 (What’s New)

* **헤드리스 데스크톱 자동 기동**: `Xvfb + fluxbox + x11vnc + noVNC` 조합을 컨테이너에서 원클릭 실행
* **영상 오버레이 예제 추가**: `examples/video_overlay.qml`

  * HUD(시간/FPS/재생율), ROI 박스, Seek 슬라이더, **A–B Loop**, **Snapshot/ROI Snapshot**, 단축키(공백/←/→)
* **합성 카메라 오버레이 예제 추가**: `examples/camera_overlay.qml` (물리 카메라 없이 UI/오버레이 개발 가능)
* **런처 스크립트 추가**

  * `docker/scripts/run-headless.sh`: Xvfb→fluxbox→x11vnc→noVNC 순차 기동 (+로그)
  * `docker/scripts/run-overlay-video`: 소프트웨어 백엔드(경량)
  * `docker/scripts/run-overlay-video-gl`: **GLX+LLVMpipe(권장)** → 헤드리스에서도 영상 출력 안정
* **Humble 호환 QoS 패치**: `BestAvailable()` 미심볼 문제를 **`KeepLast(10)+Reliable+Volatile`**로 자동 치환
* **QML 모듈 경로/링크 고정**

  * `QML2_IMPORT_PATH=/ws/install/qml_ros2_plugin/lib`
  * `.../lib/Ros2 → .../lib/Ros` 심볼릭 링크 생성
* **nounset(set -u) 안전 런처**: ROS/colcon setup 스크립트와 충돌 없이 환경 로드

---

## 스크린샷 / GIF (예시)

> 레포에 `docs/` 폴더를 만들고 파일을 넣은 뒤 아래 경로를 수정하세요.

* noVNC 데스크톱 접속 화면: `docs/novnc-desktop.png`
* 비디오 오버레이 HUD & ROI: `docs/video-overlay.gif`

---

## 빠른 시작 (Quick Start)

### 1) noVNC 데스크톱 띄우기

```bash
# 컨테이너 내부에서 Xvfb→fluxbox→x11vnc→noVNC 순서로 기동
HOST_PORT=6901 bash docker/run-headless.sh
```

* 브라우저: `http://localhost:6080/vnc.html?autoconnect=1&resize=scale`
* 원격 서버라면(예: 맥 → 서버):

  ```bash
  # 맥에서 SSH 터널
  ssh -N -L 6080:localhost:6901 <user>@<server-host>
  # 브라우저는 http://localhost:6080 접속
  ```

### 2) 샘플 비디오 준비(선택)

```bash
docker exec -it qmlros2_hmi bash -lc '
  apt-get update && apt-get install -y --no-install-recommends ffmpeg && \
  mkdir -p /ws/assets && \
  ffmpeg -y -f lavfi -i testsrc=size=1280x720:rate=30 -t 15 \
         -c:v libx264 -pix_fmt yuv420p -movflags +faststart /ws/assets/sample.mp4'
```

### 3) 비디오 오버레이 실행(권장)

```bash
docker exec -it qmlros2_hmi bash -lc '/ws/src/qml_ros2_plugin/docker/scripts/run-overlay-video-gl'
```

### 4) (옵션) 소프트웨어 백엔드로 실행

```bash
docker exec -it qmlros2_hmi bash -lc '/ws/src/qml_ros2_plugin/docker/scripts/run-overlay-video'
```

---

## 추가된 예제 (Examples Added)

### `examples/video_overlay.qml`

* **HUD**: FPS, Timecode, Playback Rate
* **오버레이**: 십자선·ROI 박스
* **컨트롤**: Seek 슬라이더, **A–B Loop**, Snapshot/ROI Snapshot
* **단축키**: Space(재생/일시정지), `←/→` (±1s 시킹)

### `examples/camera_overlay.qml`

* 물리 카메라 없이 합성 피드로 **오버레이 UI 개발/테스트**
* 중심 십자선, 드래그 ROI, FPS 라벨, 스냅샷 저장(`/tmp/snap_*.png`)

---

## 스크립트 / 런처 (Scripts)

```
docker/scripts/
  run-headless.sh        # Xvfb→fluxbox→x11vnc→noVNC 순차 기동, 로그는 /tmp/*.log
  run-overlay-video      # Qt 소프트웨어 백엔드
  run-overlay-video-gl   # GLX+LLVMpipe(권장): 헤드리스에서 영상 출력 안정
```

> (선택) `qml_runner`를 함께 제공했다면, QQuickView/QQmlApplicationEngine 기반으로 show() 강제 및 -geometry 적용.

---

## 환경 변수 & 포트 (Headless/Qt/GStreamer)

* **권장/안전 ENV**

  * `DISPLAY=:0`
  * `QT_QPA_PLATFORM=xcb`
  * `QT_QUICK_BACKEND=software` *(GL 런처에서는 unset하거나 GLX 사용)*
  * `LIBGL_ALWAYS_SOFTWARE=1`
  * `QSG_RENDER_LOOP=basic`
  * `QML2_IMPORT_PATH=/ws/install/qml_ros2_plugin/lib`
* **오디오/로그 억제(옵션)**

  * `QT_LOGGING_RULES="qt.multimedia.*=false"`
  * `ALSA_CONFIG_PATH=/dev/null`
  * `GST_AUDIOSINK=fakesink`
* **포트 규칙**

  * 컨테이너 noVNC: `6080` ← 호스트: `6901` (기본)
    → 로컬 브라우저: `http://localhost:6080`

---

## ROS Humble 호환성 메모 (QoS/런타임)

* Humble에는 `rclcpp::QoS::BestAvailable()` 심볼이 없어 **런타임 로드 실패**를 유발할 수 있습니다.
* 대체:

  ```cpp
  rclcpp::QoS(rclcpp::KeepLast(10))
    .reliability(RMW_QOS_POLICY_RELIABILITY_RELIABLE)
    .durability(RMW_QOS_POLICY_DURABILITY_VOLATILE);
  ```

---

## QML 모듈 경로 & 심볼릭 링크

* `QML2_IMPORT_PATH=/ws/install/qml_ros2_plugin/lib`
* 일부 예제는 `import Ros 1.0`/`import Ros2 1.0`을 혼용하므로, 다음 링크를 보장:

  ```
  /ws/install/qml_ros2_plugin/lib/Ros2 -> /ws/install/qml_ros2_plugin/lib/Ros
  ```

---

## 문제 해결 (Troubleshooting)

| 증상                                               | 원인                                   | 해결                                                                          |        |             |
| ------------------------------------------------ | ------------------------------------ | --------------------------------------------------------------------------- | ------ | ----------- |
| 브라우저가 검은 화면/무반응                                  | Xvfb/fluxbox/x11vnc/noVNC 순서·포트 꼬임   | `run-headless.sh` 재실행, `/tmp/novnc.log` 확인, `pgrep -af Xvfb                 | x11vnc | websockify` |
| 창이 안 뜸(조용히 종료)                                   | 런처/GL 백엔드/Window 루트 미표시              | GL 런처 사용(`...-gl`), `QT_QUICK_BACKEND=software` 확인, show() 강제된 런처 사용        |        |             |
| `module "Ros" is not installed`                  | QML2_IMPORT_PATH 미설정, Ros2→Ros 링크 부재 | `QML2_IMPORT_PATH` 설정, 심볼릭 링크 생성                                            |        |             |
| `unbound variable` (set -u)                      | ROS setup 스크립트와 nounset 충돌           | `set +u`로 감싸서 `source .../setup.bash`, 미정의 변수 기본값 대입                        |        |             |
| `no service for "org.qt-project.qt.mediaplayer"` | QtMultimedia/GStreamer 누락            | `qml-module-qtmultimedia`, `libqt5multimedia5-plugins`, `gstreamer1.0-*` 설치 |        |             |
| 영상 0:00/검은 화면                                    | 파일 없음/GL 싱크 실패                       | 샘플 mp4 생성(ffmpeg), GL 런처(`...-gl`) 사용                                       |        |             |
| 통신 안 됨                                           | ROS_DOMAIN_ID 불일치                    | `ros2 topic list/echo`로 확인, 동일 도메인 설정                                       |        |             |

* 유용한 로그/명령:

  ```bash
  tail -n 100 /tmp/novnc.log
  QML_IMPORT_TRACE=1 QT_DEBUG_PLUGINS=1 <런처>
  wmctrl -l
  ```

---

## 검증 체크리스트 (Verify)

* noVNC 접속 → 데스크톱 배경 노출
* 비디오 재생(패턴 또는 내 mp4) 확인, HUD 수치 변화
* Seek / A–B Loop 정상 동작
* Snapshot/ROI Snapshot 생성: `/tmp/snap_*.png`, `/tmp/roishot_*.png`
* (옵션) 로그 경고 억제 동작 확인

---

## 리포지토리 위생(.gitignore/가이드)

* 임시/해시 파일, `.bak` 등은 커밋 제외
* 예제 자산은 `assets/` 폴더 사용 권장
* 커밋 메시지 예시:

  ```bash
  git add examples/video_overlay.qml docker/scripts/run-overlay-video-gl
  git commit -m "feat(video-overlay): add QML video overlay (seek, AB loop, ROI snapshot) and headless GL launcher"
  ```

---

## 로드맵 / 알려진 한계

* (로드맵) 실제 ROS 토픽 연동 샘플, 멀티 스트림, 성능 수치 표기(프레임/CPU/GPU), 하드웨어 가속 경로 정리
* (한계) 헤드리스에서 일부 GStreamer 플러그인 조합 의존, 기본 오디오 비활성(필요 시 활성화 가능)

---

## Contributing & Credits

* Upstream: [https://github.com/StefanFabian/qml_ros2_plugin](https://github.com/StefanFabian/qml_ros2_plugin)
* License: MIT (원본과 동일)
* 학술 인용은 아래 Upstream README의 “Scientific Works” 섹션을 참고하세요.

---

<br>

# ⤵ Upstream README (원본 보존)

[![Quality Gate Status](https://sonarcloud.io/api/project_badges/measure?project=StefanFabian_qml_ros2_plugin\&metric=alert_status)](https://sonarcloud.io/summary/new_code?id=StefanFabian_qml_ros2_plugin)
[![Maintainability Rating](https://sonarcloud.io/api/project_badges/measure?project=StefanFabian_qml_ros2_plugin\&metric=sqale_rating)](https://sonarcloud.io/summary/new_code?id=StefanFabian_qml_ros2_plugin)
[![Reliability Rating](https://sonarcloud.io/api/project_badges/measure?project=StefanFabian_qml_ros2_plugin\&metric=reliability_rating)](https://qml-ros2-plugin.readthedocs.io/en/latest/?badge=latest)
[![Security Rating](https://sonarcloud.io/api/project_badges/measure?project=StefanFabian_qml_ros2_plugin\&metric=security_rating)](https://sonarcloud.io/summary/new_code?id=StefanFabian_qml_ros2_plugin)
[![Documentation Status](https://readthedocs.org/projects/qml-ros2-plugin/badge/?version=latest)](https://qml-ros2-plugin.readthedocs.io/en/latest/?badge=latest)

## Scientific Works

If you are using this module in a scientific context, feel free to cite [this paper](https://ieeexplore.ieee.org/document/9568801):

```
@INPROCEEDINGS{fabian2021hri,
  author = {Stefan Fabian and Oskar von Stryk},
  title = {Open-Source Tools for Efficient ROS and ROS2-based 2D Human-Robot Interface Development},
  year = {2021},
  booktitle = {2021 European Conference on Mobile Robots (ECMR)},
}
```

# QML ROS2 Plugin

Connects QML user interfaces to the Robot Operating System 2 (ROS2). [For the ROS 1 version click here](https://github.com/StefanFabian/qml_ros_plugin).
Please be aware that this loses some of the semantic information that the type of a message would normally provide.

Currently, has support for the following:
Logging, Publisher, Subscription, ImageTransportSubscription, Service client, ActionClient, TfTransform, Ament index and querying topics

**License:** MIT

This demo interface uses Tf and a velocity publisher to control and display the turtle demo with less than 200 lines of code for the entire interface.
It is available in the examples folder as `turtle_demo_control.qml`.

**Note:** For full examples including ROS init calls and shutdown handling checkout the examples directory.

## Logging

Logging is supported and correctly reports from which qml file and line the message came!

```qml
import Ros2 1.0

Item {
  function doesWork() {
    Ros2.debug("A debug message")
    // Set the logging level to Debug (default is usually Info)
    Ros2.getLogger().setLoggerLevel(Ros2LoggerLevel.Debug);
    Ros2.debug("A debug message that is actually logged.")
    Ros2.info("I have some information")
    Ros2.warn("This is the last warning")
    Ros2.error("Great! Now there's an error.")
    Ros2.fatal("I'm dead")
    Ros2.info("Just so you know, fatal does not kill a node. Though they usually die after logging fatal")
  }
  // ...
}
```

## Subscribers

Can be used to create a Subscription to any topic and message type that is available on your system.
The type does not need to be known at the time of compilation.

Usage example:

```qml
import Ros2 1.0

Item {
  width: 600
  height: 400

  Subscription {
    id: subscriber
    topic: "/test"
    onNewMessage: textField.text = message.data
  }

  Text {
    text: "You can use the message directly: " + subscriber.message.data
  }

  Text {
    id: textField
    text: "Or you can use the newMessage signal."
  }
}
```

## Image Transport

Can be used to stream camera images.
The default transport used is "compressed".
The stream is exposed to QML as a `QObject` with a `QAbstractVideoSurface` based `videoSurface` property
(see [QML VideoOutput docs](https://doc.qt.io/qt-5/qml-qtmultimedia-videooutput.html#source-prop)) and can be used
directly as source for the `VideoOutput` control.

Multiple ImageTransportSubscribers for the same topic share a subscription to ensure the image is converted
to a QML compatible format only once. Additionally, a throttleRate property allows to throttle the camera rate by
subscribing for one frame and shutting down again at the given rate (see documentation).

Usage example:

```qml
import QtMultimedia 5.4
import Ros2 1.0

Item {
  width: 600
  height: 400

  ImageTransportSubscription {
    id: imageSubscriber
    topic: "/front_rgb_cam"
    throttleRate: 0.2 // 1 frame every 5 seconds
  }

  VideoOutput {
    source: imageSubscriber
  }
}
```

## Tf Lookup

### TfTransformListener

A singleton class that can be used to look up tf transforms.
Usage example:

```qml
import Ros2 1.0

Item {
  // ...
  Connections {
    target: TfTransformListener
    onTransformChanged: {
      var message = TfTransformListener.lookUpTransform("base_link", "world");
      if (!message.valid) {
        // Check message.exception and message.message for more info if it is available.
        return;
      }
      var translation = message.transform.translation;
      var orientation = message.transform.rotation;
      // DO something with the information
    }
  }
}
```

**Explanation**:
You can use the TfTransformListener.lookUpTransform (and canTransform) methods anywhere in your QML code.
However, they only do this look up once and return the result. If you want to continuously monitor the transform, you
have to use the TfTransform component.
The message structure is identical to the ROS message, except for an added *valid* field (`message.valid`) indicating if
the transform returned is valid or not. If it is not valid, there may be a field *exception* containing the name of the
exception that occured and a field *message* with the message of the exception.

### TfTransform

A convenience component that watches a transform.

```qml
import Ros2 1.0

Item {
  // ...
  TfTransform {
    id: tfTransform
    sourceFrame: "base_link"
    targetFrame: "world"
  }

  Text {
    width: parent.width
    // The translation and rotation can either be accessed using the message field as in the lookUpTransform case or,
    // alternatively, using the convenience properties translation and rotation which resolve to the message fields.
    // In either case, the message.valid field should NOT be ignored.
    text: "- Position: " + tfTransform.message.transform.translation.x + ", " + tfTransform.translation.y + ", " + tfTransform.translation.z + "\n" +
          "- Orientation: " + tfTransform.message.transform.rotation.w + ", " + tfTransform.rotation.x + ", " + tfTransform.rotation.y + ", " + tfTransform.rotation.z + "\n" +
          "- Valid: " + tfTransform.message.valid + "\n" +
          "- Exception: " + tfTransform.message.exception + "\n" +
          "- Message: " + tfTransform.message.message
    wrapMode: Text.WordWrap
  }
}
```

**Explanation**:
This component can be used to watch a transform. Whenever the transform changes, the message and the properties of the
TfTransform change and the changes are propagated by QML.

## Installation

You can either build this repository as part of your ROS2 workspace as you would any other ROS2 package, or
set the CMake option `GLOBAL_INSTALL` to `ON` which installs the plugin in your global qml module directory.
**Please note** that the plugin will still require a ROS2 environment when loaded to be able to load the message
libraries.

Other than the source dependencies which are currently not available in the package sources, you can install
the dependencies using rosdep:
*The following command assumes you are in the `src` folder of your ROS 2 workspace*

```
rosdep install --from-paths . --ignore-packages-from-source
```

### Source Dependencies

* [ros_babel_fish](https://github.com/LOEWE-emergenCity/ros2_babel_fish)

## Documentation

You can find the documentation on [readthedocs.io](https://qml-ros2-plugin.readthedocs.io/en/latest/index.html).

Alternatively, you can follow the steps below to build it yourself.

### Dependencies

* Doxygen
* Sphinx
* sphinx_rtd_theme
* Breathe

**Example for Ubuntu**
Install dependencies

```bash
sudo apt install doxygen
pip3 install sphinx sphinx_rtd_theme breathe
```

#### Build documentation

```bash
cd REPO/docs
make html
```

### Known limitations

* JavaScript doesn't have long double, hence, they are cast to double with a possible loss of precision

---
