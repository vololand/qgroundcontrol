#include "DroneModel.h"
#include <QDebug>
#include<qhash.h>

// 1. 행의 개수 반환 (기존 유지)
int DroneModel::rowCount(const QModelIndex& parent) const
{
    if (parent.isValid())
        return 0;
    return m_drones.count();
}

// 2. QML에서 데이터 요청 시 처리 (기존 유지)
QVariant DroneModel::data(const QModelIndex& index, int role) const
{
    if (!index.isValid() || index.row() >= m_drones.count())
        return QVariant();

    const DroneItem& item = m_drones[index.row()];

    switch (role) {
    case DepthRole:       return item.depth;
    case NodeTypeRole:    return item.nodeType;
    case GroupNameRole:   return item.groupName;
    case DeviceNameRole:  return item.deviceName;
    case StatusRole:      return item.status;
    case IsArmedRole:     return item.isArmed;
    case SystemStateRole: return item.systemState;
    case FlightModeRole:  return item.flightmode;
    case FlightTypeRole:  return item.flighttype;
    case HasErrorRole:    return item.hasError;
    case IsExpandedRole:  return item.isExpanded;
    case IsVisibleRole:   return item.isVisible;
    default:
        return QVariant();
    }
}

// 3. QML에서 사용할 프로퍼티 이름 매핑 (기존 유지)
QHash<int, QByteArray> DroneModel::roleNames() const
{
    QHash<int, QByteArray> roles;
    roles[DepthRole] = "depth";
    roles[NodeTypeRole] = "nodeType";
    roles[GroupNameRole] = "groupName";
    roles[DeviceNameRole] = "deviceName";
    roles[StatusRole] = "status";
    roles[IsArmedRole] = "isArmed";
    roles[SystemStateRole] = "systemState";
    roles[FlightModeRole] = "flightmode";
    roles[FlightTypeRole] = "flighttype";
    roles[HasErrorRole] = "hasError";
    roles[IsExpandedRole] = "isExpanded";
    roles[IsVisibleRole] = "isVisible";
    return roles;
}

// 4. [추가] TCP 테스트용 데이터 세팅 함수 구현
void DroneModel::setRecentData(const QString& data)
{
    if (m_recentData != data) {
        m_recentData = data;
        emit recentDataChanged();
    }
}

// 5. [추가] 모델 초기화 함수 구현 (LNK2019 해결)
void DroneModel::clearModel()
{
    beginResetModel();
    m_drones.clear();
    endResetModel();
}

// 6. [추가] 새 드론 아이템 추가 함수 구현 (LNK2019 해결)
void DroneModel::appendDrone(const DroneItem& item)
{
    //beginInsertRows(QModelIndex(), m_drones.size(), m_drones.size());
    //m_drones.append(item);
    //endInsertRows();
    const int row = m_drones.size();
    beginInsertRows(QModelIndex(), row, row);
    m_drones.append(item);
    endInsertRows();
}

// 7. [추가] 특정 드론 상태 업데이트 함수 구현 (LNK2019 해결)
void DroneModel::updateDrone(const QString& name, const QJsonObject& obj)
{
    for (int i = 0; i < m_drones.size(); ++i) {

        // device 노드만 업데이트 (계층 노드 보호)
        if (m_drones[i].nodeType != "device")
            continue;

        if (m_drones[i].deviceName == name) {
            if (obj.contains("status"))     m_drones[i].status = obj["status"].toString();
            if (obj.contains("systemState")) {
                m_drones[i].systemState = obj["systemState"].toInt();
            }
            if (obj.contains("isArmed"))    m_drones[i].isArmed = obj["isArmed"].toBool();
            if (obj.contains("flightmode")) m_drones[i].flightmode = obj["flightmode"].toString();

            // 너의 하트비트 스키마 반영
            if (obj.contains("flighttype")) m_drones[i].flighttype = obj["flighttype"].toString();
            if (obj.contains("hasError"))   m_drones[i].hasError = obj["hasError"].toBool();

            QModelIndex idx = index(i);
            emit dataChanged(idx, idx);
            break;
        }
    }
}


void DroneModel::setDeviceStatus(const QString& name, const QString& status)
{
    for (int i = 0; i < m_drones.size(); ++i) {
        if (m_drones[i].nodeType == "device" && m_drones[i].deviceName == name) {
            if (m_drones[i].status != status) {
                m_drones[i].status = status;
                QModelIndex idx = index(i);
                emit dataChanged(idx, idx, { StatusRole }); // status만 변경 알림
            }
            break;
        }
    }
}

// DroneModel.cpp 파일 하단에 추가

bool DroneModel::setData(const QModelIndex& index, const QVariant& value, int role)
{
    // 1. 인덱스 유효성 검사
    if (!index.isValid() || index.row() >= m_drones.count())
        return false;

    DroneItem& item = m_drones[index.row()];
    bool changed = false;

    // 2. 역할(Role)에 따른 데이터 수정
    switch (role) {
    case IsExpandedRole:
        if (item.isExpanded != value.toBool()) {
            item.isExpanded = value.toBool();
            changed = true;
        }
        break;
    case IsVisibleRole:
        if (item.isVisible != value.toBool()) {
            item.isVisible = value.toBool();
            changed = true;
        }
        break;
        // 필요한 경우 다른 Role(StatusRole 등)도 여기에 추가 가능
    }

    // 3. 데이터가 변경되었다면 QML에 신호를 보냄
    if (changed) {
        emit dataChanged(index, index, { role });
        return true;
    }

    return false;
}

void DroneModel::toggleSection(int index, const QString& searchText) {
    QString text = searchText.trimmed().toLower();

    // [Case 1] 사용자가 특정 항목을 클릭하여 접거나 펼칠 때 (index >= 0)
    if (index >= 0 && index < m_drones.count()) {
        // 1. 클릭된 부모의 확장 상태 반환
        m_drones[index].isExpanded = !m_drones[index].isExpanded;
        QModelIndex pIdx = this->index(index);
        emit dataChanged(pIdx, pIdx, { IsExpandedRole });

        // 2. 검색어가 없는 경우에만 즉시 하위 가시성 제어 (검색어 있을 땐 Case 2에서 처리)
        if (text.isEmpty()) {
            int startDepth = m_drones[index].depth;
            bool parentExpanded = m_drones[index].isExpanded;

            for (int i = index + 1; i < m_drones.count(); ++i) {
                if (m_drones[i].depth > startDepth) {
                    bool shouldBeVisible = false;
                    if (parentExpanded) {
                        // 부모 체인 검사 (히스토리 유지)
                        shouldBeVisible = true;
                        int currentChildDepth = m_drones[i].depth;
                        for (int j = i - 1; j >= index; --j) {
                            if (m_drones[j].depth < currentChildDepth) {
                                if (!m_drones[j].isExpanded) {
                                    shouldBeVisible = false;
                                    break;
                                }
                                currentChildDepth = m_drones[j].depth;
                            }
                        }
                    }

                    if (m_drones[i].isVisible != shouldBeVisible) {
                        m_drones[i].isVisible = shouldBeVisible;
                        QModelIndex childIdx = this->index(i);
                        emit dataChanged(childIdx, childIdx, { IsVisibleRole });
                    }
                }
                else break; // 계층 벗어남
            }
            return; // 클릭 처리는 여기서 종료
        }
    }

    // [Case 2] 검색어가 입력되었거나, 검색 상태에서 접기/펴기를 눌렀을 때 (전체 갱신)
    for (int i = 0; i < m_drones.count(); ++i) {
        bool finalVisible = true;

        // A. 검색 필터 적용
        if (!text.isEmpty()) {
            if (m_drones[i].nodeType == "device") {
                finalVisible = m_drones[i].deviceName.toLower().contains(text);
            }
            else {
                finalVisible = false;
                for (int j = i + 1; j < m_drones.count(); ++j) {
                    if (m_drones[j].depth <= m_drones[i].depth) break;
                    if (m_drones[j].nodeType == "device" && m_drones[j].deviceName.toLower().contains(text)) {
                        finalVisible = true;
                        break;
                    }
                }
            }
        }

        // B. 계층 구조 적용 (상위 부모 중 하나라도 닫혀있으면 숨김)
        if (finalVisible) {
            int currentDepth = m_drones[i].depth;
            for (int k = i - 1; k >= 0; --k) {
                if (m_drones[k].depth < currentDepth) {
                    if (!m_drones[k].isExpanded) {
                        finalVisible = false;
                        break;
                    }
                    currentDepth = m_drones[k].depth;
                }
            }
        }

        if (m_drones[i].isVisible != finalVisible) {
            m_drones[i].isVisible = finalVisible;
            QModelIndex idx = this->index(i);
            emit dataChanged(idx, idx, { IsVisibleRole });
        }
    }
}

// 1. get 함수 수정 (m_items -> m_drones 로 변경)
QVariantMap DroneModel::get(int row) const {
    if (row < 0 || row >= m_drones.count()) // 사용자님의 실제 변수명 m_drones 사용
        return QVariantMap();

    const auto& item = m_drones.at(row);
    QVariantMap map;

    map["depth"] = item.depth;
    map["nodeType"] = item.nodeType;
    map["isExpanded"] = item.isExpanded;
    map["isVisible"] = item.isVisible;
    map["deviceName"] = item.deviceName;
    map["groupName"] = item.groupName;
    map["flightmode"] = item.flightmode;
    map["status"] = item.status;
    map["systemState"] = item.systemState;

    return map;
}

// 2. [추가] QML에서 setProperty()를 직접 호출하기 위한 보조 함수
// QML의 m.setProperty(index, "isVisible", true) 호출 시 동작하도록 함
Q_INVOKABLE void DroneModel::setProperty(int row, const QString& roleName, const QVariant& value) {
    if (row < 0 || row >= m_drones.count()) return;

    int role = -1;

    // QHashIterator 대신 QHash의 모든 키를 가져와서 반복문을 돌리는 방식
    // 이 방식은 별도의 Iterator 헤더가 없어도 작동합니다.
    QHash<int, QByteArray> roles = roleNames();
    QList<int> keys = roles.keys();

    for (int key : keys) {
        if (roles.value(key) == roleName.toUtf8()) {
            role = key;
            break;
        }
    }

    if (role != -1) {
        // 기존에 정의된 setData를 호출하여 데이터를 변경합니다.
        setData(index(row), value, role);
    }
}
