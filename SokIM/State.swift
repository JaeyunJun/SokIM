import Cocoa
import Foundation

let defaultRange = NSRange(location: NSNotFound, length: 0)

/** 입력 상태 및 변화 */
struct State: CustomStringConvertible {
    init() {}

    // MARK: - Input

    /** modifier 키 눌림 상태 (InputMonitor와 유사) */
    var modifier: [ModifierUsage: InputType] = [:]

    /** Input 처리에서 도출된 Caps Lock 키 활성화 상태 */
    private var isCapsLockOn = false

    /** 현재 눌려있는 Input, 반복 입력 시 사용 */
    private(set) var down: Input?

    /** 새로운 Input 입력 처리 */
    mutating func next(_ input: Input) {
        debug("\(input)")

        let (usage, type) = (input.usage, input.type)

        // usage가 modifier인 경우
        if let key = ModifierUsage(rawValue: usage) {
            modifier[key] = type

            // Caps Lock: 일반 반전 처리
            if (type, key) == (.keyDown, .capsLock) {
                isCapsLockOn.toggle()
            }
        }
        // 그 외 경우 중 keyDown인 경우
        else if type == .keyDown {
            // 눌린 키를 down에 기록
            down = input

            // Command, Shift, Option, Control
            let isCommandDown = modifier[.leftCommand] == .keyDown || modifier[.rightCommand] == .keyDown
            let isShiftDown = modifier[.leftShift] == .keyDown || modifier[.rightShift] == .keyDown
            let isOptionDown = modifier[.leftOption] == .keyDown || modifier[.rightOption] == .keyDown
            let isControlDown = modifier[.leftControl] == .keyDown || modifier[.rightControl] == .keyDown

            // Control, Command: keyDown 상태인 경우 키 무시
            if isControlDown || isCommandDown {
                debug("Input ignored: \(input) \(modifier)")

                return
            }

            // engine으로 현재 input을 tuple로 변환 가능하면
            if let tuple = engine.usageToTuple(usage, isOptionDown, isShiftDown, isCapsLockOn) {
                // 입력 진행
                next(tuple)
            }
            // 그 외 모든 경우
            else {
                debug("Input ignored: \(input)")
            }
        }
        // 그 외 경우 중 keyUp인 경우
        else if type == .keyUp {
            // 같은 키면 down 삭제
            if down?.usage == input.usage {
                down = nil
            }
        }
        // 그 외 경우
        else {
            debug("Input ignored: \(input)")
        }
    }

    /** NSEvent의 modifier 상태로 동기화 (HID keyUp 누락 복구) */
    mutating func syncModifiers(with flags: NSEvent.ModifierFlags) {
        if !flags.contains(.option) {
            modifier[.leftOption] = nil
            modifier[.rightOption] = nil
        }
        if !flags.contains(.shift) {
            modifier[.leftShift] = nil
            modifier[.rightShift] = nil
        }
        if !flags.contains(.control) {
            modifier[.leftControl] = nil
            modifier[.rightControl] = nil
        }
        if !flags.contains(.command) {
            modifier[.leftCommand] = nil
            modifier[.rightCommand] = nil
        }
    }

    // MARK: - KeyboardEngine

    let engine: Engine.Type = TwoSetEngine.self

    // MARK: - CharTuple

    /** 완성 */
    private(set) var composed: String = ""  // å / å  / åé  |   /
    /** 조합 */
    private(set) var composing: String = "" //   / ´  /     | ㄱ / 가

    // TODO: 세벌식 모아치기 (두 글자 이상 조합) 지원
    // TODO: combineChars(String, Character)?
    /** 새로운 CharTuple 입력 처리 */
    mutating func next(_ tuple: CharTuple) {
        debug("\(tuple)")

        let (inputChar, inputMarked) = tuple
        let markedChar = composing.last
        var nextText: String

        // 조합 중인 마지막 글자가 있으면 새로 입력된 글자와 합치기
        if markedChar != nil {
            nextText = engine.combineChars(markedChar!, inputChar)
        }
        // 없으면 새로 입력된 글자 그대로 사용
        else {
            nextText = "\(inputChar)"
        }

        // 새로 입력된 글자가 이후 조합을 허용하면 조합으로 저장
        if inputMarked {
            composing = "\(nextText.popLast() ?? "?")"
        }
        // 아니면 조합 비움
        else {
            composing = ""
        }

        // 완성 갱신
        composed += nextText
    }

    /** 완성/조합 버림 */
    mutating func clear(composed includeComposed: Bool, composing includeComposing: Bool) {
        debug("composed: \(includeComposed), composing: \(includeComposing)")

        if includeComposed {
            composed = ""
        }

        if includeComposing {
            composing = ""
        }
    }

    mutating func backspaceComposing() {
        debug()

        // 조합에서 마지막 글자를 꺼냈을 때, 글자가 있다면
        if let oldLast = composing.popLast() {
            debug("oldLast: \(oldLast)")

            // engine을 통해 뒤로 삭제, 이후에도 글자가 남아있으면
            if let newLast = engine.backspaceComposing(oldLast) {
                debug("newLast: \(newLast)")

                // 다시 조합에 붙임
                composing += "\(newLast)"
            }
        }
    }

    // MARK: - CustomStringConvertible

    var description: String { "\(engine) '\(composed)' [\(composing)] \(modifier)" }
}
