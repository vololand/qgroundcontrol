.pragma library
// 1. MAV_AUTOPILOT: 오토파일럿(펌웨어) 종류 정의
const MAV_AUTOPILOT_MAP = {
    0: "GENERIC",
    1: "RESERVED",
    2: "SLUGS",
    3: "ARDUPILOT",
    4: "OPENPILOT",
    12: "PX4",
    13: "SMACCM",
    18: "ASLUAV"
};

// 2. MAV_TYPE: 기체 외형
const MAV_TYPE_MAP = {
    0: { name: "GENERIC", icon: "🛸" },
    1: { name: "FIXED_WING", icon: "✈️" },
    2: { name: "QUADROTOR", icon: "🚁" },
    10: { name: "GROUND_ROVER", icon: "🚗" },
    11: { name: "SURFACE_BOAT", icon: "🚤" },
    12: { name: "SUBMARINE", icon: "🤿" },
    29: { name: "VTOL", icon: "🛫" }
};

// 3. MAV_STATE: 시스템 상태
const MAV_STATE_MAP = {
    0: { label: "초기화", color: "#FFA500", icon: "⚠️", category: "CHECK" },   // 주황: 점검필요
    1: { label: "부팅", color: "#FFA500", icon: "⚠️", category: "CHECK" },     // 주황: 점검필요
    2: { label: "교정", color: "#FFA500", icon: "⚠️", category: "CHECK" },     // 주황: 점검필요
    3: { label: "대기", color: "#2ECC71", icon: "→", category: "READY" },    // 초록: 비행가능
    4: { label: "활성", color: "#2ECC71", icon: "→", category: "READY" },    // 초록: 비행가능
    5: { label: "위험", color: "#E74C3C", icon: "!", category: "ERROR" },    // 빨간: 비행안됨
    6: { label: "긴급", color: "#E74C3C", icon: "!", category: "ERROR" },    // 빨간: 비행안됨
    8: { label: "종료", color: "#E74C3C", icon: "!", category: "ERROR" }     // 빨간: 비행안됨
};

/** --- 데이터 추출 함수 --- **/

// 펌웨어 이름 반환
function getAutopilotName(autopilot) {
    return MAV_AUTOPILOT_MAP[autopilot] || "UNKNOWN";
}

// MAVLink 버전 반환 (단순 정수 값 출력)
function getMavVersion(version) {
    return "v" + version;
}

// 기존 함수 유지
function getIcon(type) { return (MAV_TYPE_MAP[type] && MAV_TYPE_MAP[type].icon) || "🛸"; }
function getStateLabel(state) { return (MAV_STATE_MAP[state] && MAV_STATE_MAP[state].label) || "알 수 없음"; }
function getStateColor(state) { return (MAV_STATE_MAP[state] && MAV_STATE_MAP[state].color) || "#000000"; }
function getStateData(state) { return MAV_STATE_MAP[state] || { label: "알수없음", color: "#808080", icon: "?" };}