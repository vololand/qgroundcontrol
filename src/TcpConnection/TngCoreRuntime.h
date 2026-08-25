#pragma once

#include "TngCryptoConfig.h"

#include <QtCore/QByteArray>
#include <QtCore/QLibrary>
#include <QtCore/QMutex>
#include <QtCore/QString>

class TngCoreRuntime
{
public:
    using InitCoreFn = int (*)(unsigned char *, int, unsigned char *, int);
    using CloseCoreFn = int (*)();
    using SetKeystorePathFn = int (*)(char *, int);
    using GenerateRandomNumberFn = int (*)(unsigned char *, int, int);
    using OpenSessionFn = int (*)(unsigned int *, unsigned char *, unsigned int, int, int, unsigned char *, unsigned int, unsigned int);
    using CloseSessionFn = int (*)(unsigned int);
    using EncSymmFn = int (*)(unsigned int, const unsigned char *, unsigned int, unsigned char **, unsigned int *);
    using DecSymmFn = int (*)(unsigned int, const unsigned char *, unsigned int, unsigned char **, unsigned int *);
    using EncHsFn = int (*)(unsigned int, const unsigned char *, unsigned int, unsigned char **, unsigned int *);
    using DecHsFn = int (*)(unsigned int, const unsigned char *, unsigned int, unsigned char **, unsigned int *);
    using CoreVersionFn = unsigned char *(*)();
    using ReadLatestKeyFn = int (*)(unsigned char *, int *, int *);
    using ReadKeyFn = int (*)(int, unsigned char *, int *);
    using SaveKeyFn = int (*)(void *, int, char *, int, int *);
    using SetDeviceInfoFn = int (*)(unsigned char *, unsigned char *, unsigned char *, unsigned char *, unsigned char *);
    using GetSavedKeyListFn = int (*)(void *, int *);
    using DestroyKeyFn = int (*)(int);
    using DestroyAllKeyFn = void (*)();

    static TngCoreRuntime &instance();

    /// 코어를 취득한다. 첫 취득자만 DLL 로드 → tngInitCore → tngSetKeystorePath 를 수행하고,
    /// 이후 취득자는 참조 계수만 올린다.
    /// 이미 다른 identity(dll 경로 / sys_unique / package_id / keystore_path)로 초기화돼 있으면
    /// 조용히 재사용하지 않고 실패시킨다 — 요청과 다른 identity 로 돌면 복호 결과만 어긋난다.
    bool acquire(const TngCryptoConfig &config, QString *error = nullptr);
    /// 마지막 사용자가 놓을 때만 tngCloseCore + unload 한다.
    void release();

    bool isReady() const { return _users > 0; }
    bool highSpeedAvailable() const { return _encHs && _decHs; }

    // 심볼 접근자. acquire() 성공 이후 release() 전까지만 유효하다.
    GenerateRandomNumberFn genRnd() const { return _genRnd; }
    OpenSessionFn openSession() const { return _openSession; }
    CloseSessionFn closeSession() const { return _closeSession; }
    EncSymmFn encSymm() const { return _encSymm; }
    DecSymmFn decSymm() const { return _decSymm; }
    EncHsFn encHs() const { return _encHs; }
    DecHsFn decHs() const { return _decHs; }
    ReadLatestKeyFn readLatestKey() const { return _readLatestKey; }
    ReadKeyFn readKey() const { return _readKey; }
    SaveKeyFn saveKey() const { return _saveKey; }
    SetDeviceInfoFn setDeviceInfo() const { return _setDeviceInfo; }
    GetSavedKeyListFn getSavedKeyList() const { return _getSavedKeyList; }
    DestroyKeyFn destroyKey() const { return _destroyKey; }
    DestroyAllKeyFn destroyAllKey() const { return _destroyAllKey; }

private:
    TngCoreRuntime() = default;
    /// instance() 가 의도적으로 파괴하지 않으므로 호출되지 않는다(정적 소멸 순서 회피).
    ~TngCoreRuntime() = default;

    Q_DISABLE_COPY_MOVE(TngCoreRuntime)

    bool _resolveSymbols(QString *error);
    void _clearSymbols();
    /// tngCloseCore → 심볼 해제 → unload. _mutex 를 잡은 상태에서만 호출한다.
    void _shutdown();
    static QByteArray _identityOf(const TngCryptoConfig &config);

    QMutex _mutex;
    QLibrary _lib;
    QByteArray _identity;
    int _users = 0;

    InitCoreFn _initCore = nullptr;
    CloseCoreFn _closeCore = nullptr;
    SetKeystorePathFn _setKeystorePath = nullptr;
    GenerateRandomNumberFn _genRnd = nullptr;
    OpenSessionFn _openSession = nullptr;
    CloseSessionFn _closeSession = nullptr;
    EncSymmFn _encSymm = nullptr;
    DecSymmFn _decSymm = nullptr;
    EncHsFn _encHs = nullptr;
    DecHsFn _decHs = nullptr;
    CoreVersionFn _coreVersion = nullptr;
    ReadLatestKeyFn _readLatestKey = nullptr;
    ReadKeyFn _readKey = nullptr;
    SaveKeyFn _saveKey = nullptr;
    SetDeviceInfoFn _setDeviceInfo = nullptr;
    GetSavedKeyListFn _getSavedKeyList = nullptr;
    DestroyKeyFn _destroyKey = nullptr;
    DestroyAllKeyFn _destroyAllKey = nullptr;
};
