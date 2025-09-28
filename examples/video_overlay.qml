import QtQuick 2.15
import QtQuick.Controls 2.15
import QtMultimedia 5.15

Rectangle {
  id: root
  width: 1100; height: 660; color: "black"
  focus: true

  MediaPlayer {
    id: player
    source: "file:///ws/assets/sample.mp4"
    autoPlay: true
    loops: MediaPlayer.Infinite
    playbackRate: speed.value
    onError: console.error("MediaPlayer error:", errorString)
  }
  VideoOutput { anchors.fill: parent; source: player; fillMode: VideoOutput.PreserveAspectFit }

  // UI refresh FPS
  property int frame: 0; property real fps: 0.0; property double _last: 0
  Timer {
    interval: 33; repeat: true; running: true
    onTriggered: {
      frame++; overlay.requestPaint()
      var now=Date.now(); if(_last>0){var dt=(now-_last)/1000; var inst=1/Math.max(dt,1e-6); fps=fps*0.8+inst*0.2}else fps=30; _last=now
    }
  }

  // ROI (normalized)
  property real roiX: 0.33; property real roiY: 0.33
  property real roiW: 0.40; property real roiH: 0.30

  // Overlay
  Canvas {
    id: overlay; anchors.fill: parent; antialiasing: true
    onPaint: {
      var c=getContext('2d'), w=width, h=height; c.clearRect(0,0,w,h)
      // crosshair
      c.strokeStyle='white'; c.lineWidth=2; c.beginPath()
      c.moveTo(w/2-50,h/2); c.lineTo(w/2+50,h/2)
      c.moveTo(w/2,h/2-50); c.lineTo(w/2,h/2+50); c.stroke()
      // ROI
      var x=roiX*w, y=roiY*h, rw=roiW*w, rh=roiH*h
      c.strokeStyle='#ff4040'; c.lineWidth=3; c.strokeRect(x,y,rw,rh)
      // labels
      c.fillStyle='rgba(0,0,0,0.55)'; c.fillRect(10,10,300,86)
      c.font="bold 16px 'DejaVu Sans'"; c.fillStyle='white'
      function tc(ms){var s=Math.max(0,Math.floor(ms/1000)),m=Math.floor(s/60),sec=s%60,t=Math.floor((ms%1000)/100);return (m<10?'0':'')+m+':'+(sec<10?'0':'')+sec+'.'+t}
      c.fillText('FPS: '+root.fps.toFixed(1),20,34)
      c.fillText('Time: '+tc(player.position)+' / '+tc(Math.max(player.duration,1)),20,58)
      c.fillText('Rate: x'+speed.value.toFixed(2),20,82)
    }
    // ROI drag
    property bool drag:false; property real sx:0; property real sy:0; property real srx:0; property real sry:0
    MouseArea{
      anchors.fill: parent
      onPressed:(e)=>{overlay.drag=true; overlay.sx=e.x; overlay.sy=e.y; overlay.srx=root.roiX; overlay.sry=root.roiY; e.accepted=true}
      onPositionChanged:(e)=>{if(!overlay.drag)return; var dx=(e.x-overlay.sx)/overlay.width, dy=(e.y-overlay.sy)/overlay.height
        root.roiX=Math.max(0,Math.min(1-root.roiW,overlay.srx+dx)); root.roiY=Math.max(0,Math.min(1-root.roiH,overlay.sry+dy)); overlay.requestPaint()}
      onReleased:()=>overlay.drag=false
    }
  }

  // Control panel
  Rectangle {
    anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 12
    width: 360; height: 330; radius: 10; color: "#44000000"
    Column {
      anchors.fill: parent; anchors.margins: 12; spacing: 8
      Text { text: "Video Overlay"; color: "white"; font.bold: true }

      Row {
        spacing: 8
        Button {
          id: playBtn
          text: player.playbackState===MediaPlayer.PlayingState ? "Pause" : "Play"
          onClicked: { player.playbackState===MediaPlayer.PlayingState ? player.pause() : player.play() }
          contentItem: Text { text: playBtn.text; color: "white" }
          background: Rectangle { radius: 6; color: "#444" }
          width: 80; height: 34
        }
        Button {
          id: stopBtn; text: "Stop"; onClicked: player.stop()
          contentItem: Text { text: stopBtn.text; color: "white" }
          background: Rectangle { radius: 6; color: "#444" }
          width: 70; height: 34
        }
        Button {
          id: snapBtn; text: "Snapshot"
          onClicked: root.grabToImage(function(img){var p='/tmp/snap_'+Date.now()+'.png'; img.saveToFile(p); console.log('saved:',p)})
          contentItem: Text { text: snapBtn.text; color: "white" }
          background: Rectangle { radius: 6; color: "#444" }
          width: 100; height: 34
        }
        Button {
          id: roiBtn; text: "ROI Shot"
          onClicked: {
            root.grabToImage(function(img){
              var w=root.width,h=root.height, rx=Math.round(root.roiX*w), ry=Math.round(root.roiY*h)
              var rw=Math.round(root.roiW*w), rh=Math.round(root.roiH*h)
              var p='/tmp/roishot_'+Date.now()+'.png'
              img.saveToFile(p,{clipRect:{x:rx,y:ry,width:rw,height:rh}})
              console.log('saved ROI snapshot:',p)
            })
          }
          contentItem: Text { text: roiBtn.text; color: "white" }
          background: Rectangle { radius: 6; color: "#444" }
          width: 100; height: 34
        }
      }

      Row { spacing:8
        Text { text: "Rate"; color: "white"; width: 60 }
        Slider { id: speed; from:0.25; to:2.0; value:1.0; stepSize:0.05; width: 210
          onValueChanged: player.playbackRate=value }
        Text { text: "x"+speed.value.toFixed(2); color: "white"; width: 60 }
      }
      Row { spacing:8
        Text { text: "ROI W"; color: "white"; width: 60 }
        Slider { from:0.1; to:0.9; value:root.roiW; width: 270; onValueChanged: root.roiW=value }
      }
      Row { spacing:8
        Text { text: "ROI H"; color: "white"; width: 60 }
        Slider { from:0.1; to:0.9; value:root.roiH; width: 270; onValueChanged: root.roiH=value }
      }

      // Seek bar
      Row { spacing:8
        Text { text: "Pos"; color:"white"; width:60 }
        Slider {
          id: seek; width: 270
          from: 0; to: Math.max(player.duration, 1)
          value: player.position
          onMoved: player.seek(value)    // position은 read-only → seek 사용
        }
        Text { text: (player.position/1000).toFixed(1)+"s"; color:"white"; width:60 }
      }

      // A–B loop
      Row {
        id: loopRow
        spacing: 8
        property bool loopOn: false
        property int loopA: 0
        property int loopB: 0

        Button {
          id: loopBtn; text: loopRow.loopOn ? "Loop: ON" : "Loop: OFF"
          onClicked: loopRow.loopOn = !loopRow.loopOn
          contentItem: Text { text: loopBtn.text; color: "white" }
          background: Rectangle { radius: 6; color: "#444" }
          width: 110; height: 34
        }
        Button {
          id: setA; text: "Set A"; onClicked: loopRow.loopA = player.position
          contentItem: Text { text: setA.text; color: "white" }
          background: Rectangle { radius: 6; color: "#444" }
          width: 70; height: 34
        }
        Button {
          id: setB; text: "Set B"; onClicked: loopRow.loopB = player.position
          contentItem: Text { text: setB.text; color: "white" }
          background: Rectangle { radius: 6; color: "#444" }
          width: 70; height: 34
        }

        // Connections: 최신 문법 + seek 사용
        Connections {
          target: player
          function onPositionChanged() {
            seek.value = player.position
            if (loopRow.loopOn && loopRow.loopB > loopRow.loopA && player.position >= loopRow.loopB)
              player.seek(loopRow.loopA)
          }
          function onDurationChanged() { seek.to = Math.max(player.duration, 1) }
        }
      }
    }
  }

  // Keyboard shortcuts (seek로 교체)
  Keys.onSpacePressed: { player.playbackState===MediaPlayer.PlayingState ? player.pause() : player.play() }
  Keys.onLeftPressed:  player.seek(Math.max(0, player.position - 1000))
  Keys.onRightPressed: player.seek(Math.min(player.duration, player.position + 1000))

  onWidthChanged: overlay.requestPaint()
  onHeightChanged: overlay.requestPaint()
}
