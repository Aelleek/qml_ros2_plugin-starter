cmake_minimum_required(VERSION 3.12)
project(qml_runner LANGUAGES CXX)

set(CMAKE_AUTOMOC ON)
set(CMAKE_CXX_STANDARD 14)

find_package(Qt5 REQUIRED COMPONENTS Core Gui Qml Quick)

add_executable(qml_runner main.cpp)
target_link_libraries(qml_runner Qt5::Core Qt5::Gui Qt5::Qml Qt5::Quick)

