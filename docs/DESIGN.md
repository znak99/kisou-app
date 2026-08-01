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
| iOS 위젯 | SwiftUI + WidgetKit (Small / Medium) |
| Android 위젯 | Kotlin + AppWidget / RemoteViews (Small / Medium) |
| API 서버 | FastAPI |
| DB | PostgreSQL |
| 추천 로직 | Python 기반 |
| 푸시 알림 | Firebase Cloud Messaging + Firebase Installations |
| 크래시 분석 | Firebase Crashlytics (미도입) |
| 행동 분석 | Firebase Analytics (미도입) |
| 광고·동의 | google_mobile_ads 9.x (Google Mobile Ads + UMP) |
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
- 현재 운영판은 익명 계정만 제공하며 기기 변경 시 데이터 이전을 지원하지 않음
- Apple / Google 로그인·연동 코드는 실서비스 자격 증명과 심사 준비가 끝날
  때까지 운영 UI에서 비활성화
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
- 체감 데이터 초기화
- 라이트 / 다크 / 시스템 테마 선택
- 개인정보처리방침 열기
- 로그아웃
- 계정 삭제
- 외부 삭제용 지원 ID·삭제 코드 발급, 표시, 복사, 교체와 백업 확인

**광고·추가 예측**

- `ADS_ENABLED`로 명시적으로 활성화한 빌드의 UMP 동의 게이트
- 예보 스크롤 끝의 비개인화 인라인 adaptive 배너
- 날짜 지정 예측 횟수가 소진된 뒤 사용자가 명시적으로 시작하는
  서버 검증형 리워드 광고

**매일 푸시 알림**

- 사용자가 명시적으로 켜는 아침 복장 추천·저녁 체감 기록 알림
- 각 알림의 `Asia/Tokyo` 기준 시각 설정과 foreground·background·종료 상태
  탭 이동
- 계정·설치 세대가 다른 payload 차단과 로그아웃·계정 전환·삭제 시 token/FID
  정리

**홈 화면 위젯**

- iOS Small·Medium 및 Android 크기 가변 Small·Medium 오늘 추천
- 앱이 인증 API를 호출해 최소 스냅샷을 저장하고, 네이티브 위젯은 네트워크나
  토큰 없이 공유 파일만 읽는 구조
- 위젯 탭의 정확한 홈 이동과 홈·위젯 강제 갱신, 로그아웃·계정 전환·삭제의
  재시작 안전 `signed_out` 경계

### 제외

- 로지스틱 회귀 모델 (데이터 축적 후 도입)
- 과거 피드백 히스토리 열람 화면
- 소셜/공유 기능
- 옷장 등록, 코디 저장
- 색상/브랜드/스타일 추천
- 우산/소지품 추천
- 다국어 지원 (일본어 단일)
- 유료 기능, 구독
- Apple / Google 실서비스 로그인·계정 연동

---

## 2. 추천 로직 상세

### 입력값

- **날씨 데이터:** 최근 피드백에서 반복된 외출 시간대 또는 기본
  09:00~18:00의 시간별 기온, 체감온도, 습도, 풍속, 강수확률·강수량
  (여름철 WBGT 추가)
- **사용자 프로필:** 성별, 추위/더위 성향
- **사용자 보정값:** 피드백 누적으로 조정된 개인 체감 오프셋
- ※ 별명은 UI 표시용이며 로직 입력이 아님

### 출력값

- 복장 태그 조합 3개 (1번 가장 추천 / 2번 약간 따뜻한 방향 / 3번 약간 가벼운 방향)
- 각 조합은 상의 + 하의 + 겉옷(선택)
- 각 조합의 `direction`은 `primary` / `warmer` / `lighter` /
  `alternative` 중 하나이며 앱은 순위가 아니라 이 값을 표시 문구의 근거로
  사용
- 추천 당시의 결과·사용자·JST 날짜를 결합한 서명형
  `recommendation_context`, 실제 분석에 적용한 시간대와 유효 시간 수를 함께
  반환

### 체감 점수

Open-Meteo 체감온도가 있으면 이미 습도·풍속·일사를 반영한 값을 사용하고
습도·풍속을 다시 더하지 않습니다. 체감온도가 없을 때만 실제 기온에 상한이
있는 습도·풍속 보정을 적용합니다. 두 경로 모두 WBGT와 강수 보정을 별도로
적용하며, 과거 강수확률이 없으면 시간당 실제 강수량을 비가 온 신호로
사용합니다.

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
- 카탈로그의 가장 따뜻하거나 가장 가벼운 경계에 도달해 해당 방향의 서로
  다른 조합을 더 만들 수 없으면 2번 또는 3번은 같은 보온도의
  `alternative`가 될 수 있음
- 앱은 `direction=alternative`를 `同じ暖かさの別案`으로 표시하고
  `少し暖かめ` 또는 `少し軽め`라고 잘못 단정하지 않음. 보조기기에는
  `2番目の候補、同じ暖かさの別案`처럼 순위와 의미를 일본어로 함께 전달

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
| HALF_PANTS | 半ズボン |
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

### 홈 화면 위젯

`GET /widget/today`는 Bearer 인증을 사용하며 rank 1 추천만 아래 exact JSON으로
반환합니다. `Cache-Control: private, no-store`와 `Pragma: no-cache`를 사용하고
ETag/304는 지원하지 않습니다. 별명, 계정 ID, 위치, 날씨, 추천 컨텍스트,
토큰은 응답과 단말 스냅샷에 포함하지 않습니다.

```json
{
  "schema_version": 1,
  "date": "2026-07-31",
  "valid_until": "2026-07-31T15:00:00Z",
  "feeling": "PERFECT",
  "recommendation": {
    "top": "SHORT_SLEEVE",
    "bottom": "LONG_PANTS",
    "outer": null
  }
}
```

앱은 누락·추가 필드, `1.0`/boolean schema, 알 수 없는 코드, 공백·offset·소수초·
leap second가 있는 만료 시각을 거부합니다. `date`는 `Asia/Tokyo` 날짜이고
`valid_until`은 그 날짜 다음 JST 자정의 초 단위 canonical UTC `Z`와 정확히
같아야 합니다. 검증 후에만 다음 공유 envelope를 원자적으로 게시합니다.

- 준비 상태:
  `{"schema_version":1,"state":"ready","date", "valid_until","feeling",`
  `"recommendation":{"top","bottom","outer"}}`
- 계정 종료 상태:
  `{"schema_version":1,"state":"signed_out"}`

공유 파일은 위 고정 키 순서와 공백 없는 UTF-8 byte envelope 하나만 허용합니다.
Android/iOS는 의미 검증 뒤 canonical envelope를 다시 조립해 원문 byte와
일치하는지 확인하므로 중복 key, key 순서·escape·공백 변형, 주석·작은따옴표,
trailing content처럼 native JSON parser가 관대하게 받을 수 있는 입력도
손상 상태로 처리합니다.

데이터 흐름은 `API → Dio 인증 클라이언트 → Flutter strict model/coordinator →
MethodChannel → native 공유 파일 → 위젯 렌더러`입니다. 네이티브 위젯과 Android
주기 갱신은 네트워크를 호출하지 않습니다. Android는 `noBackupFilesDir`의
`AtomicFile`을 단일 IO executor에서 읽고 `fd.sync` 후 교체합니다.
`finishWrite` 뒤에도 8KiB 이하의 저장 bytes를 다시 읽어 기대 envelope와
완전히 같고 read-back 전후 `.bak`·`.new` 잔존 파일이 없는 경우에만 성공으로
응답하며, finish 이후에는 닫힌 stream에 `failWrite`를 다시 호출하지 않습니다.
iOS는
환경별 App Group 안에 `Data.write(.atomic)`로 교체하고 `FileHandle.synchronize`
완료 뒤 응답하며, 파일 보호와 backup 제외를 적용합니다.

Flutter coordinator는 성공 후 3시간 cooldown, 최신 실패 후 1분 재시도를
적용합니다. 오프라인 실패는 같은 JST 날짜의 기존 ready 파일을 보존하고,
네이티브가 날짜 불일치·만료·손상·알 수 없는 코드에서 날짜가 포함된 일반
placeholder로 fail-closed 합니다. 시작·foreground 복귀·JST 날짜 전환에서
갱신하며, 홈 수동 갱신과 위젯 탭은 cooldown을 우회합니다. 프로필·피드백·
초기화 mutation은 이전 응답 revision을 폐기하고 mutation 완료 후 새 결과를
강제 조회합니다.

iOS timeline은 현재 ready entry와 `valid_until`의 placeholder entry를 함께
만들고 `.atEnd`를 요청합니다. `reloadTimelines`는 WidgetKit에 재로딩을
요청할 뿐 렌더 완료 시각을 보장하지 않으며 OS 정책 때문에 자정 경계 반영이
늦을 수 있습니다. Android의 30분 `updatePeriodMillis`도 공유 파일을 다시
읽기만 합니다.

계정 종료는 먼저 coordinator generation을 닫아 old API/native write를
drain한 뒤 `signed_out` 파일과 cold route 삭제를 완료하고 네이티브 reload를
요청합니다. 이 단계가 실패하면 인증 정보를 보존하고 coordinator lease와
cooldown만 복구해 명시적 재시도를 허용합니다. 성공한 route-disabled 상태는
프로세스 재시작 때 공유 파일에서 복구하며, 다음 계정의 valid ready write가
성공하기 전에는 열지 않습니다. Dart와 양 네이티브 bridge의 epoch는 이전
ready completion이 더 최신 tombstone을 덮거나 경로를 다시 여는 것을 막습니다.
같은 계정의 ready 갱신 성공은 아직 Dart가 consume하지 않은 tap을 지우지
않습니다. Android는 비동기 공유 파일 hydration이 끝나기 전의 cold/warm tap을
보존하고 consume 요청에는 일단 `false`를 반환한 뒤, hydration 또는 ready
게시로 route lease가 열리면 callback을 다시 보냅니다. 계정 close만 hydration과
이전 ready를 폐기하고 pending route를 제거합니다. Android는 파일 자체가 없는
최초 상태와, 파일은 존재하지만 unreadable·비정상 type·8KiB 초과인 손상 상태를
구분해 손상 상태의 route를 fail-closed 합니다.

위젯 URL은 prod `kisou://widget/home`, dev `kisou-dev://widget/home`만 허용하며
user/password/port/query/fragment를 거부합니다. Flutter 자동 deep linking은
비활성화하고 custom bridge가 cold/warm route를 단독 소유합니다. Android
application ID/no-backup 저장소와 iOS App Group·bundle ID·URL scheme은
dev/prod가 분리됩니다.

iOS ready 내용은 `.privacySensitive()`로 OS redaction을 허용합니다. 양 플랫폼은
라이트/다크 4.5:1 대비와 큰 글자 compact 분기를 사용하며 날짜와 상의·하의·
겉옷은 유지합니다. 작은 큰 글자 layout에서는 공간 확보를 위해 체감 문구와
반복 category/title을 축약할 수 있습니다. 실제 App Group capability,
extension provisioning/profile, `xcodebuild -showBuildSettings` 9개 구성,
WidgetKit 반영 지연·잠금 redaction·VoiceOver/TalkBack·200% 글자 크기는
macOS와 실기기에서 소유자가 최종 확인합니다.

---

## 3. 온보딩 설계

앱 첫 실행 시 익명 계정을 자동 발급한 뒤 1회 진행합니다. 네 단계 모두 필수이며,
위치를 고른 뒤 `この設定で始める`을 눌렀을 때 프로필을 한 번에 저장합니다.
익명 계정은 온보딩 전에 이미 서버에 생성되므로, 모든 단계의 상단에서
`アカウント削除`를 제공해 설정을 끝내지 않은 사용자도 서버 계정과 단말
데이터를 직접 삭제할 수 있습니다.

마지막 프로필 저장이 성공하면 온보딩 완료 상태를 기록하기 전에 외부 삭제용
정보를 발급할지 한 번 안내합니다. `発行画面を開く`을 고르면 삭제용 정보
화면으로 이동하지만 코드 발급은 그 화면의 별도 확인을 거쳐야 합니다.
`あとで`를 골라도 온보딩은 완료되며 메뉴의 `削除用情報`에서 언제든 다시
발급할 수 있습니다.

**Step 1: 별명 입력**

- 2~10자
- `なんとお呼びすればよいですか？`와
  `ホーム画面の呼びかけに使います。`로 사용 목적을 먼저 설명
- 앱 내에서 "○○さん、今日は…" 형태로 사용
- 키보드 완료 키, 입력란 바깥 탭, `次へ`와 단계 이동 시 입력 포커스를
  해제해 화면이 바뀐 뒤 키보드가 남지 않도록 함

**Step 2: 성별 선택**

- `服装のおすすめに使う情報を教えてください`와 비공개·추천 조정 목적 설명
- 남성 / 여성 / 응답 안 함
- "응답 안 함"인 경우 하의 후보 전체 포함

**Step 3: 추위/더위 성향**

- 추위: 잘 탐 / 보통 / 안 탐
- 더위: 잘 탐 / 보통 / 안 탐
- 이 답변으로 초기 보정값 설정

**Step 4: 위치 설정**

- `天気を表示する地域を設定します`와 현재지의 이용·비공개 목적 설명
- `現在地から設定`을 누른 경우에만 시스템 권한 요청
- 위치 서비스 꺼짐, 1회 거부, 영구 거부를 구분하고 각각 재시도 또는 단말
  설정 이동을 제공
- 허가 시 GPS를 역지오코딩해 ISO 국가코드가 `JP`인 경우에만 현재지를 저장
- 일본 밖이거나 국가를 확인할 수 없으면 GPS 값을 저장하지 않고 일본 주요
  도시 수동 선택 바텀시트로 강제 전환
- 수동 선택은 항상 대체 경로로 제공
- 지역 선택 후 `この設定で始める`로 명시적으로 확정
- 저장 성공 시 차단형 완료 팝업 없이 홈으로 이동하고
  `設定が完了しました` 스낵바 표시
- 저장 실패 시 네 단계의 입력을 유지하고 같은 버튼에서 재시도

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

- Step 1 `いつ外にいましたか？`: 날짜(오늘~7일 전)와 실제 외출 시간대
  필수·복수 선택
- Step 2 `何を着ていましたか？`: 아우터 → 상의 → 하의 순서로 실제 착용
  복장 선택
- Step 3 `どう感じましたか？`: 추움 / 적당함 / 더움 중 체감 선택 후
  `記録する` 또는 `変更を保存`으로 명시적 저장
- 상단에 `1/3`~`3/3` 진행률을 표시하고 뒤로 이동해도 입력을 유지

사용자·날짜별 1회이며 같은 날짜는 수정할 수 있습니다.

날짜 버튼은 `今日 7/29（水）`처럼 가운데점 없이 표시합니다. 버튼을 누르면
별도 팝업을 중첩하지 않고 시트 내부가 최근 8일 선택 화면으로 전환됩니다.
오늘·어제, 기록 유무, 현재 선택 상태를 함께 표시하며 200% 글자 크기에서는
날짜와 상태를 두 행으로 재배치합니다. 기록이 있으면 저장된 시간대·복장·체감을
복원하고 `保存済みの記録を編集中`, 없으면
`この日の記録はまだありません`을 표시합니다. 오늘 추천 복장은 자동으로
선택하지 않으며, 사용자가 `おすすめと同じ服装を選ぶ`을 명시적으로 누른
경우에만 1순위 추천을 채웁니다. 사용자가 직접 수정한 내용이 있는 상태에서
날짜를 바꾸면 폐기 확인을 거칩니다.

피드백 버튼을 누르는 순간 메모리에 준비된 `/home`의 날짜·추천 조합·
`recommendation_context`를 하나의 스냅샷으로 고정해 시트에 전달합니다.
시트가 열린 뒤 홈이 갱신되더라도 서로 다른 추천과 서명값을 섞지 않습니다.
대상 날짜가 시트를 연 JST 날짜이고 고정한 홈 날짜와도 일치할 때만 서명값을
전송하므로, 23:59에 연 시트를 자정 뒤 저장해도 유효한 전날 컨텍스트를
보존합니다. 다른 과거 날짜 또는 홈 미로딩·구 API 응답에서는 전송하지
않습니다. 명시적 추천 적용 시 `applied_recommendation_rank=1`을 기록하고
이후 상의·하의·아우터 중 하나를 수동으로 바꾸면 이 값을 `null`로
해제합니다. 기존 기록 수정 시에는 API가 돌려준 적용 순위를 복원하되 같은
수동 변경 규칙을 적용합니다.

외출 시간대는 다음 6개 구간을 3열×2행의 동일한 크기로 표시합니다. 화면에는
분을 노출하지 않되 각 버튼의 접근성 이름에는 실제 범위를 전달합니다.

| 코드 | 화면 표시 | 실제 범위 |
|---|---|---|
| EARLY_MORNING | `早朝` / `4〜7時` | 04:00~07:59 |
| MORNING | `午前` / `8〜11時` | 08:00~11:59 |
| AFTERNOON | `午後` / `12〜15時` | 12:00~15:59 |
| EVENING | `夕方` / `16〜19時` | 16:00~19:59 |
| NIGHT | `夜` / `20〜23時` | 20:00~23:59 |
| LATE_NIGHT | `深夜` / `0〜3時` | 00:00~03:59 |

초기에는 시간대 선택 안내만 표시합니다. 첫 단계의 `次へ`를 탭했을 때
시간대가 비어 있으면 화면을 전환하지 않고 한 단계 작은
`外出時間帯を1つ以上選択してください` 오류를 그때 처음 표시합니다.
오류가 화면 밖에 있으면 시간대 섹션이 보이는 위치로 이동합니다. 시간대를
선택하면 오류를 즉시 해제합니다. 의류 단계에서는 성별과 무관하게 모든 실제
하의 선택지를 제공하며, 아우터는 미선택과 `アウターなし`를 구분합니다.
아우터·상의·하의를 모두 명시적으로 선택해야 체감 단계로 이동할 수 있습니다.
체감 선택만으로 전송하지 않고 마지막 저장 버튼을 눌러야 API를 호출합니다.
의류 선택 상태는 타일 전체의 저대비 배경·테두리와 우측 상단 20dp 체크
배지로 표현하며, 이미지 모서리를 따라 잘린 테두리는 사용하지 않습니다.

### 피드백 저장 데이터

- 사용자 ID
- 날짜
- 피드백 값 (cold / perfect / hot)
- `/home`이 발급한 사용자·날짜·알고리즘 버전 결속 9일 만료 서명
  컨텍스트와 검증된 실제 표시 추천 조합 스냅샷
- 실제 착용 복장 (actual_top, actual_bottom, actual_outer)
- 실제 외출 시간대 (time_slots, 신규·수정 UI에서 필수)
- 선택 시간대의 날씨 데이터 스냅샷
- 추천 표시 시점과 실제 경험 시간대의 버전화된 점수 구성·결측·프로필 피처
- 제출 시점 offset, 추천 표시 시점 offset, replay 전 offset과 실제 적용 delta
- 컨텍스트 출처, 학습 적격성, 제외 사유, 보정 epoch·정책 버전
- 사용자가 명시적으로 적용한 추천 순위(수동 선택·변경이면 null)

### 보정값 업데이트 규칙

| 조건 | 추웠어요 | 딱 좋았어요 | 더웠어요 |
|---|---|---|---|
| 검증된 1순위대로 입음 | +0.3 | 변화 없음 | -0.3 |
| 다르게 입음 또는 미검증 | +0.15 | 변화 없음 | -0.15 |

- 보정값 범위: -3 ~ +3
- 범위 도달 시 더 이상 변하지 않음
- 서명 컨텍스트가 없는 구버전 요청은 추천 일치 보너스를 적용하지 않음
- 검증된 cold/hot 체감이 같은 방향으로 이어지면 1회 1.0배, 2회 1.25배,
  3회 이상 1.5배를 `ROUND_HALF_UP`으로 소수 둘째 자리까지 적용
- perfect, 반대 방향, 미검증 컨텍스트, 성향 변경은 연속 체감을 끊음
- 같은 calibration epoch의 신규 행은 고정 기준선부터 `(date, id)` 순으로
  replay하므로 backdate·수정·동시 요청의 도착 순서에 영향받지 않음
- 배포 전 기존 행은 당시 현재 offset에 포함된 상태로 기준선에 보존하고
  부정확한 추천·피처를 추정하거나 새 정책으로 재계산하지 않음
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
| calibration_epoch_id | UUID | 현재 보정 구간 식별자 |
| calibration_baseline_offset | FLOAT | 현재 epoch의 불변 replay 기준선 |
| calibration_policy_version | VARCHAR | 현재 보정 정책 버전 |
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
| context_source | VARCHAR | served_context / legacy_reconstructed / legacy_unverified |
| applied_recommendation_rank | SMALLINT (nullable) | 앱에서 명시적으로 적용한 추천 순위 |
| calibration_epoch_id | UUID (nullable) | 신규 보정 행이 속한 epoch |
| replay_offset_before / applied_delta | NUMERIC | replay 직전 값과 실제 기여분 |
| streak_length | SMALLINT (nullable) | 검증된 동일 방향 연속 횟수 |
| model_features | JSONB (nullable) | 표시 시점 prediction과 경험 시점 피처 |
| feature_time_slots | JSONB (nullable) | 피처 생성에 사용한 불변 시간대 |
| training_eligible / exclusion_reason | BOOLEAN / VARCHAR | 학습 사용 여부와 제외 이유 |
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
- 오늘·미래 예보의 캐시 갱신 주기: 3시간
- 강수확률 보조 호출이 실패해도 JMA 실제 강수량이 있으면 저하 상태 캐시를
  같은 3시간 동안 사용해 장애 시 재호출 폭증을 막음
- 과거 날씨는 한 번 저장 후 갱신 불필요

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
| GET | /widget/today | 위젯용 rank 1 최소 추천과 다음 JST 자정 만료 시각 |
| GET | /users/me | 프로필 조회 |
| PUT | /users/me | 프로필 업데이트 |
| POST | /users/me/reset-data | 피드백 삭제 + 성향 기준 보정값 초기화 |
| DELETE | /users/me | canonical UUID v4 `Idempotency-Key`로 계정·관련 데이터 삭제 및 24시간 완료 영수증 생성 |
| POST | /account-deletion/status | JWT 없이 삭제 UUID의 `completed` 영수증 확인(없음·만료는 404) |
| POST | /feedback | 오늘~7일 전 피드백 제출/수정 + 보정값 업데이트 |
| GET | /feedback/today | 오늘 피드백 제출 여부 확인 |
| GET | /feedback/recent | 오늘부터 7일 전까지 기록 유무와 저장 내용 일괄 조회 |
| GET | /analysis | 체감 성향·피드백 분포·날짜순 이력 조회 |
| GET | /forecast/tomorrow | 내일 추천·오늘 비교·D+2~D+4 요약 |
| GET | /forecast/outlook/quota | JST 기준 무료 횟수·검증된 보상 크레딧·광고 발급 가능 상태 |
| POST | /forecast/outlook | 미래 날짜·좌표의 실예보 또는 과거 기후 추정, 멱등 UUID로 1회 차감 |
| POST | /ads/rewards/challenges | 플랫폼·실제 로드한 광고 단위·클라이언트 UUID가 일치하는 멱등 SSV challenge 발급 |
| GET | /ads/rewards/challenges/{id} | pending·settling·credited·consumed·expired 상태 조회 |
| POST | /ads/rewards/challenges/{id}/development-confirm | 공식 테스트 광고의 개발 전용 보상 확인 |
| GET | /push/preferences | 아침·저녁 사용 여부와 `Asia/Tokyo` 시각 조회 |
| PUT | /push/preferences | 아침·저녁 사용 여부와 시각 원자적 갱신 |
| PUT | /push/devices | install UUID·단조 증가 client revision으로 FCM token 멱등 등록 |
| POST | /push/devices/unregister | 더 높은 client revision으로 설치 등록 tombstone 전환 |

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
      "direction": "primary",
      "top": "THIN_LONG",
      "bottom": "LONG_PANTS",
      "outer": "LIGHT_OUTER"
    },
    {
      "rank": 2,
      "direction": "warmer",
      "top": "LONG_SLEEVE",
      "bottom": "LONG_PANTS",
      "outer": "CARDIGAN"
    },
    {
      "rank": 3,
      "direction": "lighter",
      "top": "SHORT_SLEEVE",
      "bottom": "LONG_PANTS",
      "outer": "LIGHT_OUTER"
    }
  ],
  "recommendation_context": "<opaque-signed-context>",
  "applied_time_slots": ["MORNING", "EVENING"],
  "hours_analyzed": 8,
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
- **추천 영역:** `今日の服装はこちら` 아래 1번 추천을 표시하고 2·3번은 접힌 상태에서 펼칠 수 있습니다. 모든 추천의 순서는 겉옷 → 상의 → 하의로 통일하며 겉옷이 없을 때도 `アウターなし`를 생략하지 않습니다. 2·3번의 설명은 순위로 추론하지 않고 서버의 `direction`을 사용하며, 보온도 경계의 동급 대안은 `同じ暖かさの別案`으로 표시합니다.
- **체감 영역:** 사용자명을 반복하지 않고 `体感予想`과 `〜感じそうです` 형식의 한 문장으로 안내합니다. 카드 전체를 누르면 개인 체감 분석 화면으로 이동합니다.
- **날씨 비교 영역:** 오늘/어제/2일 전 기온 비교 (예: "어제보다 3도 낮아요")
- **출처 영역:** 오늘 날씨·날씨 비교 카드 바로 뒤의 같은 스크롤 흐름에
  `天気データ: Open‑Meteo`, `CC BY 4.0`, `加工あり`를 표시합니다.
  출처와 라이선스는 각각 외부 링크이며 최소 48dp 터치 영역과 명시적인
  보조기기 링크 의미를 제공합니다.
- **피드백 액션:** 공통 상단 툴바 우측에서 입력/수정

### 예보 화면

- 정보 순서는 `明日の予報` → 내일 날씨·추천 → `今後3日間` →
  D+2~D+4 기온·강수확률 → Open-Meteo 출처·라이선스·가공 표시 →
  단말의 `旅行予定` → 피드백 카드로 고정
- 피드백 카드는 연속된 예보를 끊지 않도록 화면의 마지막 보조 행동으로 배치
- 최초 조회는 내일 추천 카드와 3개 일별 행의 실제 구조를 닮은 스켈레톤 표시
- 전체 화면 당겨서 새로고침을 제공하고, 재조회 중에는 기존 성공 데이터를
  유지한 채 시스템 새로고침 표시만 사용
- 오프라인은 `インターネット接続を確認してください`, 시간 초과는
  `予報の取得に時間がかかっています`, 기타 오류는
  `予報を読み込めませんでした`로 구분하고 `再試行` 제공
- 피드백 상태 조회 실패는 핵심 예보를 숨기지 않으며 재시도 중복 입력 방지
- 별도 화면에서 330일 이내 미래 날짜와 일본 주요 도시를 선택해 예측
- 가까운 날짜는 실예보, 먼 날짜는 과거 연도 기후 통계 사용

#### 여행 예정·출발 알림

- 예보 탭에는 가까운 여행 예정 최대 3건을 출발순으로 표시하고, 전체 관리
  화면에서 최대 20건을 추가·수정·삭제합니다. 출발일·시각과 D-day는 단말
  시간대와 관계없이 `Asia/Tokyo` 기준이며 지난 날짜의 일정은 재조정 시
  제거합니다.
- 장소는 15개 주요 도시의 안정적인 영문 코드로 저장합니다. 같은 도시와
  같은 UTC 출발 시각의 중복은 거부하고, 미래 시각만 저장합니다.
- 일정의 원본은 `sqflite` 데이터베이스이며 API로 전송하지 않습니다.
  네트워크가 없어도 조회·추가·수정·삭제할 수 있습니다. 날짜 지정 예측의
  성공 결과에서는 조회 당시 도시와 날짜를 편집기의 기본값으로 넘기되,
  사용자가 출발 시각과 알림 선택을 확인한 뒤 저장합니다.
- Android 앱 백업은 비활성화하고, iOS DB는 Application Support 전용
  하위 디렉터리에 두며 native에서 backup 제외와
  `completeUntilFirstUserAuthentication` 파일 보호 적용에 성공한 뒤에만
  엽니다. 기존 DB·WAL·SHM에도 같은 속성을 적용하며 실패 시 보호되지 않은
  경로로 대체하지 않습니다. 이전 Documents DB와 sidecar는 보호 경로에
  복사·보호한 뒤 기존 사본을 삭제합니다.
- 날짜 지정 예측에서 넘긴 날짜가 없는 신규 편집기는 고정 09:00이 아니라
  현재 시각 다음 JST 정시(자정이면 다음 날)를 기본값으로 사용합니다.
- 알림 기본값은 `通知しない`입니다. 사용자가 24시간 전 또는 3시간 전을
  선택하고 저장할 때만 OS 알림 권한을 요청합니다. Android는 정확 알람
  권한을 요구하지 않는 `inexactAllowWhileIdle`을 사용하므로 절전 설정에
  따라 지연될 수 있음을 편집기에 알립니다.
- DB 저장이 항상 먼저 완료됩니다. 권한 거부는 `blockedPermission`, 플랫폼
  예약·교체·취소 실패는 `pendingSchedule` outbox와 사용자 경고로 표시하며
  저장 자체를 실패로 되돌리지 않습니다. 앱 시작·foreground 복귀·JST
  자정에 예약 누락, 변경, 취소, 삭제 outbox와 고아 알림을 재조정합니다.
  재조정과 CRUD는 직렬화해 이전 snapshot이 최신 수정 예약을 덮어쓰지 않게
  합니다. Android inexact 알림이 명목 시각 뒤에도 OS pending이면 출발
  시각까지만 보존하고, 출발 뒤에는 취소합니다.
- 잠금화면 알림은 도시·출발시각을 포함하지 않는 일반 문구만 사용하고,
  payload는 `travel:<로컬 일정 ID>`, Android 알림 ID는
  `100000..199999` 전용 범위로 격리합니다. 알림 탭 대상이 이미 삭제되었거나
  만료됐으면 관리 화면에서 안전한 찾을 수 없음 안내만 표시합니다.
- 로그아웃, 새 계정 로그인, 앱 내 계정 삭제 시 예약된 여행 알림을 먼저
  취소한 뒤 단말 DB를 삭제합니다. 공개 웹 삭제는 분실·고장 단말을 원격으로
  지울 수 없습니다.

#### 아침 추천·저녁 피드백 푸시

- 설정 기본값은 아침 `07:00`, 저녁 `20:00`, 양쪽 모두 꺼짐이며 모든 시각은
  단말 시간대가 아니라 `Asia/Tokyo` 기준입니다. 선택한 시각은 정확 알람이
  아닌 서버 발송 목표이므로 APNs·FCM·운영체제 상태에 따라 지연되거나
  전달되지 않을 수 있습니다.
- `PUSH_NOTIFICATIONS_ENABLED`의 기본값은 `false`입니다. 활성 빌드만 Android·
  iOS Firebase 식별자를 플랫폼·환경과 대조하며, 잘못된 boolean 또는 누락·
  형식 오류는 앱 상태나 네트워크에 접근하기 전에 fail-closed 처리합니다.
  Firebase 단말 초기화 실패는 날씨·인증·피드백 등 핵심 기능을 막지 않고
  알림 설정과 foreground 복귀에서 재시도합니다.
- Android manifest와 iOS Info.plist는 FCM auto-init과 Firebase Analytics
  수집을 기본 비활성화합니다. 사용자가 설정에서 처음 아침 또는 저녁 스위치를
  켠 동작만 OS 알림 권한 요청을 시작합니다. 권한이 없거나 거부되면 server
  preference를 켜지 않고, 차단 상태에는 단말 설정 이동을 제공합니다.
- 활성화는 보안 저장소에 `platform_cleanup_required`를 먼저 기록한 뒤
  auto-init 활성화 → token 조회 → 서버 등록 순으로 직렬화합니다. 단말에는
  raw FCM token을 저장하지 않고 SHA-256 fingerprint, canonical lowercase
  install UUID v4, 앱 버전, 플랫폼, 단조 증가 int64 client revision만
  보관합니다. 응답 유실 재시도는 같은 UUID·revision·의미상 같은 요청을
  재전송합니다.
- 서버가 보내는 data payload는 정확히
  `schema_version`, `type`, `delivery_id`, `client_revision` 네 문자열만
  허용합니다. type은 `morning_recommendation|evening_feedback`,
  `delivery_id`는 canonical lowercase UUID v4, revision은 canonical 양의
  int64 decimal입니다. 별명, 내부 user ID, 위치, 날씨, 추천 상세, token,
  install UUID는 제목·본문·payload에 포함하지 않습니다.
- 앱은 현재 설치 레코드의 active revision 또는 응답 유실로 남은 pending
  register revision과 정확히 일치하는 payload만 처리합니다. pending
  unregister와 과거·미래 revision은 모두 거부합니다. delivery UUID는
  SharedPreferences의 최대 64개 versioned receipt로 foreground 표시와
  navigation pending·완료를 crash-safe하게 1회 처리합니다.
- foreground에서는 시스템 배너를 중복 표시하지 않고 앱 내부 배너를
  제공합니다. morning 탭은 홈으로 이동해 추천을 새로 읽고, evening 탭은
  공통 피드백 입력을 엽니다. background는 `onMessageOpenedApp`, 종료 상태는
  `getInitialMessage`를 사용하며, pending route는 재시작 뒤에도 revision을
  다시 검증합니다.
- 양쪽 알림을 끄거나 로그아웃·계정 전환·앱 내 계정 삭제를 시작하면 이전
  계정 세대를 먼저 닫고 더 높은 unregister revision을 보안 저장소에
  기록합니다. 서버 unregister와 단말 정리는 독립적으로 시작하며, 단말은
  auto-init 비활성화 → FCM token 삭제 → Firebase Installation ID 삭제
  순서를 전부 완료해야 cleanup marker를 지웁니다. 전환 전후에 종료 상태
  message를 소진하고 이미 표시된 매일 푸시만 제거합니다.
- 로그아웃·계정 전환의 로컬 정리는 push close와 여행·삭제 코드 등 독립
  계정 저장소를 먼저 모두 시도하는 선행 단계와 auth 소유 데이터의 최종
  단계로 나눕니다. 선행 단계 하나라도 실패하면 transition marker,
  access/refresh token, onboarding 상태를 유지해 인증된 unregister와 단말
  정리를 재시도합니다. 선행 단계가 전부 성공한 경우에만 pending reward,
  onboarding, 마지막으로 session token을 지웁니다. 재시작 복구, 명시적
  재시도, 새 로그인 전 account switch, 세션 만료가 같은 gate를 사용합니다.
  이 전환이 보낸 unregister의 401·refresh 실패는 API interceptor에서도
  token·onboarding을 지우거나 전역 세션 만료 callback을 부르지 않고 선행
  단계 실패로 반환하며, 최종 auth 단계만 credential 삭제를 소유합니다.
- 설치 메타데이터의 확정적 JSON/형식 손상은 key 존재 자체를 과거 Firebase
  활성화 가능성으로 봅니다. 서버 UUID·revision은 신뢰하지 않고 token/FID
  정리를 완료한 뒤에만 새 revision-0 레코드로 교체합니다. 정리나 secure
  write가 실패하면 손상값을 retry marker로 유지합니다. 원인불명의 Keychain·
  Keystore `PlatformException`은 값을 지우거나 추정하지 않고 계정 전환을
  차단해 재시도합니다.
- receipt 손상은 push close보다 먼저 전환을 막지 않습니다. durable
  unregister 경계와 필요한 token/FID 정리가 끝난 뒤에만 손상 receipt key를
  제거하며, close 실패에는 그대로 보존합니다. 서버에서 식별할 수 없는
  손상 레코드의 과거 token row는 token/FID 무효화 후 서버의 invalid token·
  30일 stale 정리 대상이 됩니다.
- Android daily channel은 `push_daily_v1`, 표시 정리 tag는
  `kisou_daily_push_v1`입니다. iOS는 같은 값을 `thread-id`로 사용합니다.
  native 정리는 이 namespace만 대상으로 하므로 SQLite 여행 알림
  `travel:`/ID `100000..199999`는 건드리지 않습니다.

#### 미래 날짜·장소 예측 화면 상태 설계

- 입력 카드는 날짜와 장소 선택, 서버가 반환한 무료 횟수와 보상 크레딧의
  합계, 예측 실행 버튼을 제공합니다. 기존 SharedPreferences 횟수 키는
  최초 서버 quota 조회에서 삭제합니다. 날짜를 선택하기 전이거나 남은
  횟수가 없거나 요청 처리
  중이면 실행 버튼을 비활성화하며, 빠른 연속 탭으로 요청과 횟수 차감이
  중복되지 않게 합니다.
- 입력 카드와 상태 영역 사이에는 32dp 간격을 둡니다. 날짜와 장소를 아직
  예측하지 않은 빈 상태에서는 투명 배경의 3D 클레이 일러스트
  `assets/illustrations/outlook_empty_state.png`를 중앙에 최대
  144×120dp로 표시합니다. 일러스트는 열린 아이보리색 여행 가방, 파란색
  반소매 상의, 주황색 아우터, 작은 달력과 위치 핀으로 구성됩니다.
- 빈 상태 일러스트 아래 16dp에
  `旅行の日付と場所を選びましょう`를 15sp·굵기 700·줄 높이 1.4로,
  다시 6dp 아래에
  `その日の気温とおすすめの服装を予想します`를
  13sp·굵기 400·줄 높이 1.5로 표시합니다. 두 문구는 최대 300dp 안에서
  중앙 정렬하고 큰 글자에서는 줄바꿈합니다. 장식 일러스트는 보조기기에서
  제외하고 두 안내 문구를 하나의 빈 상태 설명으로 전달합니다.
- 예측을 시작하면 빈 상태 또는 이전 결과를 같은 위치와 시각적 무게의 카드
  스켈레톤으로 교체하고 `予想結果を読み込んでいます`를 라이브 영역으로
  알립니다. 입력한 날짜와 장소는 처리 중에도 유지합니다.
- 성공 결과는 선택한 도시·날짜, 최저~최고 기온 또는 예년 범위, 개인화된
  체감 예상, 1순위 복장 추천, 실예보·기후 통계 중 어떤 근거를 사용했는지를
  하나의 결과 카드에 표시합니다. 실예보와 과거 기후 통계 결과 모두 카드
  안의 설명 바로 뒤에 Open-Meteo 출처·CC BY 4.0 라이선스·가공 표시를
  제공합니다. 결과 시작점이 화면 밖에 있을 때만
  애니메이션을 줄일 수 있는 설정을 존중하며 결과가 보이는 위치까지
  스크롤합니다.
- 먼 날짜의 Open-Meteo 재분석 표본 `min/max`는 공인 관측소의 공식 기록이
  아니므로 사용자에게 `역대 최저/최고` 또는 이에 준하는 극값으로 표시하지
  않습니다. 기후 통계 결과에는 예년 평균 최저~평균 최고와 계산에 사용한
  표본 연수·일수만 표시하며, 위젯 회귀 테스트로 극값 문구가 노출되지 않음을
  고정합니다.
- 실패하면 선택값을 유지한 채 같은 위치에 오류 아이콘, 실패 안내,
  `もう一度試す` 버튼이 있는 오류 카드를 표시합니다. 실패한 요청은 무료
  예측 횟수를 차감하지 않으며 재시도 중에는 버튼을 다시 비활성화합니다.
  날짜·정확 좌표 조합마다 UUID `Idempotency-Key`를 만들고 timeout·통신
  재시도에는 같은 키를 사용합니다. 입력 변경·성공 뒤에는 새 키를 만들며,
  409에서는 충돌 키를 폐기합니다. 409·429는 quota를 즉시 다시 읽고 이전
  성공 결과를 화면에서 제거하지 않습니다.
- 서버 합계가 0이고 `ads_available=true`일 때만 사용자가 명시적으로 누를
  수 있는 리워드 버튼을 표시합니다. 광고 로드 성공 뒤에만 challenge를
  발급하고, 로드에 사용한 광고 단위를 요청 본문에도 보내 서버 설정과
  정확히 대조합니다. API 호출 전에 canonical UUID v4를 보안 저장소에
  `issuing`으로 기록하며 timeout·응답 유실·프로세스 재시작에는 서버
  `expires_at`까지 같은 UUID만 재사용합니다. 최초 발급 응답 자체가 유실돼
  `expires_at`을 모르는 `issuing` 작업은 서버의 최대 60분에 1분 여유를 둔
  생성 후 61분까지 같은 UUID만 재사용합니다. 새 UUID와 `created_at`은 광고
  로드가 성공한 뒤 challenge API 직전에만 기록하므로, no-fill에는 미전송
  작업이 남지 않고 광고 로드 시간이 로컬 재생 상한을 앞당기지 않습니다.
  발급 응답을 받으면 challenge ID와 시각을 `issued`, 네이티브 SDK 진입
  전에는 `presented`로 기록하지만 43자 원문은 저장하지 않습니다.
- 재발급 응답이 `pending`일 때만 메모리의 challenge 원문을 SSV
  `customData`에 넣어 광고를 표시하고 `userId`는 설정하지 않습니다.
  `settling`은 표시 없이 polling, `credited`는 표시 없이 quota 갱신,
  `consumed|expired`는 로컬 작업 정리로 분기합니다. 계정 전환은 reward
  provider를 먼저 닫고 account-generation lease를 무효화한 뒤 진행 중
  보안 저장소 쓰기를 drain하고 마지막 delete를 수행합니다.
- 광고 시청만으로 앱이 운영 크레딧을 직접
  추가하지 않으며, 1·2·4·8초 이후 5초 간격으로 약 30초 동안 서버의
  `pending|settling|credited|consumed|expired`를 조회합니다. credited에서
  quota를 갱신하고 지연되면 안내를 유지한 채 foreground 복귀 시 다시
  확인합니다. 광고나 예측은 자동 실행하지 않습니다.
- 날짜·장소 입력은 일반 글자 크기에서 두 열, 큰 글자 또는 폭 320dp 미만에서
  세로 한 열로 재배치합니다. 빈 상태·로딩·오류·결과 모두
  `docs/CONVENTIONS.md`의 공통 접근성 완료 조건을 따릅니다.

#### 광고·동의·배너 수명주기

- `ADS_ENABLED`는 기본 `false`입니다. 비활성 또는 스토어 캡처 fixture는
  UMP, Mobile Ads SDK, quota API, 배너·리워드 플랫폼 채널을 호출하지
  않습니다. development 활성 빌드는 Google 공식 샘플 ID만 사용하고,
  production 활성 빌드는 Android·iOS App/배너/리워드 실제 ID가 모두
  유효하지 않으면 Dart 런타임과 네이티브 빌드에서 중단합니다.
- 활성 앱은 매 프로세스 시작에
  `requestConsentInfoUpdate → loadAndShowConsentFormIfRequired →
  canRequestAds` 순서를 한 번 수행합니다. UMP 오류가 나도 기존 동의로
  요청 가능한지 다시 확인하며, G 등급 request configuration을 적용한 뒤
  SDK를 single-flight로 초기화합니다. 일시 초기화 실패는 foreground
  복귀에서 재시도합니다.
- 모든 배너·리워드는 `nonPersonalizedAds=true`이고 위치·닉네임·체감·
  내부 사용자 ID를 광고 요청에 넣지 않습니다. 개인정보 옵션 메뉴는 UMP가
  required로 반환할 때만 표시합니다.
- Android 병합 manifest에서는 SDK가 추가하는 `AD_ID`와 Privacy Sandbox의
  `ACCESS_ADSERVICES_AD_ID`·`ACCESS_ADSERVICES_ATTRIBUTION`·
  `ACCESS_ADSERVICES_TOPICS` 권한을 제거합니다. iOS는
  `NSUserTrackingUsageDescription`을 선언하거나 ATT를 요청하지 않으며,
  앱은 IDFA와 앱·웹 간 추적을 사용하지 않습니다.
- 인라인 adaptive 배너는 예보 스크롤의 피드백 카드 뒤 마지막 항목입니다.
  실제 platform size가 반환된 뒤에만 그 높이와 위 간격을 차지합니다.
  no-fill·비활성은 0dp이고, 실패 재시도는 2·5·15초 세 번으로 제한합니다.
  폭·동의 세대 변경, IndexedStack의 숨은 탭, background 전환에서는 진행
  중 로드를 무효화하고 기존 `AdWidget`이 트리에서 제거된 다음 handle을
  dispose합니다.

### 메뉴 화면

- 섹션은 개인 정보 → 체감 설정 → 표시 설정 → 계정 설정 → 법률·지원 정보
  순으로 배치하고 개인정보처리방침은 콘텐츠의 마지막에 둡니다.
- 표시 설정에는 `毎日の通知` 진입을 두고, 아침·저녁 사용 여부와 JST 시각,
  OS 권한 상태, 저장·등록 오류와 재시도를 독립 스크롤 화면으로 제공합니다.
  320dp·200% 글자 크기에서도 두 카드와 권한 동작에 접근할 수 있어야 합니다.
- 체감 설정의 `体感分析`은 현재 체감 유형과 추위·적정·더위 기록 분포를
  표시합니다. 기록이 없으면 시작 안내, 4건 이하이면 평균 데이터를
  바탕으로 예상 중이라는 안내와 상세 분석까지 남은 횟수, 5건 이상이면
  최근 개인 기록의 날짜·체감·기온을 표시합니다. 상세 기록에서 날씨가
  표시될 때는 목록 바로 뒤의 같은 스크롤 흐름에 Open-Meteo
  출처·CC BY 4.0 라이선스·가공 표시를 제공합니다. 원시 보정값은
  사용자에게 노출하지 않습니다.
- 법률·지원 영역에는 `KISOUについて`와 개인정보처리방침을 두고, 앱 정보
  화면은 72dp 브랜드 마크, 앱 설명, 버전·빌드, 오픈소스 라이선스를
  제공합니다. 실제 문의 경로가 준비되기 전에는 동작하지 않는 문의 행을
  노출하지 않습니다.
- 콘텐츠가 화면보다 길 때만 콘텐츠 영역 상단에 높이 2dp의 희미한 가로형
  진행 표시를 고정합니다. 최상단은 10%에서 시작하고
  `10% + 90% × (현재 스크롤 위치 / 최대 스크롤 거리)`로 증가해 최하단에서
  100%에 도달합니다. 화면 오른쪽의 세로 스크롤 인디케이터는 사용하지
  않습니다.
- 마지막 설정과 하단 내비게이션 사이에 최소 24dp 여백을 두고 작은 화면과 200%
  글자 크기에서도 모든 항목에 접근할 수 있어야 합니다.
- 설정 행은 `ニックネーム`·`性別`·`地域`·`体感の傾向`처럼 상태명을
  사용하고 오른쪽 현재값과 화살표로 편집 가능성을 표현합니다.
- 게스트 카드에는 `ゲストアカウント`와 현재 기기 변경 시 데이터 이전을
  지원하지 않는다는 사실을 안내합니다. OAuth가 준비되기 전 실행 불가능한
  연동 행동은 노출하지 않고 개발 동작은 `開発者向け` 아래에 격리합니다.
- 익명 계정은 복구 경로를 보장할 수 없으므로 로그아웃을 노출하지 않습니다.
- `体感データをリセット`은 계정이 삭제되지 않음을 확인창에 명시하고,
  계정 삭제는 계정에 연결된 기록·설정과 해당 단말의 로컬 데이터가 영구
  삭제되고 복구할 수 없음을 명시합니다. 공용 캐시·운영 로그의 범위는
  공개 개인정보처리방침으로 안내합니다.
- 저장 중에는 메뉴 전체 진행 막대 대신 실행한 행의 끝에만 진행 표시를
  사용하고 나머지 작업의 중복 실행을 막습니다.

### 피드백 (바텀시트)

- Step 1: 최근 8일 중 대상 날짜·필수 외출 시간대 선택
- Step 2: 아우터·상의·하의의 실제 착용 복장 선택
- Step 3: 체감 선택 후 명시적 저장
- 기록이 있는 날짜는 저장값을 복원해 수정하고, 기록이 없는 날짜는 빈 입력
  상태로 시작합니다.
- 완료 → 신규는 "반영했어요!", 수정은 `記録を更新しました` → 닫힘

### 설정 화면

- 별명 변경
- 성별 변경
- 추위/더위 성향 재설정 (변경 시 보정값 초기화 + 확인 팝업)
- 위치 변경 (GPS 재설정 또는 수동 지역 선택)
- 체감 데이터 초기화
- 테마 선택 및 개인정보처리방침 열기
- 아침 추천·저녁 피드백 푸시 사용 여부와 JST 시각 설정
- Apple/Google 계정 연동 상태 표시 코드는 유지하지만 신규 연동 행동은
  운영판에서 비활성화
- 연결 계정 로그아웃
- 계정 삭제

위치 변경에서 서비스 꺼짐·권한 거부·영구 거부를 구분해 단말 설정 또는
수동 선택으로 이동할 수 있는 하단 모달을 표시하고, 단말 설정에서 돌아오면
상태를 다시 확인합니다. 현재 위치의 국가가 일본이 아니거나 국가를 확인할
수 없으면 안내 후 일본 지역 수동 선택 하단 모달을 자동으로 엽니다.

### 복장 아이콘

- 총 16개 UI 에셋: 상의 6 + 하의 4 + 겉옷 5 + 겉옷 없음 1
- 배포 번들에는 96px 기본 이미지와 2x·3x·4x 해상도 변형만 포함하고,
  1254px 원본은 `design_assets/clothing_icons_master/`에 분리합니다.
- 표시 크기와 기기 배율에 맞춘 디코딩 크기를 사용하고 홈의 첫 추천
  3개 아이콘만 선로딩합니다.

### 지원 화면·방향과 모션

- 지원 범위는 스마트폰 `portraitUp`이며 가로모드와 태블릿은 지원하지
  않습니다. Android 네이티브 액티비티와 Flutter 진입점 모두 세로 방향을
  고정하고 iOS 대상 기기군은 iPhone으로 제한합니다.
- 320×568·360×800·390×844·430×932 세로 화면과
  100%·130%·200% 글자 크기에서 주요 입력·분석 화면을 자동 검증합니다.
- Android와 iOS의 표시 이름은 `KISOU`로 통일하고 라이트·다크 테마에
  맞춰 상태 표시줄과 시스템 내비게이션 아이콘 대비를 전환합니다.
- 운영체제의 애니메이션 줄이기 설정이 켜져 있으면 스플래시 페이드와 로딩
  점 순환, 홈 추천 펼침 모션을 즉시 전환으로 대체합니다.

---

## 8. 일본 출시용 개인정보/위치정보

### 수집하는 개인정보

| 데이터 | 분류 | 수집 경로 |
|---|---|---|
| 익명 계정 비밀값 또는 Apple/Google 인증 ID | 인증정보 | 자동 계정 생성/계정 연동 |
| 지원 ID와 삭제 코드 해시·버전 | 계정 삭제 인증정보 | 사용자의 명시적 발급·교체 |
| 별명 | 개인정보 | 온보딩 |
| 성별 | 개인정보 | 온보딩 |
| 위치정보 (위도/경도) | 위치정보 | GPS/수동 |
| 추위/더위 성향 | 개인정보 | 온보딩 |
| 피드백 기록 | 이용 기록 | 앱 사용 중 |
| 보정값 | 이용 기록 | 자동 생성 |
| 여행 장소 코드·출발 일시·알림 선택/상태 | 단말 이용 정보 | 사용자가 입력하며 해당 단말에만 저장, 서버 미전송 |
| FCM 등록 token·Firebase Installation ID | 단말 식별정보 | 사용자가 매일 알림을 켠 단말에서 Firebase가 발급 |
| push install UUID·client revision·플랫폼·앱 버전 | 단말/보안 메타데이터 | 앱 보안 저장소와 기기 등록 API |
| 아침·저녁 사용 여부와 JST 시각 | 계정 설정 | 사용자의 알림 설정 |
| push delivery UUID·type·revision·처리 단계 | 중복 처리 메타데이터 | 서버 발송과 단말 SharedPreferences |

### MVP 필수 구현 사항

**프라이버시 폴리시**

- ChatGPT Sites의 공개 URL
  `https://kisou-pages.znak-llm.chatgpt.site/privacy/`에서 호스팅
- 메뉴의 `プライバシーポリシー`에서 같은 HTTPS URL을 시스템 기본
  외부 브라우저로 표시하고, 열기 실패 시 일본어 오류 안내 제공
- 포함 내용: 수집 항목, 이용 목적, 제3자 제공 여부, 보관 기간, 사용자 권리, 문의처
- Firebase Cloud Messaging/Installations 처리, token/FID 삭제와 외부
  live·backup 삭제에 최대 180일이 걸릴 수 있는 범위, 전달 시각 비보장,
  운영체제 알림 권한을 공개 정책과 스토어 개인정보·데이터 안전 신고에 반영

**위치정보**

- 온보딩에서 사용 목적 설명 후 시스템 권한 요청
- iOS: NSLocationWhenInUseUsageDescription에 일본어 사용 목적 기재
- Android: ACCESS_FINE_LOCATION 또는 ACCESS_COARSE_LOCATION
- "사용 중만" 권한 (백그라운드 불필요)

**계정 삭제**

- 앱 내에서 계정 삭제 가능 (Apple 필수 요구사항)
- 온보딩 전 생성된 익명 계정도 온보딩 화면의 삭제 경로로 제거 가능
- 삭제 시 사용자 프로필과 인증 정보, feedbacks·refresh_tokens를 서버에서
  삭제하고, 성공한 단말의 보안 저장소와 로컬 설정 삭제를 시도합니다.
- 서버 삭제 요청 전에 보안 저장소에 `requested` 전환 단계를 기록하고,
  canonical UUID v4를 하나의 versioned 값으로 원자적으로 기록하고 DELETE
  `Idempotency-Key`로 보냅니다. 앱 재시작은 token보다 이 값을 먼저
  검사하며, JWT가 필요 없는 `POST /account-deletion/status`가 24시간
  영수증의 `completed`를 반환할 때만 UUID를 포함한 `confirmed` 단계로
  전환해 단말 데이터를 지웁니다. 모든 단말 저장소 삭제가 끝날 때까지
  confirmed marker와 UUID를 유지합니다.
- DELETE 401, status 404·429·5xx·파싱 오류·네트워크 오류는 삭제 성공
  증거가 아니므로 marker, token이 아닌 계정 로컬 데이터와 여행 일정을
  보존합니다. 401 interceptor와 동시 세션 만료도 삭제
  marker를 account switch로 덮지 않습니다. 익명 계정은 기존
  `device_secret`으로 같은 계정만 엄격 복원하고 새 guest 생성 fallback은
  사용하지 않습니다. 복원할 수 없으면 로컬 데이터를 보존하고 복구 화면에서
  삭제 완료 상태를 다시 확인할 수 있게 합니다.
- 원계정 세션을 복원할 수 없고 status의 최신 결과가 네트워크 오류나
  429·5xx가 아닌 확정 404일 때만 `이 기기의 데이터만 삭제` 보조 동작을
  표시합니다. 확인 창은 서버 삭제 미확인·서버 데이터 잔존 가능성과 로컬
  삭제를 복구할 수 없음을 명시합니다. 사용자가 확인해도 서버 삭제 성공으로
  표시하거나 DELETE를 다시 보내지 않습니다. 먼저 crash-safe
  `unconfirmedAccountDiscard` marker로 전환한 뒤 여행·알림·테마와
  access/refresh token·익명 `device_secret`·계정 설정을 전부 정리하고
  마지막에 marker를 지웁니다. marker 기록 실패는 기존 삭제 UUID와 로컬
  데이터를 유지하며, 이후 정리 실패나 프로세스 종료는 전용 marker로
  재시작 복구합니다. 일반 로그아웃·계정 전환의 동일 guest 복원 정책과
  섞지 않으며, 정리 성공 뒤에만 새 익명 계정을 시작합니다.
- 서버 삭제 후 단말 저장소 정리에 실패하면 인증 화면으로 전환해 계정은 이미
  삭제됐음을 알리고, 단말 데이터 재삭제 버튼과 앱 재설치 절차를 표시합니다.
- 매일 푸시를 사용한 단말은 계정 삭제 전 더 높은 unregister revision을
  기록하고 FCM auto-init·token·FID를 정리합니다. Firebase 문서상 FID와
  연결된 외부 live·backup 데이터 삭제에는 최대 180일이 걸릴 수 있습니다.
- 사용자 ID를 직접 부여하지 않은 공용 weather_cache, 제한된 운영 로그,
  외부 처리업체가 보유하는 로그·백업은 계정 삭제 대상이 아닙니다. 실제
  보존 상태와 외부 삭제 범위는 공개 개인정보처리방침에 따릅니다.

**ATT (앱 추적 투명성)**

- Firebase Core·Cloud Messaging·Installations는 매일 푸시에 사용하지만
  Firebase Analytics는 설치하지 않았고 native 수집도 비활성화합니다.
  Google Mobile Ads와 UMP는 설치되어 있지만 광고 요청을 비개인화/문맥형으로
  제한하고 앱에서 IDFA나 앱·웹 간 추적을 사용하지 않습니다. 따라서
  `NSUserTrackingUsageDescription`을 선언하지 않고 ATT 팝업도 요청하지
  않습니다.
- 광고를 운영 활성화하기 전 Google SDK의 당시 데이터 처리 명세, UMP
  메시지와 App Store 개인정보 표시·Google Play 데이터 안전 섹션을 다시
  검토합니다. 향후 개인화 광고·분석 또는 추적을 도입한다면 ATT 필요
  여부와 스토어 신고를 함께 갱신합니다.

**데이터 보관**

- 계정에 연결된 프로필·위치 설정·체감 기록·인증 레코드는 계정 존재 기간
  동안 보관하고 계정 삭제 시 삭제합니다.
- 활성 push token과 preference는 계정·설치 등록 기간에 보관하고 all-off,
  로그아웃, 계정 전환, 계정 삭제에서 등록 해제합니다. 앱의 raw token은
  요청 메모리에서만 사용하고 단말 영구 저장에는 SHA-256만 남깁니다.
  Firebase FID 삭제의 외부 완료 범위는 Google 정책상 최대 180일입니다.
- 공용 weather_cache에는 현재 기간 기반 자동 삭제가 없고, 운영 Docker
  로그는 용량 기준으로 순환합니다. Gmail 문의와 외부 기반의 보존 설정을
  포함한 현재 상태와 미확정 사항은 공개 개인정보처리방침에 명시합니다.

**스토어 등록**

- 프라이버시 폴리시 URL
- App Store: 앱 프라이버시 영양 라벨
- Google Play: 데이터 안전 섹션

---

# 현재 UI 구조

- **디자인 시스템:** 오프화이트 배경, 테마 토큰 기반 라이트·다크·시스템 모드, 절제된 그래디언트와 글래스 효과를 사용합니다.
- **시작 상태:** 준비된 콘텐츠를 지연시키지 않도록 스플래시 최소 노출을
  500ms로 제한하고, 1.2초 안에 홈이 준비되지 않으면 앱의 실제 로딩 또는
  오류 화면으로 전환합니다. 시작 문구는 특정 추천 계산을 단정하지 않는
  `データを読み込んでいます`를 사용합니다.
- **오프라인 복구:** 신규 익명 계정 생성 실패는 로그인 화면이 아닌
  원인별 시작 복구 화면으로 표시합니다. 기존 사용자의 홈 조회 실패도
  스플래시에서 반복 재시도하지 않고 홈 오류 상태와 `再試行`를 제공합니다.
  네트워크 인터페이스가 복구되면 한 번 자동 재조회하고, 실제 API 실패는
  계속 오류 처리합니다.
- **공통 셸:** `RootShell`이 홈·예보·메뉴 세 탭, 공통 `KisouTopBar`와
  하단 내비게이션을 관리합니다. 광고는 `ADS_ENABLED=false`가 기본이며
  이때 UMP·광고 SDK 호출과 광고 UI가 없습니다. 명시적으로 활성화하면 UMP
  동의 게이트를 통과한 비개인화 인라인 배너를 예보 콘텐츠 끝에 표시하고,
  서버 기준 날짜 지정 예측 횟수가 0일 때만 사용자가 직접 시작하는
  SSV 리워드 경로를 표시합니다. 숨은 탭·background·no-fill에서는 배너
  공간을 남기지 않습니다.
- **상단 액션:** 홈은 피드백, 예보는 미래 날짜·장소 예측 진입 버튼을 표시하며 메뉴에는 별도 액션이 없습니다.
- **홈:** `今日の服装はこちら` 아래 1순위 추천을 먼저 표시하고 2·3순위는 기본 접힘 상태에서 펼칠 수 있습니다. 모든 카드가 겉옷 → 상의 → 하의 순서를 유지하고 겉옷이 없으면 `アウターなし`를 표시합니다. 체감 안내는 사용자명을 반복하지 않는 `体感予想` 한 문장으로 제공하며 카드 전체에서 개인 분석으로 이동합니다.
- **예보:** `明日の予報`과 `今後3日間`을 연속 배치한 뒤 단말의
  `旅行予定`과 피드백 카드를 둡니다. 최초 로딩 스켈레톤, 당겨서
  새로고침, 원인별 오류와 재시도를 제공합니다. 여행 예정은 오프라인
  SQLite 원본과 JST D-day를 사용하며 별도 관리 화면에서 편집합니다.
  오늘 기록 완료 카드는 왼쪽에 체크 아이콘과
  `記録済み`, 오른쪽에 연필 아이콘과 `記録を編集`을 두며 카드 전체를
  하나의 최소 64dp 터치·시맨틱 버튼으로 사용합니다.
- **메뉴:** 개인 정보 → 체감 → 표시 → 계정 → 법률·지원 순서로 구성하고,
  오버플로가 있을 때만 상단 2dp 스크롤 진행 표시를 제공합니다. 설정명은
  상태 중심 문구를 사용하며 게스트 계정에는 로그아웃을 노출하지 않습니다.
  체감 분석과 앱 정보·라이선스 화면을 제공합니다.
- **피드백:** 날짜·시간, 의류, 체감의 3단계로 나누고 시트 안에서 최근
  8일을 선택해 기존 기록을 복원할 수 있습니다. 추천 복장은 명시적 빠른
  선택으로만 적용하고 체감 선택 뒤 별도 저장 버튼을 사용합니다. 날짜
  목록은 로딩 스켈레톤과 실패·재시도 상태를 가지며 기록을 완전히
  불러오기 전에는 저장하지 않습니다.
- **날짜 전환:** 앱 실행 중 또는 백그라운드 복귀 시 JST 날짜가 바뀌면
  홈·예보·오늘 피드백 상태를 새로 불러오고 여행 예정·알림 outbox를
  재조정합니다. 여행 알림 재조정은 날짜가 바뀌지 않은 foreground 복귀에도
  수행합니다.
- **앱 아이콘:** 시스템 알림을 유발하는 런타임 대체 아이콘 변경 없이 단일 정적 아이콘을 사용합니다.

## 운영 API 연결

- 개발 빌드는 `config/dev.json`의 로컬 API를 사용하고, 운영 빌드는 `config/prod.json`의 `https://kisou.znak99.cloud`를 사용합니다.
- 앱 시작 시 `APP_ENV`와 API URL을 release에서도 제거되지 않는 코드로
  검증합니다. release는 `production`만 허용하고 운영 URL은 host가 있는
  절대 HTTPS URL이어야 하며 사용자 정보·query·fragment를 거부합니다.
- 개발 로그인 UI, 개발 인증 메서드, 스플래시 미리보기와 네트워크 로그는
  debug 모드와 development 환경이 동시에 맞을 때만 활성화합니다.
- Android와 iOS는 `dev` flavor를 `cloud.znak99.kisou.dev`와
  `KISOU Dev`로 분리하고 `prod`는 스토어 식별자
  `cloud.znak99.kisou`와 `KISOU`를 유지합니다. 시작 시 네이티브
  flavor와 `APP_ENV`의 `dev ↔ development`, `prod ↔ production`
  일치를 강제해 운영 식별자로 개발 기능을 실행할 수 없습니다.
- iOS는 `Debug`·`Profile`·`Release` 각각의 dev/prod build
  configuration과 공유 scheme을 사용합니다. dev 전용 Info.plist에만
  로컬 네트워크 설명과 ATS의 로컬 HTTP 허용을 두고 prod Info.plist에는
  두 권한을 포함하지 않습니다. release는 production만 허용하므로
  archive는 prod scheme만 지원합니다.
- iOS UserDefaults와 기본 Keychain access group은 서로 다른 bundle
  ID로 격리합니다. 운영 secure-storage service 이름은 기존 세션을
  보존하고 dev만 별도 service를 사용하며, dev/prod를 잇는 공용
  Keychain group은 구성하지 않습니다.
- push는 환경별 Firebase Android/iOS 앱을 runtime define으로 구성하고
  `PUSH_NOTIFICATIONS_ENABLED=false`를 기본으로 유지합니다. 활성화 전
  Firebase service account·서버 scheduler, Apple Push capability와 APNs
  key 업로드, provisioning을 소유자가 구성하고 Android·iOS 실기기에서
  foreground/background/terminated와 token refresh를 검증합니다. 한번
  활성 배포한 환경은 이후 feature flag를 내려도 이전 설치 cleanup을 위해
  같은 Firebase 식별자를 빌드에 유지합니다.
- 외부 삭제용 코드 원문은 세션 자격정보와 분리한 repository·secure-store
  경로에서 처리합니다. iOS Keychain은 `synchronizable: false`와
  `unlocked_this_device`를 사용하고, Android는 백업 제외와 Keystore 암호화를
  함께 적용합니다. 지원 ID·코드 버전이 서버 descriptor와 맞을 때만 원문을
  읽습니다. 최신 descriptor를 조회하는 load에서 불일치하면 로컬 값을
  제거하고 명시적인 교체 상태로 전환하되, 진행 중이던 이전 세대의 원문
  읽기는 새 버전 저장값을 삭제하지 않고 `null`만 반환합니다. 코드 교체를
  시작하면 진행 중인 원문 읽기·표시·복사도 즉시 무효화합니다.
- 계정 삭제가 서버에서 성공하면 더 이상 존재하지 않는 계정에 logout을
  요청하지 않고 access·refresh token과 익명 `device_secret`, 온보딩·테마·
  날짜 지정 사용량 등 단말 설정을 즉시 삭제합니다. Profile과 온보딩은 같은
  삭제 조정 메서드를 사용합니다. 단말 정리에 실패한 상태는 인증 상태에
  보존해 화면 교체 후에도 재시도·재설치 안내가 사라지지 않습니다. 익명
  계정을 Apple·Google 계정에 연결한 경우에도 더 이상 유효하지 않은
  `device_secret`을 삭제합니다.
- Android release는 debug key로 대체 서명하지 않으며 소유자 서명 설정이
  없으면 산출물을 만들기 전에 실패합니다. 배포용 빌드는 저장소 밖의 upload
  keystore와 인증서 SHA-256 지문을 `android/key.properties`(Git 제외),
  절대경로의 외부 properties 또는 완전한 환경 변수 세트로 제공합니다.
- `scripts/build_android_release.sh`는 AAB 서명자 지문·압축 무결성·운영
  application ID·운영 API URL과 개발 표식 부재를 검증합니다. CI는 명시적으로
  요청한 2일 유효 임시 인증서만 사용하고 검증 직후 AAB를 삭제하며, 소유자
  서명 자료는 거부합니다. 로컬 임시 검증 산출물도
  `KISOU-prod-EPHEMERAL-NOT-FOR-STORE.aab`로 구분합니다.
- 실제 배포 전에는 소유자 upload 인증서 지문을 Play Console 등록값과
  대조하고 소유자 서명 AAB를 실기기·내부 테스트 트랙에서 최종 검증합니다.
- 날짜 지정 예측의 정확 좌표와 날짜는 `POST /forecast/outlook`의 JSON
  본문으로 전송해 프록시·access log의 URL에 위치가 남지 않게 합니다. API는
  모든 access log query를 제거하고 애플리케이션 로그에도 좌표를 기록하지
  않습니다.
- 날짜 지정 스토어 캡처는 `kDebugMode`와 명시적
  `OUTLOOK_SCREENSHOT_FIXTURE=true`가 모두 맞을 때만 Tokyo·JST 8일 뒤를
  선택하고 고정 결과와 메모리 내 3회 사용량을 제공합니다. 이 경로는 API,
  저장된 사용량, UMP·광고 SDK·광고 플랫폼 채널을 건드리지 않으며
  production debug에서도 재현할 수 있지만
  profile·release에서는 define 값과 무관하게 비활성화됩니다. 캡처 결과에는
  `画面イメージ・説明用データ` 배지와 실제 예측에서 사용하는 기상 출처라는
  안내를 함께 표시해, 고정값을 실측 예보로 오인하지 않게 합니다.
- `KISOUについて` 화면에는 Open-Meteo의 CC BY 4.0 이용 조건과 환경성
  열중증 예방정보 사이트의 WBGT 데이터 출처 링크를 항상 표시합니다.
- 홈 날씨·비교, 예보 탭, 날짜 지정 실예보·과거 기후 결과, 체감 분석의
  날씨 포함 상세 기록에는 공통 `WeatherDataAttribution`을 데이터와 같은
  스크롤 맥락에 표시합니다.
  `天気データ: Open‑Meteo`는 제공자 사이트, `CC BY 4.0`은 라이선스
  원문으로 연결하고 `編集・加工あり`로 앱의 집계·변환 사실을 알립니다.
  홈에 환경성 WBGT 값이 있을 때는 같은 맥락에 `暑さ指数: 環境省` 링크도
  표시하고, 값이 없을 때는 관련 없는 출처를 노출하지 않습니다. 각 링크는
  48dp 이상 터치 영역과 독립된 링크 시맨틱을 가지며 외부 앱 열기 실패 시
  `リンクを開けませんでした。`를 표시합니다.
- 운영 API는 별도 MacBook 서버의 Docker Compose에서 실행되며 Cloudflare Tunnel을 통해 공개됩니다.
