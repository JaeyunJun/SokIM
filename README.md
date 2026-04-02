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

## 빌드

```bash
xcodebuild -project SokIM.xcodeproj -scheme SokIM -configuration Release build
```

빌드 결과물을 `/Library/Input Methods/SokIM.app`에 복사 후 입력 소스에 추가.

## 원본

- [kiding/SokIM](https://github.com/kiding/SokIM) — 빠르고 매끄러운 한영 전환을 위한 macOS 입력기
