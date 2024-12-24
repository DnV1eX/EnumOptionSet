//
//  EnumOptionSetTests.swift
//  EnumOptionSet
//
//  Created by Alexey Demin on 2024-12-09.
//  Copyright © 2024 DnV1eX. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//

import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

// Macro implementations build for the host, so the corresponding module is not available when cross-compiling. Cross-compiled tests may still make use of the macro itself in end-to-end tests.
#if canImport(EnumOptionSetMacros)
import EnumOptionSetMacros

let testMacros: [String: Macro.Type] = [
    "EnumOptionSet": EnumOptionSetMacro.self,
]
#endif

func rawValueExpandedSource(_ type: String) -> String {
    """
            let rawValue: \(type)
            init(rawValue: \(type)) {
                self.rawValue = rawValue
            }
            /// Creates a new option set with the specified bit index. Asserts on `RawValue` overflow.
            /// - Parameter bitIndex: The index of the `1` bit in the `rawValue` bit mask.
            init(bitIndex: Int) {
                assert((0 ..< RawValue.bitWidth).contains(bitIndex), "Option bit index \\(bitIndex) is out of range for '\(type)'")
                self.init(rawValue: 1 << bitIndex)
            }
    """
}

let defaultMembersExpandedSource = """
            /// `ShippingOption.Set(rawValue: 1 << 0)`
            static let nextDay = Self(bitIndex: 0)
            /// `ShippingOption.Set(rawValue: 1 << 1)`
            static let secondDay = Self(bitIndex: 1)
            /// `ShippingOption.Set(rawValue: 1 << 2)`
            static let priority = Self(bitIndex: 2)
            /// `ShippingOption.Set(rawValue: 1 << 3)`
            static let standard = Self(bitIndex: 3)
    """

let defaultCombinationExpandedSource = """
            /// Combination of all set options.
            static let all: Self = [nextDay, secondDay, priority, standard]
    """

let bitIndicesExpandedSource = """
            /// Set of indices corresponding to the `1` bits in the `rawValue` bit mask.
            var bitIndices: Swift.Set<Int> {
                (0 ..< RawValue.bitWidth).reduce(into: []) { result, bitIndex in
                    if contains(.init(bitIndex: bitIndex)) {
                        result.insert(bitIndex)
                    }
                }
            }
            /// Creates a new option set with the specified bit indices. Asserts on `RawValue` overflow.
            /// - Parameter bitIndices: The set of indices corresponding to the `1` bits in the `rawValue` bit mask.
            init(bitIndices: Swift.Set<Int>) {
                self = bitIndices.reduce(into: []) { result, bitIndex in
                    result.formUnion(.init(bitIndex: bitIndex))
                }
            }
    """

func descriptionExpandedSource(_ names: String) -> String {
    """
            var description: String {
                let names = \(names)
                return "[" + bitIndices.sorted().map { bitIndex in
                    names[bitIndex] ?? "\\(bitIndex)"
                } .joined(separator: ", ") + "]"
            }
            var debugDescription: String {
                "OptionSet(\\(rawValue.binaryString))"
            }
    """
}

func optionsExpandedSource(_ options: String) -> String {
    """
            /// Array of `ShippingOption` enum cases in the `rawValue` bit mask, ordered by declaration.
            var options: [ShippingOption] {
                \(options).reduce(into: []) { result, option in
                    if contains(option.0) {
                        result.append(option.1)
                    }
                }
            }
            /// Creates a new option set with the specified array of `ShippingOption` enum cases.
            /// - Parameter options: The array of `ShippingOption` enum cases corresponding to the `rawValue` bit mask.
            init(options: [ShippingOption]) {
                self = \(options).reduce(into: []) { result, option in
                    if options.contains(option.1) {
                        result.formUnion(option.0)
                    }
                }
            }
    """
}

let defaultSetStructExpandedSource = """
        struct Set: OptionSet, CustomStringConvertible, CustomDebugStringConvertible {
    \(rawValueExpandedSource("Int"))
    \(defaultMembersExpandedSource)
    \(defaultCombinationExpandedSource)
    \(bitIndicesExpandedSource)
    \(descriptionExpandedSource(#"[0: "nextDay", 1: "secondDay", 2: "priority", 3: "standard"]"#))
    \(optionsExpandedSource("[(Self.nextDay, ShippingOption.nextDay), (Self.secondDay, ShippingOption.secondDay), (Self.priority, ShippingOption.priority), (Self.standard, ShippingOption.standard)]"))
        }
    """

let publicEnumExpandedSource = #"""
    public enum ShippingOption {
        case nextDay, secondDay, priority, standard

        public struct Set: OptionSet, Sendable, CustomStringConvertible, CustomDebugStringConvertible {
            public let rawValue: UInt8
            public init(rawValue: UInt8) {
                self.rawValue = rawValue
            }
            /// Creates a new option set with the specified bit index. Asserts on `RawValue` overflow.
            /// - Parameter bitIndex: The index of the `1` bit in the `rawValue` bit mask.
            public init(bitIndex: Int) {
                assert((0 ..< RawValue.bitWidth).contains(bitIndex), "Option bit index \(bitIndex) is out of range for 'UInt8'")
                self.init(rawValue: 1 << bitIndex)
            }
            /// `ShippingOption.Set(rawValue: 1 << 0)`
            public static let nextDay = Self(bitIndex: 0)
            /// `ShippingOption.Set(rawValue: 1 << 1)`
            public static let secondDay = Self(bitIndex: 1)
            /// `ShippingOption.Set(rawValue: 1 << 2)`
            public static let priority = Self(bitIndex: 2)
            /// `ShippingOption.Set(rawValue: 1 << 3)`
            public static let standard = Self(bitIndex: 3)
            /// Combination of all set options.
            public static let all: Self = [nextDay, secondDay, priority, standard]
            /// Set of indices corresponding to the `1` bits in the `rawValue` bit mask.
            public var bitIndices: Swift.Set<Int> {
                (0 ..< RawValue.bitWidth).reduce(into: []) { result, bitIndex in
                    if contains(.init(bitIndex: bitIndex)) {
                        result.insert(bitIndex)
                    }
                }
            }
            /// Creates a new option set with the specified bit indices. Asserts on `RawValue` overflow.
            /// - Parameter bitIndices: The set of indices corresponding to the `1` bits in the `rawValue` bit mask.
            public init(bitIndices: Swift.Set<Int>) {
                self = bitIndices.reduce(into: []) { result, bitIndex in
                    result.formUnion(.init(bitIndex: bitIndex))
                }
            }
            public var description: String {
                let names = [0: "nextDay", 1: "secondDay", 2: "priority", 3: "standard"]
                return "[" + bitIndices.sorted().map { bitIndex in
                    names[bitIndex] ?? "\(bitIndex)"
                } .joined(separator: ", ") + "]"
            }
            public var debugDescription: String {
                "OptionSet(\(rawValue.binaryString))"
            }
            /// Array of `ShippingOption` enum cases in the `rawValue` bit mask, ordered by declaration.
            public var options: [ShippingOption] {
                [(Self.nextDay, ShippingOption.nextDay), (Self.secondDay, ShippingOption.secondDay), (Self.priority, ShippingOption.priority), (Self.standard, ShippingOption.standard)].reduce(into: []) { result, option in
                    if contains(option.0) {
                        result.append(option.1)
                    }
                }
            }
            /// Creates a new option set with the specified array of `ShippingOption` enum cases.
            /// - Parameter options: The array of `ShippingOption` enum cases corresponding to the `rawValue` bit mask.
            public init(options: [ShippingOption]) {
                self = [(Self.nextDay, ShippingOption.nextDay), (Self.secondDay, ShippingOption.secondDay), (Self.priority, ShippingOption.priority), (Self.standard, ShippingOption.standard)].reduce(into: []) { result, option in
                    if options.contains(option.1) {
                        result.formUnion(option.0)
                    }
                }
            }
        }
    }
    """#

final class EnumOptionSetTests: XCTestCase {

    func testMacroWithAssociatedValuesEnum() throws {
        #if canImport(EnumOptionSetMacros)
        assertMacroExpansion(
            """
            @EnumOptionSet
            enum ShippingOption {
                case nextDay, secondDay(String), priority, standard
            }
            """,
            expandedSource: """
            enum ShippingOption {
                case nextDay, secondDay(String), priority, standard

                struct Set: OptionSet, CustomStringConvertible, CustomDebugStringConvertible {
            \(rawValueExpandedSource("Int"))
            \(defaultMembersExpandedSource)
            \(defaultCombinationExpandedSource)
            \(bitIndicesExpandedSource)
            \(descriptionExpandedSource(#"[0: "nextDay", 1: "secondDay", 2: "priority", 3: "standard"]"#))
                }
            }
            """,
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    func testMacroWithStringRawValueEnum() throws {
        #if canImport(EnumOptionSetMacros)
        assertMacroExpansion(
            """
            @EnumOptionSet
            enum ShippingOption: String {
                case nextDay = "1" // Should be ignored.
                case secondDay
                case priority
                case standard
            }
            """,
            expandedSource: """
            enum ShippingOption: String {
                case nextDay = "1" // Should be ignored.
                case secondDay
                case priority
                case standard

            \(defaultSetStructExpandedSource)
            }
            """,
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    func testMacroWithIntRawValueEnum() throws {
        #if canImport(EnumOptionSetMacros)
        assertMacroExpansion(
            """
            @EnumOptionSet
            enum ShippingOption: Int {
                case nextDay, secondDay, priority = 3, standard
            }
            """,
            expandedSource: """
            enum ShippingOption: Int {
                case nextDay, secondDay, priority = 3, standard

                struct Set: OptionSet, CustomStringConvertible, CustomDebugStringConvertible {
            \(rawValueExpandedSource("Int"))
                    /// `ShippingOption.Set(rawValue: 1 << 0)`
                    static let nextDay = Self(bitIndex: 0)
                    /// `ShippingOption.Set(rawValue: 1 << 1)`
                    static let secondDay = Self(bitIndex: 1)
                    /// `ShippingOption.Set(rawValue: 1 << 3)`
                    static let priority = Self(bitIndex: 3)
                    /// `ShippingOption.Set(rawValue: 1 << 4)`
                    static let standard = Self(bitIndex: 4)
            \(defaultCombinationExpandedSource)
            \(bitIndicesExpandedSource)
            \(descriptionExpandedSource(#"[0: "nextDay", 1: "secondDay", 3: "priority", 4: "standard"]"#))
            \(optionsExpandedSource("[(Self.nextDay, ShippingOption.nextDay), (Self.secondDay, ShippingOption.secondDay), (Self.priority, ShippingOption.priority), (Self.standard, ShippingOption.standard)]"))
                }
            }
            """,
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    func testMacroWithPrivateCaseIterableEnum() throws {
        #if canImport(EnumOptionSetMacros)
        assertMacroExpansion(
            """
            @EnumOptionSet
            private enum ShippingOption: CaseIterable {
                case nextDay, secondDay, priority, standard
            }
            """,
            expandedSource: """
            private enum ShippingOption: CaseIterable {
                case nextDay, secondDay, priority, standard

            \(defaultSetStructExpandedSource)
            }
            """,
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    func testTypeGenericMacroWithPublicEnum() throws {
        #if canImport(EnumOptionSetMacros)
        assertMacroExpansion(
            """
            @EnumOptionSet<UInt8>
            public enum ShippingOption {
                case nextDay, secondDay, priority, standard
            }
            """,
            expandedSource: publicEnumExpandedSource,
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    func testTypeArgumentMacroWithPublicEnum() throws {
        #if canImport(EnumOptionSetMacros)
        assertMacroExpansion(
            """
            @EnumOptionSet(UInt8.self)
            public enum ShippingOption {
                case nextDay, secondDay, priority, standard
            }
            """,
            expandedSource: publicEnumExpandedSource,
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    func testMacroWithAllCaseEnumWarningAndFixIt() throws {
        #if canImport(EnumOptionSetMacros)
        assertMacroExpansion(
            """
            @EnumOptionSet
            enum ShippingOption {
                case nextDay, secondDay, priority, standard, all
            }
            """,
            expandedSource: """
            enum ShippingOption {
                case nextDay, secondDay, priority, standard, all

                struct Set: OptionSet, CustomStringConvertible, CustomDebugStringConvertible {
            \(rawValueExpandedSource("Int"))
            \(defaultMembersExpandedSource)
                    /// `ShippingOption.Set(rawValue: 1 << 4)`
                    static let all = Self(bitIndex: 4)
            \(bitIndicesExpandedSource)
            \(descriptionExpandedSource(#"[0: "nextDay", 1: "secondDay", 2: "priority", 3: "standard", 4: "all"]"#))
            \(optionsExpandedSource("[(Self.nextDay, ShippingOption.nextDay), (Self.secondDay, ShippingOption.secondDay), (Self.priority, ShippingOption.priority), (Self.standard, ShippingOption.standard), (Self.all, ShippingOption.all)]"))
                }
            }
            """,
            diagnostics: [.init(message: "'all' is used as a distinct option, not a combination of all options",
                                line: 3,
                                column: 50,
                                severity: .warning,
                                fixIts: [.init(message: "Add backticks to silence the warning")])],
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    func testMacroWithEscapedAllCaseEnum() throws {
        #if canImport(EnumOptionSetMacros)
        assertMacroExpansion(
            """
            @EnumOptionSet
            enum ShippingOption {
                case nextDay, secondDay, priority, standard, `all`
            }
            """,
            expandedSource: """
            enum ShippingOption {
                case nextDay, secondDay, priority, standard, `all`

                struct Set: OptionSet, CustomStringConvertible, CustomDebugStringConvertible {
            \(rawValueExpandedSource("Int"))
            \(defaultMembersExpandedSource)
                    /// `ShippingOption.Set(rawValue: 1 << 4)`
                    static let `all` = Self(bitIndex: 4)
            \(bitIndicesExpandedSource)
            \(descriptionExpandedSource(#"[0: "nextDay", 1: "secondDay", 2: "priority", 3: "standard", 4: "`all`"]"#))
            \(optionsExpandedSource("[(Self.nextDay, ShippingOption.nextDay), (Self.secondDay, ShippingOption.secondDay), (Self.priority, ShippingOption.priority), (Self.standard, ShippingOption.standard), (Self.`all`, ShippingOption.`all`)]"))
                }
            }
            """,
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    func testExplicitTypeMacroOverflowError() throws {
        #if canImport(EnumOptionSetMacros)
        assertMacroExpansion(
            """
            @EnumOptionSet<UInt8>
            enum ShippingOption {
                case nextDay, secondDay, priority = 7, standard
            }
            """,
            expandedSource: """
            enum ShippingOption {
                case nextDay, secondDay, priority = 7, standard

                struct Set: OptionSet, CustomStringConvertible, CustomDebugStringConvertible {
            \(rawValueExpandedSource("UInt8"))
                    /// `ShippingOption.Set(rawValue: 1 << 0)`
                    static let nextDay = Self(bitIndex: 0)
                    /// `ShippingOption.Set(rawValue: 1 << 1)`
                    static let secondDay = Self(bitIndex: 1)
                    /// `ShippingOption.Set(rawValue: 1 << 7)`
                    static let priority = Self(bitIndex: 7)
                    /// `ShippingOption.Set(rawValue: 1 << 8)`
                    static let standard = Self(bitIndex: 8)
            \(defaultCombinationExpandedSource)
            \(bitIndicesExpandedSource)
            \(descriptionExpandedSource(#"[0: "nextDay", 1: "secondDay", 7: "priority", 8: "standard"]"#))
            \(optionsExpandedSource("[(Self.nextDay, ShippingOption.nextDay), (Self.secondDay, ShippingOption.secondDay), (Self.priority, ShippingOption.priority), (Self.standard, ShippingOption.standard)]"))
                }
            }
            """,
            diagnostics: [.init(message: "Option bit index 8 is out of range for 'UInt8'",
                                line: 3,
                                column: 44,
                                severity: .warning,
                                fixIts: [.init(message: "Ignore the bit mask overflow")])],
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    func testDefaultTypeMacroOverflowError() throws {
        #if canImport(EnumOptionSetMacros)
        assertMacroExpansion(
            """
            @EnumOptionSet
            enum ShippingOption {
                case nextDay, secondDay, priority = 63, standard
            }
            """,
            expandedSource: """
            enum ShippingOption {
                case nextDay, secondDay, priority = 63, standard

                struct Set: OptionSet, CustomStringConvertible, CustomDebugStringConvertible {
            \(rawValueExpandedSource("Int"))
                    /// `ShippingOption.Set(rawValue: 1 << 0)`
                    static let nextDay = Self(bitIndex: 0)
                    /// `ShippingOption.Set(rawValue: 1 << 1)`
                    static let secondDay = Self(bitIndex: 1)
                    /// `ShippingOption.Set(rawValue: 1 << 63)`
                    static let priority = Self(bitIndex: 63)
                    /// `ShippingOption.Set(rawValue: 1 << 64)`
                    static let standard = Self(bitIndex: 64)
            \(defaultCombinationExpandedSource)
            \(bitIndicesExpandedSource)
            \(descriptionExpandedSource(#"[0: "nextDay", 1: "secondDay", 63: "priority", 64: "standard"]"#))
            \(optionsExpandedSource("[(Self.nextDay, ShippingOption.nextDay), (Self.secondDay, ShippingOption.secondDay), (Self.priority, ShippingOption.priority), (Self.standard, ShippingOption.standard)]"))
                }
            }
            """,
            diagnostics: [.init(message: "Option bit index 64 is out of range for 'Int'",
                                line: 3,
                                column: 45,
                                severity: .warning,
                                fixIts: [.init(message: "Ignore the bit mask overflow")])],
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    func testCheckOverflowFalseArgumentMacro() throws {
        #if canImport(EnumOptionSetMacros)
        assertMacroExpansion(
            """
            @EnumOptionSet(checkOverflow: false)
            enum ShippingOption {
                case nextDay, secondDay, priority = 63, standard
            }
            """,
            expandedSource: """
            enum ShippingOption {
                case nextDay, secondDay, priority = 63, standard

                struct Set: OptionSet, CustomStringConvertible, CustomDebugStringConvertible {
                    let rawValue: Int
                    init(rawValue: Int) {
                        self.rawValue = rawValue
                    }
                    /// Creates a new option set with the specified bit index.
                    /// - Parameter bitIndex: The index of the `1` bit in the `rawValue` bit mask.
                    init(bitIndex: Int) {
                        self.init(rawValue: 1 << bitIndex)
                    }
                    /// `ShippingOption.Set(rawValue: 1 << 0)`
                    static let nextDay = Self(bitIndex: 0)
                    /// `ShippingOption.Set(rawValue: 1 << 1)`
                    static let secondDay = Self(bitIndex: 1)
                    /// `ShippingOption.Set(rawValue: 1 << 63)`
                    static let priority = Self(bitIndex: 63)
                    /// `ShippingOption.Set(rawValue: 1 << 64)`
                    static let standard = Self(bitIndex: 64)
            \(defaultCombinationExpandedSource)
                    /// Set of indices corresponding to the `1` bits in the `rawValue` bit mask.
                    var bitIndices: Swift.Set<Int> {
                        (0 ..< RawValue.bitWidth).reduce(into: []) { result, bitIndex in
                            if contains(.init(bitIndex: bitIndex)) {
                                result.insert(bitIndex)
                            }
                        }
                    }
                    /// Creates a new option set with the specified bit indices.
                    /// - Parameter bitIndices: The set of indices corresponding to the `1` bits in the `rawValue` bit mask.
                    init(bitIndices: Swift.Set<Int>) {
                        self = bitIndices.reduce(into: []) { result, bitIndex in
                            result.formUnion(.init(bitIndex: bitIndex))
                        }
                    }
            \(descriptionExpandedSource(#"[0: "nextDay", 1: "secondDay", 63: "priority", 64: "standard"]"#))
            \(optionsExpandedSource("[(Self.nextDay, ShippingOption.nextDay), (Self.secondDay, ShippingOption.secondDay), (Self.priority, ShippingOption.priority), (Self.standard, ShippingOption.standard)]"))
                }
            }
            """,
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    func testGenerateDescriptionFalseArgumentMacro() throws {
        #if canImport(EnumOptionSetMacros)
        assertMacroExpansion(
            """
            @EnumOptionSet(generateDescription: false)
            enum ShippingOption {
                case nextDay, secondDay, priority, standard
            }
            """,
            expandedSource: """
            enum ShippingOption {
                case nextDay, secondDay, priority, standard

                struct Set: OptionSet {
            \(rawValueExpandedSource("Int"))
            \(defaultMembersExpandedSource)
            \(defaultCombinationExpandedSource)
            \(bitIndicesExpandedSource)
            \(optionsExpandedSource("[(Self.nextDay, ShippingOption.nextDay), (Self.secondDay, ShippingOption.secondDay), (Self.priority, ShippingOption.priority), (Self.standard, ShippingOption.standard)]"))
                }
            }
            """,
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    func testNonBoolLiteralArgumentMacroErrorAndFixIts() throws {
        #if canImport(EnumOptionSetMacros)
        assertMacroExpansion(
            """
            let b = false
            @EnumOptionSet(checkOverflow: b)
            enum ShippingOption {
                case nextDay, secondDay, priority, standard
            }
            """,
            expandedSource: """
            let b = false
            enum ShippingOption {
                case nextDay, secondDay, priority, standard
            }
            """,
            diagnostics: [.init(message: "'checkOverflow' argument must be a boolean literal",
                                line: 2,
                                column: 31,
                                fixIts: [.init(message: "'checkOverflow' argument must be a boolean literal"),
                                         .init(message: "Remove the 'checkOverflow' argument")])],
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    func testMacroWithNonEnumStructErrorAndFixIt() throws {
        #if canImport(EnumOptionSetMacros)
        assertMacroExpansion(
            """
            @EnumOptionSet
            struct ShippingOption {
            }
            """,
            expandedSource: """
            struct ShippingOption {
            }
            """,
            diagnostics: [.init(message: "@EnumOptionSet can only be applied to 'enum'",
                                line: 2,
                                column: 1,
                                fixIts: [.init(message: "@EnumOptionSet can only be applied to 'enum'")])],
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    func testMacroWithEmptyEnum() throws {
        #if canImport(EnumOptionSetMacros)
        assertMacroExpansion(
            """
            @EnumOptionSet
            enum ShippingOption {
            }
            """,
            expandedSource: """
            enum ShippingOption {

                struct Set: OptionSet, CustomStringConvertible, CustomDebugStringConvertible {
            \(rawValueExpandedSource("Int"))
                    /// Combination of all set options.
                    static let all: Self = []
            \(bitIndicesExpandedSource)
            \(descriptionExpandedSource("[]"))
            \(optionsExpandedSource("[]"))
                }
            }
            """,
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }
}
