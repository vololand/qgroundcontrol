#ifndef DRONEMODEL_H
#define DRONEMODEL_H

#include <QAbstractListModel>
#include <QVector>
#include <QString>
#include <QHash>
#include <QByteArray>
#include <QJsonObject>

// 상태 정보 데이터 구조체
struct DroneItem {
    int depth;
    QString nodeType;
    QString groupName;
    QString deviceName;
    QString status;
    bool isArmed;
    int battery;
    QString flightmode;
    QString flighttype;
    bool hasError;
    bool isExpanded;
    bool isVisible;
    int systemState;
};

class DroneModel : public QAbstractListModel
{
    Q_OBJECT
        // QML 프로퍼티 등록
        Q_PROPERTY(QString recentData READ recentData NOTIFY recentDataChanged)

public:
    explicit DroneModel(QObject* parent = nullptr) : QAbstractListModel(parent) {}

    Q_INVOKABLE QVariantMap get(int row) const;
    Q_INVOKABLE void setProperty(int row, const QString& roleName, const QVariant& value);
    // toggleSection도 QML에서 호출하려면 Q_INVOKABLE이 붙어있어야 합니다.
    Q_INVOKABLE void toggleSection(int index, const QString& searchText);

    // QML에서 데이터를 식별할 때 사용할 역할 번호
    enum DroneRoles {
        DepthRole = Qt::UserRole + 1,
        NodeTypeRole,
        GroupNameRole,
        DeviceNameRole,
        StatusRole,
        IsArmedRole,
        SystemStateRole,
        FlightModeRole,
        FlightTypeRole,
        HasErrorRole,
        IsExpandedRole,
        IsVisibleRole
    };

    // TCP 테스트 및 데이터 업데이트를 위한 함수 선언
    QString recentData() const { return m_recentData; }
    void setRecentData(const QString& data);

    // 드론 리스트 관리를 위한 함수 선언
    void clearModel();
    void appendDrone(const DroneItem& item);
    void updateDrone(const QString& name, const QJsonObject& obj);
    void setDeviceStatus(const QString& name, const QString& status); // status만 변경(나머지 값 유지) - OFFLINE 처리 등에 사용

    // QML에서 model.isExpanded = true 와 같이 값을 직접 수정할 때 호출되는 함수입니다.
    bool setData(const QModelIndex& index, const QVariant& value, int role = Qt::EditRole) override;

    // QAbstractListModel 필수 구현 함수
    int rowCount(const QModelIndex& parent = QModelIndex()) const override;
    QVariant data(const QModelIndex& index, int role = Qt::DisplayRole) const override;

protected:
    // 역할 번호와 QML 변수명을 매핑하는 함수
    QHash<int, QByteArray> roleNames() const override;

signals:
    // 프로퍼티 변경 알림 신호
    void recentDataChanged();

private:
    // 실제 데이터가 저장되는 변수들
    QString m_recentData = "Waiting for TCP...";
    QVector<DroneItem> m_drones;
};

#endif // DRONEMODEL_H