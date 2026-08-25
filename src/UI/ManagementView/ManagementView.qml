/****************************************************************************
 *
 * QGroundControl Open Source Ground Control Station
 *
 * Management view – left tree panel + right content loader
 *
 ****************************************************************************/

import QtQuick
import QtQuick.Controls

import QGroundControl
import QGroundControl.Palette
import QGroundControl.Controls
import QGroundControl.ScreenTools

Rectangle {
    id:     _root
    color:  qgcPal.window
    z:      QGroundControl.zOrderTopMost

    readonly property real _hMargin:        ScreenTools.defaultFontPixelWidth  / 2
    readonly property real _vMargin:        ScreenTools.defaultFontPixelHeight / 2
    // mainWindow.sidebarTargetWidth(= width * 0.20) 를 사용해 다른 뷰(Analyze, Setup)와 동일한 좌측 패널 너비 유지
    // mainWindow 참조 불가 시 폴백: ScreenTools.defaultFontPixelWidth * 36
    readonly property real _leftPanelWidth: (typeof mainWindow !== "undefined" && mainWindow !== null)
                                            ? mainWindow.sidebarTargetWidth
                                            : ScreenTools.defaultFontPixelWidth * 36

    // ── 페이지 열기 전에 저장되는 파라미터
    property string _addParentName:    ""
    property string _editGroupName:   ""
    property string _editParentName:  ""
    property string _editNodeType:    ""
    property string _detailGroupName: ""
    property string _detailParentName:""
    property string _detailNodeType:  ""
    property var    _parentGroupModel: []   // org·group — 그룹 등록/수정 콤보
    property var    _userGroupModel:   []   // org·group·subGroup — 사용자 등록/수정 콤보
    property string _editUserName:     ""   // 수정 대상 사용자명
    property string _detailUserName:   ""   // 상세 보기 대상 사용자명
    property string _assetAddGroupName: ""  // 자산 등록 시 pre-select 그룹명
    property string _editAssetName:     ""  // 자산 수정 대상 자산명
    property string _detailAssetName:   ""  // 자산 상세 보기 대상 자산명

    QGCPalette { id: qgcPal; colorGroupEnabled: true }

    DeadMouseArea { anchors.fill: parent }

    // ── Left panel
    Item {
        id:             _leftArea
        anchors.left:   parent.left
        anchors.top:    parent.top
        anchors.bottom: parent.bottom
        width:          _leftPanelWidth

        Loader {
            id:           _leftPanelLoader
            anchors.fill: parent
            source:       "ManagementLeftPanel.qml"

            onLoaded: {
                // 그룹 추가: 우클릭 대상이 기본 상위 그룹 (버튼 클릭 시 빈 문자열)
                item.requestGroupAdd.connect(function(parentName) {
                    _root._addParentName    = parentName
                    _root._parentGroupModel = item.parentGroupNames
                    _groupAddLoader.source  = "GroupAddPage.qml"
                })

                // 그룹 수정: 선택된 그룹명 + 상위 그룹명(1뎁스 높은 그룹) + 노드 타입
                item.requestGroupEdit.connect(function(groupName, parentName, nodeType) {
                    _root._editGroupName    = groupName
                    _root._editParentName   = parentName
                    _root._editNodeType     = nodeType
                    _root._parentGroupModel = item.parentGroupNames
                    _groupEditLoader.source = "GroupEditPage.qml"
                })

                // 그룹 상세: group·subGroup 노드 우클릭
                item.requestGroupDetail.connect(function(groupName, parentName, nodeType) {
                    _root._detailGroupName  = groupName
                    _root._detailParentName = parentName
                    _root._detailNodeType   = nodeType
                    _groupDetailLoader.source = "GroupDetailPage.qml"
                })

                // 그룹 삭제: group·subGroup 노드 우클릭 → 삭제 항목
                // TODO: 서버 그룹삭제 API 호출 후 트리 갱신
                item.requestGroupDelete.connect(function(groupName) {
                    console.log("[그룹삭제] 대상:", groupName, "— 서버 연동 후 처리 예정")
                })

                // 그룹 업데이트: group·subGroup → 해당 그룹 데이터 갱신
                // TODO: 서버에서 해당 그룹의 최신 데이터 수신 후 트리 갱신
                item.requestGroupRefresh.connect(function(groupName) {
                    console.log("[그룹업데이트] 대상:", groupName, "— 서버 연동 후 처리 예정")
                })

                // 트리 전체 업데이트: org 우클릭 → 전체 트리 데이터 갱신
                // TODO: 서버에서 전체 트리 데이터 재수신 후 트리 갱신
                item.requestTreeRefresh.connect(function() {
                    console.log("[트리전체업데이트] — 서버 연동 후 처리 예정")
                })

                // 사용자 등록: userMgmt 우클릭 (전체 그룹 목록 전달)
                item.requestUserAdd.connect(function() {
                    _root._userGroupModel = item.allGroupNames
                    _userAddLoader.source = "UserAddPage.qml"
                })

                // 사용자 수정: user 노드 우클릭
                item.requestUserEdit.connect(function(userName) {
                    _root._editUserName   = userName
                    _root._userGroupModel = item.allGroupNames
                    _userEditLoader.source = "UserEditPage.qml"
                })

                // 사용자 삭제: user 노드 우클릭 → 삭제 항목
                // TODO: 서버 사용자삭제 API 호출 후 트리 갱신
                item.requestUserDelete.connect(function(userName) {
                    console.log("[사용자삭제] 대상:", userName, "— 서버 연동 후 처리 예정")
                })

                // 사용자 상세: user 노드 더블클릭
                item.requestUserDetail.connect(function(userName) {
                    _root._detailUserName   = userName
                    _userDetailLoader.source = "UserDetailPage.qml"
                })

                // 사용자 관리 리스트 조회: 좌측 사용자 탭 새로고침
                // TODO: 서버 사용자관리 리스트 조회 API 호출 후 좌측 사용자 트리 갱신
                item.requestUserManagementListRefresh.connect(function() {
                    console.log("[사용자관리리스트조회] — 서버 연동 후 처리 예정")
                })

                // 자산 등록: group·subGroup 노드 우클릭
                item.requestAssetAdd.connect(function(groupName) {
                    _root._assetAddGroupName = groupName
                    _root._userGroupModel    = item.allGroupNames
                    _assetAddLoader.source   = "AssetAddPage.qml"
                })

                // 자산 수정: asset 노드 우클릭
                item.requestAssetEdit.connect(function(assetName) {
                    _root._editAssetName     = assetName
                    _root._userGroupModel    = item.allGroupNames
                    _assetEditLoader.source  = "AssetEditPage.qml"
                })

                // 자산 삭제: asset 노드 우클릭 → 삭제 항목
                // TODO: 서버 자산삭제 API 호출 후 트리 갱신
                item.requestAssetDelete.connect(function(assetName) {
                    console.log("[자산삭제] 대상:", assetName, "— 서버 연동 후 처리 예정")
                })

                // 자산 관리 리스트 조회: 좌측 자산 탭 새로고침
                // TODO: 서버 자산관리 리스트 조회 API 호출 후 좌측 자산 트리 갱신
                item.requestAssetManagementListRefresh.connect(function() {
                    console.log("[자산관리리스트조회] — 서버 연동 후 처리 예정")
                })

                // 자산 상세: asset 노드 더블클릭
                item.requestAssetDetail.connect(function(assetName) {
                    _root._detailAssetName    = assetName
                    _assetDetailLoader.source = "AssetDetailPage.qml"
                })
            }
        }

        // Vertical divider
        Rectangle {
            anchors.right:          parent.right
            anchors.top:            parent.top
            anchors.bottom:         parent.bottom
            anchors.topMargin:      _vMargin
            anchors.bottomMargin:   _vMargin
            width:                  1
            color:                  qgcPal.windowShade
        }
    }

    // ── Right content
    Loader {
        id:                     _rightPanelLoader
        anchors.left:           _leftArea.right
        anchors.right:          parent.right
        anchors.top:            parent.top
        anchors.bottom:         parent.bottom
        anchors.leftMargin:     _hMargin
        anchors.rightMargin:    _hMargin
        anchors.topMargin:      _vMargin
        anchors.bottomMargin:   _vMargin
        source:                 "ManagementListPage.qml"

        onLoaded: {
            item.requestUserAdd.connect(function() {
                _root._userGroupModel = _leftPanelLoader.item
                                        ? _leftPanelLoader.item.allGroupNames : []
                _userAddLoader.source = "UserAddPage.qml"
            })

            item.requestUserEdit.connect(function(userName) {
                _root._editUserName   = userName
                _root._userGroupModel = _leftPanelLoader.item
                                        ? _leftPanelLoader.item.allGroupNames : []
                _userEditLoader.source = "UserEditPage.qml"
            })

            item.requestAssetAdd.connect(function() {
                _root._assetAddGroupName = ""
                _root._userGroupModel    = _leftPanelLoader.item
                                           ? _leftPanelLoader.item.allGroupNames : []
                _assetAddLoader.source   = "AssetAddPage.qml"
            })

            item.requestAssetEdit.connect(function(assetName) {
                _root._editAssetName    = assetName
                _root._userGroupModel   = _leftPanelLoader.item
                                          ? _leftPanelLoader.item.allGroupNames : []
                _assetEditLoader.source = "AssetEditPage.qml"
            })
        }
    }

    // ── GroupAddPage 오버레이
    Loader {
        id:           _groupAddLoader
        anchors.fill: parent

        onLoaded: {
            item.parentGroupModel = _root._parentGroupModel  // 콤보 모델 먼저
            item.presetParentName = _root._addParentName     // 그 후 pre-select
            item.accepted.connect(function()  { _groupAddLoader.source = "" })
            item.cancelled.connect(function() { _groupAddLoader.source = "" })
        }
    }

    // ── GroupEditPage 오버레이
    Loader {
        id:           _groupEditLoader
        anchors.fill: parent

        onLoaded: {
            item.parentGroupModel = _root._parentGroupModel  // 콤보 모델 먼저
            item.initGroupName    = _root._editGroupName
            item.initParentName   = _root._editParentName    // 그 후 pre-select
            item.initNodeType     = _root._editNodeType
            item.accepted.connect(function()  { _groupEditLoader.source = "" })
            item.cancelled.connect(function() { _groupEditLoader.source = "" })
        }
    }

    // ── GroupDetailPage 오버레이
    Loader {
        id:           _groupDetailLoader
        anchors.fill: parent

        onLoaded: {
            // TODO: 서버 GroupDetailRes 조회 후 실제 parent group name/description 반영
            item.initParentName  = _root._detailParentName
            item.initGroupName   = _root._detailGroupName
            item.initDescription = ""
            item.closed.connect(function() { _groupDetailLoader.source = "" })
        }
    }

    // ── UserAddPage 오버레이
    Loader {
        id:           _userAddLoader
        anchors.fill: parent

        onLoaded: {
            item.groupModel = _root._userGroupModel
            item.accepted.connect(function()  { _userAddLoader.source = "" })
            item.cancelled.connect(function() { _userAddLoader.source = "" })
        }
    }

    // ── UserEditPage 오버레이
    Loader {
        id:           _userEditLoader
        anchors.fill: parent

        onLoaded: {
            item.groupModel    = _root._userGroupModel
            item.initUserName  = _root._editUserName
            item.accepted.connect(function()  { _userEditLoader.source = "" })
            item.cancelled.connect(function() { _userEditLoader.source = "" })
        }
    }

    // ── UserDetailPage 오버레이
    Loader {
        id:           _userDetailLoader
        anchors.fill: parent

        onLoaded: {
            item.initUserName = _root._detailUserName
            item.closed.connect(function() { _userDetailLoader.source = "" })
        }
    }

    // ── AssetAddPage 오버레이
    Loader {
        id:           _assetAddLoader
        anchors.fill: parent

        onLoaded: {
            item.groupModel      = _root._userGroupModel
            item.presetGroupName = _root._assetAddGroupName
            item.accepted.connect(function()  { _assetAddLoader.source = "" })
            item.cancelled.connect(function() { _assetAddLoader.source = "" })
        }
    }

    // ── AssetEditPage 오버레이
    Loader {
        id:           _assetEditLoader
        anchors.fill: parent

        onLoaded: {
            item.groupModel    = _root._userGroupModel
            item.initAssetName = _root._editAssetName
            item.accepted.connect(function()  { _assetEditLoader.source = "" })
            item.cancelled.connect(function() { _assetEditLoader.source = "" })
        }
    }

    // ── AssetDetailPage 오버레이
    Loader {
        id:           _assetDetailLoader
        anchors.fill: parent

        onLoaded: {
            item.initAssetName = _root._detailAssetName
            item.closed.connect(function() { _assetDetailLoader.source = "" })
        }
    }
}
