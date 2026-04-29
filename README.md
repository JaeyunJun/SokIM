# 속 입력기 (개인 커스텀)

[kiding/SokIM](https://github.com/kiding/SokIM) 기반 개인 사용 목적 포크.

## 원본과의 차이

### 한국어 전용화
- 영문 엔진(QwertyEngine) 및 한/영 전환 로직 제거
- 영문 입력은 macOS 기본 입력기(ABC 등)를 사용
- Caps Lock 이중 용도(짧게=전환, 길게=CapsLock) 제거 — 시스템 기본 동작
- ABC 억제, 보안 입력 자동 전환 등 전환 관련 기능 일괄 제거

### 전역 키 조합 추가
입력기 상태와 무관하게 시스템 전역으로 동작 (CGEventTap 기반):

| 조합 | 출력 |
|------|------|
| Shift + ESC | `~` |
| Cmd + ESC | `` ` `` |
| Cmd + `\` | `₩` |

### 제거된 UI/기능
- 메뉴 막대 상태 표시 및 설정 메뉴
- 자동 업데이트 확인
- "₩ 대신 ` 입력" 옵션 (₩ 키는 항상 ₩, 백틱은 Cmd+ESC로 입력)
- 디버그 모드 토글 (Debug 빌드에서만 자동 로깅)

### 앱별 commit 처리 방식 토글
일부 앱(특히 Electron 기반 — Notion Calendar, Slack 등)에서 한글 입력 중
다른 필드 클릭 시 마지막 글자가 이중 입력되는 문제 대응.

입력 소스 메뉴(메뉴바 입력기 아이콘)에서 현재 frontmost 앱에 대해 두 가지
중 하나를 선택할 수 있다:

- **기본**: NavilIME와 동일한 IMK 표준 방식. `insertText(composed+composing, defaultRange)` 한 번 호출로 marked text를 commit text로 교체. IMK 계약을 정상 구현한 앱(대부분의 네이티브 앱)에선 매끄럽게 동작.
- **수정**: cursor 위치에서 composing 길이만큼 역산한 명시적 `replacementRange`로 영역을 직접 덮어쓰기. OS의 marked text 자동 확정 동작과 무관하게 멱등. Electron처럼 IMK의 `defaultRange` 의미를 무시하는 앱에서 이중 입력을 우회. 단 앱의 `selectedRange()` 신뢰도가 낮으면 의도와 다른 위치를 덮어쓸 위험.

설정은 in-process UserDefaults에 즉시 저장·반영(재시작 불필요).
샌드박스 환경이라 plist는 `~/Library/Containers/com.kiding.inputmethod.sok/Data/Library/Preferences/`에 저장됨.

## 빌드

```bash
xcodebuild -project SokIM.xcodeproj -scheme SokIM -configuration Release build
```

빌드 결과물을 `/Library/Input Methods/SokIM.app`에 복사 후 입력 소스에 추가.

## 원본

- [kiding/SokIM](https://github.com/kiding/SokIM) — 빠르고 매끄러운 한영 전환을 위한 macOS 입력기
