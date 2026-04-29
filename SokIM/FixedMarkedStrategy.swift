import InputMethodKit

/**
 MarkedStrategy의 변형 (Solution C):
 - `commit()`에서 composing은 명시적 `replacementRange`로 영역을 직접 교체.
 - cursor 위치에서 composing.utf16.count만큼 역산해 marked 영역으로 추정.
 - marked가 살아있든 OS가 미리 자동 확정해버렸든 같은 영역을 같은 글자로 덮어써서 결과가 항상 단일 문자.

 의존성:
 - OS의 marked text 자동 확정 동작 ❌ (해방됨)
 - 앱의 `selectedRange()` 정확성 ✓ (Electron 등에서 부정확하면 엉뚱한 위치를 덮어쓸 위험)

 backspace/next는 MarkedStrategy와 동일.
 */
struct FixedMarkedStrategy: Strategy {
    static func backspace(from state: State, to sender: IMKTextInput, with composing: String) -> Bool {
        return MarkedStrategy.backspace(from: state, to: sender, with: composing)
    }

    static func next(from state: State, to sender: IMKTextInput, with composing: String) -> Bool {
        return MarkedStrategy.next(from: state, to: sender, with: composing)
    }

    static func commit(from state: State, to sender: IMKTextInput) {
        debug("\(state)")

        // composed: marked 안에 있지 않으므로 표준 경로(defaultRange)
        if state.composed.count > 0 {
            sender.insertText(state.composed, replacementRange: defaultRange)
        }

        // composing: cursor에서 역산한 명시적 영역으로 교체
        if state.composing.count > 0 {
            let selected = sender.selectedRange()
            let count = state.composing.utf16.count
            let location = selected.location - count
            let prevRange: NSRange = location >= 0
                ? NSRange(location: location, length: count)
                : NSRange(location: 0, length: location + count)
            sender.insertText(state.composing, replacementRange: prevRange)
        }
    }
}
