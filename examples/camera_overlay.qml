/*
  camera_overlay.qml — Synthetic camera overlay demo (no external camera/files)
  ---------------------------------------------------------------------------
  목적:
    - 실제 카메라/동영상 없이도 '카메라 위 UI'를 시연하기 위한 합성(synthetic) 영상 + 오버레이 데모.
    - 헤드리스(Xvfb) 환경에서 안정적으로 동작하도록, 외부 의존성을 제거함.

  구조:
    [A] videoCanvas (Canvas)
        - 회전 그라디언트 + 컬러 막대 + 바운싱 박스를 그려 '움직이는 영상'을 생성.
        - 나중에 실제 소스로 교체 시, 이 onPaint만 실제 프레임 렌더링으로 바꾸면 됨.

    [B] overlay (Canvas)
        - 십자선, ROI 박스, 텔레메트리(FPS/ROI) 라벨을 그리는 레이어.
        - MouseArea로 ROI 박스를 드래그해 위치 이동 가능.

    [C] 우측 컨트롤 패널 (Rectangle + Controls)
        - Target FPS 슬라이더(합성 프레임레이트), ROI W/H 슬라이더, Snapshot 버튼.
        - Snapshot은 현재 화면(root)을 캡처해 /tmp/snap_*.png로 저장.

  핵심 포인트:
    - FPS 추정: Timer 틱 간격을 Date.now()로 측정, 지수평활(EWA 0.2)로 부드럽게 표시.
    - 오버레이/패널은 소스와 독립 → 실제 카메라/RTSP/ROS Image로 교체해도 재사용 가능.
*/

import QtQuick 2.15
import QtQuick.Controls 2.15

Rectangle {
  id: root
  width: 960
  height: 540
  color: "black"

  // ----------------------------
  // [상태] 프레임 카운트 / FPS 추정치
  // ----------------------------
  property int frame: 0                 // 누적 프레임 번호
  property real fps: 0.0                // 화면 표시용 FPS 추정치
  property double _lastFpsStamp: 0      // 직전 프레임 타임스탬프(ms)

  // ----------------------------
  // [타이머] 타겟 FPS에 맞춰 합성 영상/오버레이 갱신
  // ----------------------------
  Timer {
    id: tick
    interval: Math.max(1, Math.round(1000 / fpsTarget.value)) // 타깃 FPS → ms 간격
    repeat: true
    running: true
    onTriggered: {
      root.frame++                              // 1) 프레임 증가
      videoCanvas.requestPaint()                // 2) 합성 영상 리페인트
      overlay.requestPaint()                    // 3) 오버레이 리페인트

      // 4) FPS 추정(EWA 0.2)
      var now = Date.now()
      if (root._lastFpsStamp > 0) {
        var dt = (now - root._lastFpsStamp) / 1000.0
        var inst = 1.0 / Math.max(1e-6, dt)
        root.fps = root.fps * 0.8 + inst * 0.2
      } else {
        root.fps = fpsTarget.value
      }
      root._lastFpsStamp = now
    }
  }

  // ============================
  // [A] 합성 '영상' 레이어
  // ============================
  Canvas {
    id: videoCanvas
    anchors.fill: parent
    antialiasing: false
    onPaint: {
      var ctx = getContext("2d")
      var w = width, h = height

      ctx.clearRect(0, 0, w, h)  // 전체 초기화

      // (1) 회전하는 그라디언트 배경 → 카메라 팬/틸트 느낌
      ctx.save()
      ctx.translate(w/2, h/2)
      ctx.rotate((root.frame % 360) * Math.PI / 360.0)
      var grad = ctx.createLinearGradient(-w/2, -h/2, w/2, h/2)
      grad.addColorStop(0.0, "#202020")
      grad.addColorStop(0.5, "#2b2b50")
      grad.addColorStop(1.0, "#404040")
      ctx.fillStyle = grad
      ctx.fillRect(-w/2, -h/2, w, h)
      ctx.restore()

      // (2) 상단 컬러 막대 → 시간 경과에 따른 색 변화
      var bars = 7
      var barW = Math.ceil(w / bars)
      for (var i = 0; i < bars; ++i) {
        var phase = (root.frame * 2 + i * 30) % 360
        var hue = (phase % 360)
        ctx.fillStyle = "hsl(" + hue + ", 60%, 45%)"
        ctx.fillRect(i * barW, 0, barW - 2, h/3)
      }

      // (3) 바운싱 박스 → 화면을 움직이며 동적 요소 제공
      var t = root.frame / 30.0
      var bx = (Math.sin(t*1.3) * 0.4 + 0.5) * (w - 120)
      var by = (Math.sin(t*1.7 + 1.2) * 0.4 + 0.5) * (h - 120)
      ctx.fillStyle = "#88ffffff"
      ctx.fillRect(bx, by, 120, 120)

      // (4) 좌하단 타임코드(프레임 표시)
      ctx.font = "bold 16px 'DejaVu Sans'"
      ctx.fillStyle = "white"
      ctx.fillText("SYNTH FEED  |  frame " + root.frame, 12, h - 16)
    }
  }

  // ============================
  // [B] 오버레이(ROI, 십자선, 라벨)
  // ============================
  // ROI는 정규화 좌표계 [0..1]로 가짐 → 해상도/윈도 크기와 무관하게 일관
  property real roiX: 0.3   // 좌상단 X (normalized)
  property real roiY: 0.3   // 좌상단 Y (normalized)
  property real roiW: 0.4   // 너비 비율
  property real roiH: 0.3   // 높이 비율

  Canvas {
    id: overlay
    anchors.fill: parent
    antialiasing: true

    onPaint: {
      var ctx = getContext("2d")
      var w = width, h = height
      ctx.clearRect(0, 0, w, h)

      // (1) 중앙 십자선
      ctx.strokeStyle = "white"
      ctx.lineWidth = 2
      ctx.beginPath()
      ctx.moveTo(w/2 - 40, h/2); ctx.lineTo(w/2 + 40, h/2)
      ctx.moveTo(w/2, h/2 - 40); ctx.lineTo(w/2, h/2 + 40)
      ctx.stroke()

      // (2) ROI 박스 (빨간색)
      var x = roiX * w, y = roiY * h, rw = roiW * w, rh = roiH * h
      ctx.strokeStyle = "#ff4040"
      ctx.lineWidth = 3
      ctx.strokeRect(x, y, rw, rh)

      // (3) 좌상단 텔레메트리 박스 (FPS/ROI)
      ctx.fillStyle = "rgba(0,0,0,0.55)"
      ctx.fillRect(10, 10, 220, 74)
      ctx.font = "bold 14px 'DejaVu Sans'"
      ctx.fillStyle = "white"
      ctx.fillText("FPS: " + root.fps.toFixed(1), 20, 34)
      ctx.fillText(
        "ROI: [" + roiX.toFixed(2) + ", " + roiY.toFixed(2) + "] "
        + (roiW*width).toFixed(0) + "x" + (roiH*height).toFixed(0),
        20, 58
      )
    }

    // ---- 드래그 상태값 ----
    property bool dragging: false
    property real dragStartX: 0
    property real dragStartY: 0
    property real startRoiX: 0
    property real startRoiY: 0

    // ---- 마우스 이벤트로 ROI 이동 ----
    MouseArea {
      anchors.fill: parent

      // 클릭 시작 → 기준점 저장
      onPressed: function(ev) {
        overlay.dragging = true
        overlay.dragStartX = ev.x
        overlay.dragStartY = ev.y
        overlay.startRoiX = root.roiX
        overlay.startRoiY = root.roiY
        ev.accepted = true
      }

      // 드래그 중 → 마우스 이동을 정규화 좌표로 환산해서 ROI 위치 갱신
      onPositionChanged: function(ev) {
        if (!overlay.dragging) return
        var dx = (ev.x - overlay.dragStartX) / overlay.width
        var dy = (ev.y - overlay.dragStartY) / overlay.height
        root.roiX = Math.max(0, Math.min(1 - root.roiW, overlay.startRoiX + dx))
        root.roiY = Math.max(0, Math.min(1 - root.roiH, overlay.startRoiY + dy))
        overlay.requestPaint()
      }

      // 드래그 종료
      onReleased: function(_) { overlay.dragging = false }
    }
  }

  // ============================
  // [C] 우측 컨트롤 패널
  // ============================
  Rectangle {
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.margins: 12
    width: 260
    height: 210
    color: "#66000000"
    radius: 10

    Column {
      anchors.fill: parent
      anchors.margins: 12
      spacing: 8

      Text { text: "Camera Overlay (Synthetic)"; color: "white"; font.bold: true }

      // Target FPS 슬라이더 → Timer.interval 계산에 사용
      Row {
        spacing: 8
        Text { text: "Target FPS"; color: "white"; width: 90 }
        Slider { id: fpsTarget; from: 10; to: 60; value: 30; stepSize: 1; width: 140 }
      }
      Text { text: fpsTarget.value.toFixed(0) + " fps"; color: "white" }

      // ROI 너비/높이 슬라이더 (값 변경 시 즉시 반영)
      Row {
        spacing: 8
        Text { text: "ROI W"; color: "white"; width: 90 }
        Slider { from: 0.1; to: 0.8; value: root.roiW; onValueChanged: root.roiW = value; width: 140 }
      }
      Row {
        spacing: 8
        Text { text: "ROI H"; color: "white"; width: 90 }
        Slider { from: 0.1; to: 0.8; value: root.roiH; onValueChanged: root.roiH = value; width: 140 }
      }

      // Snapshot 버튼 → root 전체를 캡처해 /tmp/snap_*.png 저장
      Button {
        text: "Snapshot"
        onClicked: {
          root.grabToImage(function(result) {
            var path = "/tmp/snap_" + Date.now() + ".png"
            result.saveToFile(path)
            console.log("saved snapshot to", path)
          })
        }
      }
    }
  }

  // 리사이즈 시 오버레이 리페인트(픽셀 단위 ROI 라벨이 즉시 갱신되도록)
  onWidthChanged: overlay.requestPaint()
  onHeightChanged: overlay.requestPaint()
}
