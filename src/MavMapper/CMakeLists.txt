# TcpConnection/CMakeLists.txt

# 1. 소스 파일 등록 (대소문자 일치 필수)
target_sources(${CMAKE_PROJECT_NAME}
    PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}/MavMapper.js
)

# 2. 헤더 파일 경로 포함
target_include_directories(${CMAKE_PROJECT_NAME}
    PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}
)

# 3. Qt6 Network 모듈 연결
target_link_libraries(${CMAKE_PROJECT_NAME}
    PRIVATE
        Qt6::Network
)