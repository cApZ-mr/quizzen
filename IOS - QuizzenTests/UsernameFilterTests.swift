//
//  UsernameFilterTests.swift
//  IOS - QuizzenTests
//

import Testing
@testable import IOS___Quizzen

@Suite("Benutzernamen-Filter")
struct UsernameFilterTests {
    @Test(arguments: ["Malte", "Tester 001", "QuizKönig", "Torpedo", "Nazir", "Badminton99", "Hanna", "Jonas_2"])
    func erlaubteNamen(_ name: String) {
        #expect(UsernameFilter.validationError(for: name) == nil)
    }

    @Test(arguments: ["fuck", "F.U.C.K", "Hurens0hn", "x_arschloch_x", "sh1t", "N1gger", "Bitch123"])
    func gesperrteNamen(_ name: String) {
        #expect(UsernameFilter.isOffensive(name))
        #expect(UsernameFilter.validationError(for: name) == "Dieser Benutzername ist nicht erlaubt")
    }

    @Test func laenge() {
        #expect(UsernameFilter.validationError(for: "ab") != nil)
        #expect(UsernameFilter.validationError(for: String(repeating: "a", count: 21)) != nil)
        #expect(UsernameFilter.validationError(for: "  abc  ") == nil)
    }
}
