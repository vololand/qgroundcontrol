# DroneModel/CMakeLists.txt

# 1. 소스 파일 등록 (실제 파일명과 대소문자 일치 필수)
target_sources(${CMAKE_PROJECT_NAME}
    PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}/DroneModel.cpp
        ${CMAKE_CURRENT_SOURCE_DIR}/DroneModel.h
        ${CMAKE_CURRENT_SOURCE_DIR}/DroneManager.cpp
        ${CMAKE_CURRENT_SOURCE_DIR}/DroneManager.h
)

# 2. 헤더 파일 경로 포함
target_include_directories(${CMAKE_PROJECT_NAME}
    PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}
)