#include "TngCoreRuntime.h"

#include <QtCore/QDir>
#include <QtCore/QMutexLocker>

TngCoreRuntime &TngCoreRuntime::instance()
{
    static TngCoreRuntime *runtime = new TngCoreRuntime;
    return *runtime;
}

QByteArray TngCoreRuntime::_identityOf(const TngCryptoConfig &config)
{
    QByteArray id;
    id += QDir::toNativeSeparators(config.resolvedDllPath()).toUtf8();
    id += '|';
    id += config.sysUnique.toUtf8();
    id += '|';
    id += config.packageId.toUtf8();
    id += '|';
    id += QDir::toNativeSeparators(config.keystorePath).toUtf8();
    return id;
}

bool TngCoreRuntime::_resolveSymbols(QString *error)
{
    _initCore = reinterpret_cast<InitCoreFn>(_lib.resolve("tngInitCore"));
    _closeCore = reinterpret_cast<CloseCoreFn>(_lib.resolve("tngCloseCore"));
    _setKeystorePath = reinterpret_cast<SetKeystorePathFn>(_lib.resolve("tngSetKeystorePath"));
    _genRnd = reinterpret_cast<GenerateRandomNumberFn>(_lib.resolve("tngGenerateRandomNumber"));
    _openSession = reinterpret_cast<OpenSessionFn>(_lib.resolve("tngOpenSession"));
    _closeSession = reinterpret_cast<CloseSessionFn>(_lib.resolve("tngCloseSession"));
    _encSymm = reinterpret_cast<EncSymmFn>(_lib.resolve("tngEncSymm"));
    _decSymm = reinterpret_cast<DecSymmFn>(_lib.resolve("tngDecSymm"));
    _encHs = reinterpret_cast<EncHsFn>(_lib.resolve("tngEncHs"));
    _decHs = reinterpret_cast<DecHsFn>(_lib.resolve("tngDecHs"));
    _coreVersion = reinterpret_cast<CoreVersionFn>(_lib.resolve("tngCoreVersion"));
    _readLatestKey = reinterpret_cast<ReadLatestKeyFn>(_lib.resolve("tngReadLatestKey"));
    _readKey = reinterpret_cast<ReadKeyFn>(_lib.resolve("tngReadKey"));
    _saveKey = reinterpret_cast<SaveKeyFn>(_lib.resolve("tngSaveKey"));
    _setDeviceInfo = reinterpret_cast<SetDeviceInfoFn>(_lib.resolve("tngSetDeviceInfo"));
    _getSavedKeyList = reinterpret_cast<GetSavedKeyListFn>(_lib.resolve("tngGetSavedKeyList"));
    _destroyKey = reinterpret_cast<DestroyKeyFn>(_lib.resolve("tngDestroyKey"));
    _destroyAllKey = reinterpret_cast<DestroyAllKeyFn>(_lib.resolve("tngDestroyAllKey"));

    if (!_initCore || !_closeCore || !_genRnd || !_openSession || !_closeSession || !_encSymm || !_decSymm) {
        if (error) {
            *error = QStringLiteral("tngcore.dll symbol resolve failed: %1").arg(_lib.errorString());
        }
        return false;
    }
    return true;
}

void TngCoreRuntime::_clearSymbols()
{
    _initCore = nullptr;
    _closeCore = nullptr;
    _setKeystorePath = nullptr;
    _genRnd = nullptr;
    _openSession = nullptr;
    _closeSession = nullptr;
    _encSymm = nullptr;
    _decSymm = nullptr;
    _encHs = nullptr;
    _decHs = nullptr;
    _coreVersion = nullptr;
    _readLatestKey = nullptr;
    _readKey = nullptr;
    _saveKey = nullptr;
    _setDeviceInfo = nullptr;
    _getSavedKeyList = nullptr;
    _destroyKey = nullptr;
    _destroyAllKey = nullptr;
}

void TngCoreRuntime::_shutdown()
{
    if (_closeCore) {
        _closeCore();
    }
    _clearSymbols();
    if (_lib.isLoaded()) {
        _lib.unload();
    }
    _identity.clear();
    _users = 0;
}

bool TngCoreRuntime::acquire(const TngCryptoConfig &config, QString *error)
{
    QMutexLocker locker(&_mutex);

    const QByteArray identity = _identityOf(config);

    if (_users > 0) {
        if (_identity != identity) {
            if (error) {
                *error = QStringLiteral("tngcore core is already initialized with a different identity "
                                        "(in use: %1 / requested: %2). "
                                        "crypto.ini 와 video_endpoints.ini 의 lib_dir/sys_unique/package_id/keystore_path 를 일치시키십시오.")
                             .arg(QString::fromUtf8(_identity), QString::fromUtf8(identity));
            }
            return false;
        }
        ++_users;
        return true;
    }

    const QString dllPath = config.resolvedDllPath();
    _lib.setFileName(dllPath);
    if (!_lib.load()) {
        if (error) {
            *error = QStringLiteral("failed to load tngcore dll '%1': %2").arg(dllPath, _lib.errorString());
        }
        return false;
    }

    if (!_resolveSymbols(error)) {
        _clearSymbols();
        _lib.unload();
        return false;
    }

    QByteArray sys = config.sysUnique.toUtf8();
    QByteArray pkg = config.packageId.toUtf8();
    const int rc = _initCore(reinterpret_cast<unsigned char *>(sys.data()), sys.size(),
                             reinterpret_cast<unsigned char *>(pkg.data()), pkg.size());
    if (rc != 0) {
        if (error) {
            *error = QStringLiteral("tngInitCore failed: %1").arg(rc);
        }
        _clearSymbols();
        _lib.unload();
        return false;
    }

    if (!config.keystorePath.isEmpty()) {
        if (!_setKeystorePath) {
            if (error) {
                *error = QStringLiteral("tngSetKeystorePath not available in dll");
            }
            _shutdown();
            return false;
        }
        QByteArray pathBytes = QDir::toNativeSeparators(config.keystorePath).toLocal8Bit();
        const int ksRc = _setKeystorePath(pathBytes.data(), pathBytes.size() + 1);
        if (ksRc != 0) {
            if (error) {
                *error = QStringLiteral("tngSetKeystorePath failed: %1 path=%2")
                             .arg(ksRc)
                             .arg(config.keystorePath);
            }
            _shutdown();
            return false;
        }
    }

    _identity = identity;
    _users = 1;
    return true;
}

void TngCoreRuntime::release()
{
    QMutexLocker locker(&_mutex);

    if (_users <= 0) {
        return;
    }
    if (--_users == 0) {
        _shutdown();
    }
}
