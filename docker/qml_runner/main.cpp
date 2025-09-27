#include <QGuiApplication>
#include <QQuickView>
#include <QQmlApplicationEngine>
#include <QCommandLineParser>
#include <QFileInfo>
#include <QUrl>
#include <QDebug>
#include <QWindow>
#include <QRegularExpression>

static bool applyGeometry(QWindow* win, const QString& geom) {
    QRegularExpression re("^(\\d+)x(\\d+)\\+(\\-?\\d+)\\+(\\-?\\d+)$");
    auto m = re.match(geom);
    if (!m.hasMatch()) return false;
    win->resize(m.captured(1).toInt(), m.captured(2).toInt());
    win->setPosition(m.captured(3).toInt(), m.captured(4).toInt());
    return true;
}

int main(int argc, char *argv[]) {
    QGuiApplication app(argc, argv);
    QCommandLineParser parser;
    parser.setApplicationDescription("qml_runner (supports non-Window & forces Window.show())");
    parser.addHelpOption();
    QCommandLineOption geometryOpt({"g","geometry"}, "Geometry WxH+X+Y.", "geom");
    parser.addOption(geometryOpt);
    parser.addPositionalArgument("file", "QML file");
    parser.process(app);

    const auto args = parser.positionalArguments();
    if (args.isEmpty()) { qWarning() << "[qml_runner] No QML file specified."; return 1; }
    const QString qmlPath = QFileInfo(args.first()).absoluteFilePath();
    const QUrl url = QUrl::fromLocalFile(qmlPath);
    const QString geom = parser.value(geometryOpt);

    // 1) QQuickView (Item/Rectangle 루트)
    QQuickView view;
    view.setResizeMode(QQuickView::SizeRootObjectToView);
    view.setSource(url);
    if (view.errors().isEmpty()) {
        view.show();
        return app.exec();
    }
    for (const auto &e : view.errors()) qWarning() << "[qml_runner] view error:" << e.toString();

    // 2) QQmlApplicationEngine (Window 루트) + 강제 show()
    QQmlApplicationEngine engine;
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreated, &app,
                     [&url](QObject *obj, const QUrl &objUrl) {
                         if (!obj && url == objUrl) QCoreApplication::exit(-1);
                     }, Qt::QueuedConnection);
    engine.load(url);
    if (engine.rootObjects().isEmpty()) { qCritical() << "[qml_runner] No root objects after load."; return 1; }

    for (QObject* obj : engine.rootObjects()) {
        if (auto *win = qobject_cast<QWindow*>(obj)) {
            if (!geom.isEmpty()) applyGeometry(win, geom);
            if (!win->isVisible()) win->show();
        }
    }
    return app.exec();
}

