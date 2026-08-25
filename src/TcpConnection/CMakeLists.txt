# TcpConnection/CMakeLists.txt

# 1. 소스 파일 등록 (대소문자 일치 필수)
target_sources(${CMAKE_PROJECT_NAME}
    PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}/ServerTcpClient.cpp
        ${CMAKE_CURRENT_SOURCE_DIR}/ServerTcpClient.h
        ${CMAKE_CURRENT_SOURCE_DIR}/TngCryptoConfig.cpp
        ${CMAKE_CURRENT_SOURCE_DIR}/TngCryptoConfig.h
        ${CMAKE_CURRENT_SOURCE_DIR}/TngCryptoSettings.cpp
        ${CMAKE_CURRENT_SOURCE_DIR}/TngCryptoSettings.h
        ${CMAKE_CURRENT_SOURCE_DIR}/TngCoreRuntime.cpp
        ${CMAKE_CURRENT_SOURCE_DIR}/TngCoreRuntime.h
        ${CMAKE_CURRENT_SOURCE_DIR}/TngCryptoEngine.cpp
        ${CMAKE_CURRENT_SOURCE_DIR}/TngCryptoEngine.h
        ${CMAKE_CURRENT_SOURCE_DIR}/McmLCryptoEngine.cpp
        ${CMAKE_CURRENT_SOURCE_DIR}/McmLCryptoEngine.h
        ${CMAKE_CURRENT_SOURCE_DIR}/CryptoLinkMonitor.cpp
        ${CMAKE_CURRENT_SOURCE_DIR}/CryptoLinkMonitor.h
        ${CMAKE_CURRENT_SOURCE_DIR}/EncryptedTcpPipe.cpp
        ${CMAKE_CURRENT_SOURCE_DIR}/EncryptedTcpPipe.h
        ${CMAKE_CURRENT_SOURCE_DIR}/EncryptedMavlinkLink.cpp
        ${CMAKE_CURRENT_SOURCE_DIR}/EncryptedMavlinkLink.h
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

# 4. tngCore 런타임 DLL 배포 (Windows 전용)
#    TngCryptoEngine 이 런타임(QLibrary)에 로드하는 서드파티 바이너리.
#    소스에서 빌드하는 대상이 아니라 tngCore SDK 가 제공하는 사전 컴파일 DLL 이므로
#    빌드 출력(exe 옆)과 install 출력(bin)에 그대로 복사한다.
#    resolvedDllPath() 기본값(lib_dir=".")이 applicationDirPath() 이므로 exe 옆에 두어야 로드된다.
if(WIN32)
    set(QGC_TNGCORE_SDK_DIR "C:/Users/user/Desktop/tngCore/bin/tngCore_V2.4.0_Windows11_x86_64"
        CACHE PATH "tngCore Windows SDK bin directory containing tngcore.dll and its runtime dependencies")

    # tngcore.dll 은 libTNG-Crypto.dll / pthreadVC2.dll 에 의존하므로 세 개를 모두 배포한다.
    set(QGC_TNGCORE_RUNTIME_DLLS
        "${QGC_TNGCORE_SDK_DIR}/tngcore.dll"
        "${QGC_TNGCORE_SDK_DIR}/libTNG-Crypto.dll"
        "${QGC_TNGCORE_SDK_DIR}/pthreadVC2.dll"
    )

    set(QGC_TNGCORE_DLLS_PRESENT TRUE)
    foreach(_dll ${QGC_TNGCORE_RUNTIME_DLLS})
        if(NOT EXISTS "${_dll}")
            set(QGC_TNGCORE_DLLS_PRESENT FALSE)
            message(WARNING "QGC: tngCore runtime DLL not found: ${_dll} "
                            "(set QGC_TNGCORE_SDK_DIR to the correct SDK bin folder). "
                            "Encrypted TCP/MAVLink will fail to load at runtime.")
        endif()
    endforeach()

    if(QGC_TNGCORE_DLLS_PRESENT)
        # (a) 빌드 후 exe 폴더로 복사할 DLL 목록을 전역 속성으로 노출한다.
        #     add_custom_command(TARGET) 은 타깃이 생성된 디렉터리(루트 CMakeLists.txt)에서만
        #     호출할 수 있으므로, 실제 POST_BUILD 복사는 루트에서 이 목록을 읽어 수행한다.
        set_property(GLOBAL PROPERTY QGC_TNGCORE_RUNTIME_DLLS "${QGC_TNGCORE_RUNTIME_DLLS}")

        # (b) install(release) 시 bin 으로 설치 — NSIS 인스톨러 패키징에 포함.
        install(FILES ${QGC_TNGCORE_RUNTIME_DLLS}
            DESTINATION ${CMAKE_INSTALL_BINDIR}
        )
    endif()
endif()

# 5. MCM-L 런타임 DLL 배포 (Windows 전용, tngCore와 배타 사용이지만 둘 다 exe 옆에 둔다)
if(WIN32)
    set(QGC_MCML_SDK_DIR "C:/Users/user/Desktop/군 개발 암호모듈 경량화 버전/kcmvp/LIBRARY/Windows_10_11"
        CACHE PATH "MCM-L Windows library directory containing mcrypto_light_v1.0-x64_win.dll")

    set(QGC_MCML_RUNTIME_DLL "${QGC_MCML_SDK_DIR}/mcrypto_light_v1.0-x64_win.dll")

    if(EXISTS "${QGC_MCML_RUNTIME_DLL}")
        set_property(GLOBAL PROPERTY QGC_MCML_RUNTIME_DLLS "${QGC_MCML_RUNTIME_DLL}")
        install(FILES ${QGC_MCML_RUNTIME_DLL}
            DESTINATION ${CMAKE_INSTALL_BINDIR}
        )
    else()
        message(WARNING "QGC: MCM-L runtime DLL not found: ${QGC_MCML_RUNTIME_DLL} "
                        "(set QGC_MCML_SDK_DIR to the Windows_10_11 library folder). "
                        "MCM-L encrypted TCP/MAVLink will fail to load at runtime.")
    endif()
endif()
