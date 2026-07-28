# キソウ — 현재 상세설계서

## 앱 개요

キソウ는 날씨와 개인 체감 데이터를 기반으로, 사용자가 춥게 느낄지 덥게 느낄지 예측하고 개인별 복장 태그를 추천하는 앱입니다. 일본 출시를 목표로 합니다.

패션 코디 앱이 아닙니다. 색상, 브랜드, 스타일, 유행 코디를 추천하지 않습니다.
목표는 "오늘 무엇을 어떻게 코디할까?"가 아니라, **"오늘 어느 정도 두께로 입어야 할까?"**를 알려주는 것입니다.

---

## 기술 스택

| 영역 | 기술 |
|------|------|
| 메인 앱 | Flutter |
| iOS 위젯 | SwiftUI + WidgetKit (MVP 이후) |
| Android 위젯 | Kotlin + Glance 또는 AppWidget (MVP 이후) |
| API 서버 | FastAPI |
| DB | PostgreSQL |
| 추천 로직 | Python 기반 |
| 푸시 알림 | Firebase Cloud Messaging (MVP 이후) |
| 크래시 분석 | Firebase Crashlytics (미도입) |
| 행동 분석 | Firebase Analytics (미도입) |
| API 키 관리 | 서버 환경변수 또는 Secret Manager |
| 날씨 API | Open-Meteo JMA (MVP) / 여름 WBGT: 환경성 API |

---

## 1. MVP 기능 범위

### 포함

**핵심 기능**

- 위치 기반 날씨 데이터 조회 (Open-Meteo JMA + 여름철 WBGT)
- 어제 / 2일 전 / 오늘 날씨 비교 표시
- 규칙 기반 복장 태그 조합 추천 (3개 조합 제시)
- 외출~귀가 시간대 기준으로 날씨 종합 후 1세트 추천
- 사용자별 보정값으로 추천 개인화
- 피드백 수집: 체감(추웠어요 / 딱 좋았어요 / 더웠어요) + 실제 착용 복장
- 피드백 기반 보정값 실시간 업데이트

**계정**

- 첫 실행 시 서버가 발급한 `device_secret`으로 익명 계정을 자동 생성
- `device_secret`, 액세스 토큰, 리프레시 토큰은 보안 저장소에 보관
- 메뉴에서 익명 계정을 Apple / Google 계정에 연동하여 데이터 유지 및 기기 변경 지원
- 액세스 토큰 만료 시 단일 사용 리프레시 토큰을 회전해 세션 갱신

**온보딩**

- 위치정보 사용 허가
- 성별 입력
- 추위/더위 성향 입력
- 별명 입력

**위치**

- GPS 자동 + 수동 검색 (일본 시구정촌 선택)

**설정**

- 위치 변경
- 추위/더위 성향 재설정 (보정값 초기화 + 확인 팝업)
- 별명, 성별 변경
- Apple / Google 계정 연동 상태 확인
- 체감 데이터 초기화
- 라이트 / 다크 / 시스템 테마 선택
- 개인정보처리방침 열기
- 로그아웃
- 계정 삭제

### 제외

- 위젯 (iOS/Android 모두)
- 알림 (푸시 알림)
- 로지스틱 회귀 모델 (데이터 축적 후 도입)
- 과거 피드백 히스토리 열람 화면
- 소셜/공유 기능
- 옷장 등록, 코디 저장
- 색상/브랜드/스타일 추천
- 우산/소지품 추천
- 다국어 지원 (일본어 단일)
- 유료 기능, 구독, 광고

---

## 2. 추천 로직 상세

### 입력값

- **날씨 데이터:** 외출~귀가 시간대의 시간별 기온, 체감온도, 습도, 풍속, 강수확률 (여름철 WBGT 추가)
- **사용자 프로필:** 성별, 추위/더위 성향
- **사용자 보정값:** 피드백 누적으로 조정된 개인 체감 오프셋
- ※ 별명은 UI 표시용이며 로직 입력이 아님

### 출력값

- 복장 태그 조합 3개 (1번 가장 추천 / 2번 약간 따뜻한 방향 / 3번 약간 가벼운 방향)
- 각 조합은 상의 + 하의 + 겉옷(선택)

### 체감 점수

기본 체감 점수 = 체감온도 기반값 + 습도 보정 + 풍속 보정 + WBGT 보정(여름)

시간대 내 최저/최고 체감 점수를 둘 다 사용합니다.

최종 체감 점수 = 기본 체감 점수 - 사용자 보정값

양수 보정값은 사용자가 같은 날씨를 더 춥게 느낀다는 뜻이므로 최종 점수를
낮춰 더 따뜻한 옷을 추천하고, 음수 보정값은 최종 점수를 높여 더 가벼운 옷을
추천합니다.

### 낮/저녁 기온차 처리

최고 체감 점수 기준으로 상의를 정하고, 최저가 낮으면 겉옷을 추가합니다.

### 강수확률 반영

강수확률은 기온/습도와 조합해서 판단합니다.

- 비 + 기온 낮음: 체감 점수를 추가로 하향 보정 (체감상 더 춥기 때문)
- 비 + 기온 높음 + 습도 높음: 체감 점수 하향 보정 없음 또는 미미
- 하의 제한: 강수확률이 높으면 반바지/숏팬츠를 후보에서 제외하되, 고온+다습 조건에서는 제외하지 않음

구체적인 임계값은 구현 시 튜닝합니다.

### 체감 점수 → 복장 매핑

| 체감 점수 구간 | 상의 후보 | 겉옷 후보 |
|---|---|---|
| 매우 더움 (30+) | SLEEVELESS, SHORT_SLEEVE | 없음 |
| 더움 (25~30) | SHORT_SLEEVE | 없음 |
| 약간 더움 (20~25) | SHORT_SLEEVE, THIN_LONG | LIGHT_OUTER |
| 보통 (15~20) | THIN_LONG, LONG_SLEEVE | LIGHT_OUTER, CARDIGAN |
| 약간 추움 (10~15) | LONG_SLEEVE, THICK_LONG | JACKET, CARDIGAN |
| 추움 (5~10) | THICK_LONG, KNIT_SWEAT | COAT, JACKET |
| 매우 추움 (5 미만) | KNIT_SWEAT | PADDING, COAT |

하의는 성별 + 기온에 따라 결정합니다. 더운 구간에서는 반바지/숏팬츠가 후보에 추가, 추운 구간에서는 긴바지 고정.

### 3개 조합 생성

- 1번: 최저~최고 체감 점수를 종합했을 때 가장 균형 잡힌 조합
- 2번: 1번보다 약간 따뜻한 방향
- 3번: 1번보다 약간 가벼운 방향

### 복장 태그 코드 체계

**상의 (top)**

| 코드 | 일본어 표시명 |
|---|---|
| SLEEVELESS | タンクトップ |
| SHORT_SLEEVE | 半袖 |
| THIN_LONG | 薄手の長袖 |
| LONG_SLEEVE | 長袖 |
| THICK_LONG | 厚手の長袖 |
| KNIT_SWEAT | ニット・スウェット |

**하의 (bottom)**

| 코드 | 일본어 표시명 |
|---|---|
| LONG_PANTS | 長ズボン |
| HALF_PANTS | ハーフパンツ |
| SHORT_PANTS | ショートパンツ |
| SKIRT | スカート |

**겉옷 (outer)**

| 코드 | 일본어 표시명 |
|---|---|
| LIGHT_OUTER | 薄手の羽織り |
| CARDIGAN | カーディガン |
| JACKET | ジャケット |
| COAT | コート |
| PADDING | ダウン |
| null | なし |

서버는 코드로 반환하고, 앱(Flutter)에서 코드 → 표시명 + 아이콘 매핑을 처리합니다.

---

## 3. 온보딩 설계

앱 첫 실행 시 익명 계정을 자동 발급한 뒤 1회 진행합니다. 네 단계 모두 필수이며, 위치 선택 완료 시 프로필을 한 번에 저장합니다.

**Step 1: 별명 입력**

- 2~10자
- 앱 내에서 "○○さん、今日は…" 형태로 사용

**Step 2: 성별 선택**

- 남성 / 여성 / 선택 안 함
- "선택 안 함"인 경우 하의 후보 전체 포함

**Step 3: 추위/더위 성향**

- 추위: 잘 탐 / 보통 / 안 탐
- 더위: 잘 탐 / 보통 / 안 탐
- 이 답변으로 초기 보정값 설정

**Step 4: 위치 설정**

- 앱 자체 설명 화면 → 시스템 권한 요청
- 허가 시: GPS 기반으로 현재 위치 자동 설정
- 거부하거나 조회에 실패하면 일본 주요 도시 목록에서 수동 선택
- 위치 선택 후 완료 팝업 표시 → 홈 화면으로 이동

외출/귀가 시간 입력은 온보딩에서 제거되었습니다. 서버의 09:00~18:00 기본값은 추천 계산의 기본 시간 범위로 유지하고, 실제 외출 시간대는 피드백마다 별도로 기록합니다.

### 초기 보정값 매핑

| 추위 | 더위 | 초기 보정값 | 의미 |
|---|---|---|---|
| 잘 탐 | 안 탐 | +1.5 | 추위 민감, 따뜻하게 추천 |
| 잘 탐 | 보통 | +1.0 | 약간 따뜻하게 |
| 보통 | 보통 | 0 | 기본 |
| 안 탐 | 잘 탐 | -1.5 | 더위 민감, 가볍게 추천 |
| 안 탐 | 보통 | -1.0 | 약간 가볍게 |
| 잘 탐 | 잘 탐 | +0.5 | 둘 다 민감, 약간 따뜻한 쪽 우선 |
| 안 탐 | 안 탐 | -0.5 | 둘 다 둔감, 약간 가벼운 쪽 |
| 보통 | 잘 탐 | -1.0 | 더위 쪽 민감 |
| 보통 | 안 탐 | +1.0 | 추위 쪽으로 약간 보정 |

---

## 4. 피드백 학습 구조

### 피드백 수집 타이밍

- 홈 상단 액션 버튼에서 직접 입력
- 예보 탭의 피드백 안내 카드에서 입력
- 미입력 시: 보정값 변화 없음 (가벼운 유도만)

### 피드백 입력 (바텀시트)

- Step 1: 날짜(오늘~7일 전), 실제 외출 시간대(복수 선택), 착용 복장 선택
- Step 2: 체감 선택 (추웠어요 / 딱 좋았어요 / 더웠어요)
- 완료 → "반영했어요!" → 닫힘

사용자·날짜별 1회이며 같은 날짜는 수정할 수 있습니다.

### 피드백 저장 데이터

- 사용자 ID
- 날짜
- 피드백 값 (cold / perfect / hot)
- 해당 날의 추천 조합 스냅샷
- 실제 착용 복장 (actual_top, actual_bottom, actual_outer)
- 실제 외출 시간대 (time_slots, 선택)
- 해당 날의 날씨 데이터 스냅샷
- 적용 시점의 보정값
- 성별 등 프로필 데이터는 학습 시 사용자 테이블에서 조인

### 보정값 업데이트 규칙

| 조건 | 추웠어요 | 딱 좋았어요 | 더웠어요 |
|---|---|---|---|
| 추천대로 입음 | +0.3 | 변화 없음 | -0.3 |
| 추천과 다르게 입음 | +0.15 | 변화 없음 | -0.15 |

- 보정값 범위: -3 ~ +3
- 범위 도달 시 더 이상 변하지 않음
- 피드백 수정 시: 이전 보정을 되돌린 뒤 새 피드백 반영
- "딱 좋았어요": 저장하되 보정값 변화 없음

---

## 5. 데이터베이스 구조

### users (사용자)

| 컬럼 | 타입 | 설명 |
|---|---|---|
| id | UUID, PK | 사용자 고유 ID |
| auth_provider | VARCHAR | anonymous / apple / google |
| auth_uid | VARCHAR | 서버 발급 익명 비밀값 또는 인증 제공자의 고유 ID |
| nickname | VARCHAR(10) | 별명 |
| gender | VARCHAR | male / female / unspecified |
| cold_sensitivity | VARCHAR | high / normal / low |
| heat_sensitivity | VARCHAR | high / normal / low |
| offset_value | FLOAT | 현재 보정값 (기본 0, 범위 -3~+3) |
| departure_time | TIME | 외출 시간 (기본 09:00) |
| return_time | TIME | 귀가 시간 (기본 18:00) |
| latitude | FLOAT | 위치 위도 |
| longitude | FLOAT | 위치 경도 |
| region_name | VARCHAR | 지역명 (표시용) |
| created_at | TIMESTAMP | 가입일 |
| updated_at | TIMESTAMP | 최종 수정일 |

### feedbacks (피드백)

| 컬럼 | 타입 | 설명 |
|---|---|---|
| id | UUID, PK | 피드백 고유 ID |
| user_id | UUID, FK | 사용자 ID |
| date | DATE | 피드백 대상 날짜 |
| feedback_value | VARCHAR | cold / perfect / hot |
| recommendation | JSONB | 해당 날 추천 조합 스냅샷 |
| actual_top | VARCHAR | 실제 착용 상의 코드 |
| actual_bottom | VARCHAR | 실제 착용 하의 코드 |
| actual_outer | VARCHAR (nullable) | 실제 착용 겉옷 코드 |
| weather_snapshot | JSONB | 해당 날 날씨 데이터 스냅샷 |
| time_slots | JSONB (nullable) | 실제 외출 시간대 코드 목록 |
| offset_at_time | FLOAT | 피드백 시점의 보정값 |
| created_at | TIMESTAMP | 생성일 |
| updated_at | TIMESTAMP | 수정일 |

user_id + date에 UNIQUE 제약 (1일 1피드백 보장)

### refresh_tokens (리프레시 토큰)

| 컬럼 | 타입 | 설명 |
|---|---|---|
| id | UUID, PK | 토큰 레코드 ID |
| user_id | UUID, FK | 사용자 ID (삭제 시 연쇄 삭제) |
| token_hash | VARCHAR(64), UNIQUE | 원문 대신 저장하는 SHA-256 해시 |
| expires_at | TIMESTAMP | 만료 시각 |
| created_at | TIMESTAMP | 발급 시각 |
| revoked_at | TIMESTAMP (nullable) | 회전 또는 로그아웃으로 폐기된 시각 |

### weather_cache (날씨 캐시)

| 컬럼 | 타입 | 설명 |
|---|---|---|
| id | SERIAL, PK | 자동 증가 ID |
| latitude | FLOAT | 위도 (소수점 2자리 반올림) |
| longitude | FLOAT | 경도 (소수점 2자리 반올림) |
| date | DATE | 날짜 |
| hourly_data | JSONB | 시간별 날씨 데이터 전체 |
| fetched_at | TIMESTAMP | API 호출 시점 |

- 같은 좌표(소수점 2자리 반올림, 약 1km 단위) + 같은 날짜 → 캐시 반환
- 캐시 갱신 주기: 3시간
- 과거 날씨(어제/2일 전)는 한 번 저장 후 갱신 불필요

---

## 6. API 구조

### 인증

- 첫 실행은 `/auth/anonymous`로 익명 계정과 세션을 발급
- Apple/Google 직접 로그인 또는 현재 익명 계정의 `/auth/link` 연동 지원
- 액세스 토큰 기본 만료: 60분, 인증 API를 제외한 요청에 Bearer 토큰 포함
- 리프레시 토큰 기본 만료: 60일, 서버에는 SHA-256 해시만 저장
- `/auth/refresh`는 기존 토큰을 폐기하고 새 토큰 쌍을 발급하며, `/auth/logout`은 리프레시 토큰을 폐기

### 엔드포인트

| 메서드 | 경로 | 설명 |
|---|---|---|
| GET | /health | 컨테이너·가동 상태 확인 |
| POST | /auth/anonymous | 익명 계정 생성 또는 `device_secret`으로 복원 |
| POST | /auth/login | Apple/Google 토큰 검증 후 액세스·리프레시 토큰 발급 |
| POST | /auth/refresh | 리프레시 토큰 회전 및 세션 갱신 |
| POST | /auth/logout | 리프레시 토큰 폐기 |
| POST | /auth/link | 현재 계정을 Apple/Google 계정에 연동 |
| GET | /home | 추천 3개 조합 + 날씨 비교(오늘/어제/2일 전) 통합 응답 |
| GET | /users/me | 프로필 조회 |
| PUT | /users/me | 프로필 업데이트 |
| POST | /users/me/reset-data | 피드백 삭제 + 성향 기준 보정값 초기화 |
| DELETE | /users/me | 계정·피드백·리프레시 토큰 삭제 |
| POST | /feedback | 오늘~7일 전 피드백 제출/수정 + 보정값 업데이트 |
| GET | /feedback/today | 오늘 피드백 제출 여부 확인 |
| GET | /analysis | 체감 성향·피드백 분포·날짜순 이력 조회 |
| GET | /forecast/tomorrow | 내일 추천·오늘 비교·D+2~D+4 요약 |
| GET | /forecast/outlook | 미래 날짜·장소의 실예보 또는 과거 기후 추정 |

### 설계 원칙

- 추천 로직은 서버에서 실행, 앱은 결과만 표시
- 날씨 API 호출: 앱 → FastAPI → weather_cache 확인 → 캐시 없거나 3시간 초과 → Open-Meteo 호출 → 캐시 저장 → 응답
- 복장 태그는 코드로 반환, 앱에서 표시명/아이콘 변환

### 응답 예시

GET /home:

```json
{
  "date": "2026-04-27",
  "feeling": "PERFECT",
  "comfort_min": 14.8,
  "comfort_max": 21.2,
  "recommendations": [
    {
      "rank": 1,
      "top": "THIN_LONG",
      "bottom": "LONG_PANTS",
      "outer": "LIGHT_OUTER"
    },
    {
      "rank": 2,
      "top": "LONG_SLEEVE",
      "bottom": "LONG_PANTS",
      "outer": "CARDIGAN"
    },
    {
      "rank": 3,
      "top": "SHORT_SLEEVE",
      "bottom": "LONG_PANTS",
      "outer": "LIGHT_OUTER"
    }
  ],
  "weather_comparison": {
    "today": {
      "temp_high": 22,
      "temp_low": 14,
      "feels_like_high": 21,
      "feels_like_low": 13,
      "humidity_avg": 55,
      "wind_speed_avg": 3.2,
      "precipitation_chance_max": 20,
      "wbgt_max": null
    },
    "yesterday": {
      "temp_high": 19,
      "temp_low": 12,
      "feels_like_high": 18,
      "feels_like_low": 10,
      "humidity_avg": 60,
      "wind_speed_avg": 4.1,
      "precipitation_chance_max": 30,
      "wbgt_max": null
    },
    "two_days_ago": {
      "temp_high": 24,
      "temp_low": 16,
      "feels_like_high": 24,
      "feels_like_low": 15,
      "humidity_avg": 50,
      "wind_speed_avg": 2.6,
      "precipitation_chance_max": 10,
      "wbgt_max": null
    }
  }
}
```

---

## 7. 화면 구성

### 온보딩 (4단계)

상기 온보딩 설계 참조.

### 메인 화면 (홈)

- **상단:** "○○さん、今日の服装は" + 현재 위치/지역명
- **추천 영역:** 1번 추천 아이콘 크게, 2번 3번 아이콘 작게 세로 나열
- **날씨 비교 영역:** 오늘/어제/2일 전 기온 비교 (예: "어제보다 3도 낮아요")
- **피드백 액션:** 공통 상단 툴바 우측에서 입력/수정

### 예보 화면

- 내일의 날씨·추천과 오늘 대비 기온 표시
- D+2~D+4의 기온·강수확률 요약
- 별도 화면에서 330일 이내 미래 날짜와 일본 주요 도시를 선택해 예측
- 가까운 날짜는 실예보, 먼 날짜는 과거 연도 기후 통계 사용

### 메뉴 화면

- 익명 계정의 Apple/Google 연동
- 개인정보·체감정보·표시 테마·계정 관리

### 피드백 (바텀시트)

- Step 1: 대상 날짜·외출 시간대·실제 착용 복장 선택
- Step 2: 체감 선택 (추웠어요 / 딱 좋았어요 / 더웠어요)
- 완료 → "반영했어요!" → 닫힘

### 설정 화면

- 별명 변경
- 성별 변경
- 추위/더위 성향 재설정 (변경 시 보정값 초기화 + 확인 팝업)
- 위치 변경 (GPS 재설정 또는 수동 지역 선택)
- 체감 데이터 초기화
- 테마 선택 및 개인정보처리방침 열기
- Apple/Google 계정 연동
- 로그아웃
- 계정 삭제

### 복장 아이콘

- 총 16개 UI 에셋: 상의 6 + 하의 4 + 겉옷 5 + 겉옷 없음 1
- 심플한 라인 일러스트 스타일
- 패션 앱처럼 보이지 않으면서 직관적인 디자인

---

## 8. 일본 출시용 개인정보/위치정보

### 수집하는 개인정보

| 데이터 | 분류 | 수집 경로 |
|---|---|---|
| 익명 계정 비밀값 또는 Apple/Google 인증 ID | 인증정보 | 자동 계정 생성/계정 연동 |
| 별명 | 개인정보 | 온보딩 |
| 성별 | 개인정보 | 온보딩 |
| 위치정보 (위도/경도) | 위치정보 | GPS/수동 |
| 추위/더위 성향 | 개인정보 | 온보딩 |
| 피드백 기록 | 이용 기록 | 앱 사용 중 |
| 보정값 | 이용 기록 | 자동 생성 |

### MVP 필수 구현 사항

**프라이버시 폴리시**

- GitHub Pages로 호스팅 (무료)
- 앱 내에서도 같은 URL을 WebView로 표시
- 포함 내용: 수집 항목, 이용 목적, 제3자 제공 여부, 보관 기간, 사용자 권리, 문의처

**위치정보**

- 온보딩에서 사용 목적 설명 후 시스템 권한 요청
- iOS: NSLocationWhenInUseUsageDescription에 일본어 사용 목적 기재
- Android: ACCESS_FINE_LOCATION 또는 ACCESS_COARSE_LOCATION
- "사용 중만" 권한 (백그라운드 불필요)

**계정 삭제**

- 앱 내에서 계정 삭제 가능 (Apple 필수 요구사항)
- 삭제 시 users, feedbacks 레코드 모두 삭제

**ATT (앱 추적 투명성)**

- IDFA 미수집으로 Firebase Analytics 설정
- ATT 팝업 불필요

**데이터 보관**

- 계정 존재 기간 동안 보관
- 계정 삭제 시 모든 데이터 삭제

**스토어 등록**

- 프라이버시 폴리시 URL
- App Store: 앱 프라이버시 영양 라벨
- Google Play: 데이터 안전 섹션

---

# 현재 UI 구조

- **디자인 시스템:** 오프화이트 배경, 테마 토큰 기반 라이트·다크·시스템 모드, 절제된 그래디언트와 글래스 효과를 사용합니다.
- **공통 셸:** `RootShell`이 홈·예보·메뉴 세 탭, 공통 `KisouTopBar`, 광고 자리표시자와 하단 내비게이션을 관리합니다.
- **상단 액션:** 홈은 피드백, 예보는 미래 날짜·장소 예측 진입 버튼을 표시하며 메뉴에는 별도 액션이 없습니다.
- **홈:** 1순위 추천을 먼저 표시하고 2·3순위는 기본 접힘 상태에서 펼칠 수 있습니다. 복장 순서는 겉옷 → 상의 → 하의입니다.
- **예보:** 내일 추천, 오늘 대비, D+2~D+4 요약과 날짜·도시별 미래 예측을 제공합니다.
- **메뉴:** 익명 계정 연동, 개인정보, 체감 데이터, 테마, 로그아웃과 계정 삭제를 관리합니다.
- **날짜 전환:** 앱 실행 중 또는 백그라운드 복귀 시 JST 날짜가 바뀌면 홈·예보·오늘 피드백 상태를 새로 불러옵니다.
- **앱 아이콘:** 시스템 알림을 유발하는 런타임 대체 아이콘 변경 없이 단일 정적 아이콘을 사용합니다.

## 운영 API 연결

- 개발 빌드는 `config/dev.json`의 로컬 API를 사용하고, 운영 빌드는 `config/prod.json`의 `https://kisou.znak99.cloud`를 사용합니다.
- 릴리스 빌드에서는 개발 로그인 UI가 항상 비활성화되고, 비개발 API URL은 HTTPS여야 합니다.
- 운영 API는 별도 MacBook 서버의 Docker Compose에서 실행되며 Cloudflare Tunnel을 통해 공개됩니다.
