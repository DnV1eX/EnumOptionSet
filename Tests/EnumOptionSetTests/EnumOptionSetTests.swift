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

final class EnumOptionSetTests: XCTestCase {
    
    func testDefaultTypeAndArgumentsMacroWithBasicEnum() throws {
        #if canImport(EnumOptionSetMacros)
        assertMacroExpansion(
            #"""
            @EnumOptionSet
            enum ShippingOption {
                case nextDay, secondDay, priority, standard
            }
            """#,
            expandedSource: #"""
            enum ShippingOption {
                case nextDay, secondDay, priority, standard

                struct Set: OptionSet, Sendable, CustomStringConvertible, CustomDebugStringConvertible {
                    let rawValue: Int
                    init(rawValue: Int) {
                        self.rawValue = rawValue
                    }
                    /// Creates a new option set with the specified bit index. Asserts on `RawValue` overflow.
                    /// - Parameter bitIndex: The bit index in the `RawValue` bit mask.
                    init(bitIndex: Int) {
                        assert(bitIndex < RawValue.bitWidth, "Option bit index \(bitIndex) exceeds the size of 'Int'")
                        self.init(rawValue: 1 << bitIndex)
                    }
                    /// `ShippingOption.Set(rawValue: 1 << 0)`
                    static let nextDay = Self(bitIndex: 0)
                    /// `ShippingOption.Set(rawValue: 1 << 1)`
                    static let secondDay = Self(bitIndex: 1)
                    /// `ShippingOption.Set(rawValue: 1 << 2)`
                    static let priority = Self(bitIndex: 2)
                    /// `ShippingOption.Set(rawValue: 1 << 3)`
                    static let standard = Self(bitIndex: 3)
                    /// Combination of all set options.
                    static let all: Self = [.nextDay, .secondDay, .priority, .standard]
                    /// Array of `ShippingOption` enum cases in the `rawValue` bit mask, ordered by declaration.
                    var options: [ShippingOption] {
                        [(0, ShippingOption.nextDay), (1, ShippingOption.secondDay), (2, ShippingOption.priority), (3, ShippingOption.standard)].filter {
                            1 << $0.0 & rawValue != 0
                        } .map(\.1)
                    }
                    var description: String {
                        "[\(options.map { "\($0)" } .joined(separator: ", "))]"
                    }
                    var debugDescription: String {
                        "OptionSet(\(rawValue.binaryString))"
                    }
                }
            }
            """#,
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    func testMacroWithIntRawValueCaseIterablePrivateEnum() throws {
        #if canImport(EnumOptionSetMacros)
        assertMacroExpansion(
            #"""
            @EnumOptionSet
            private enum ShippingOption: Int, CaseIterable {
                case nextDay, secondDay, priority = 3, standard
            }
            """#,
            expandedSource: #"""
            private enum ShippingOption: Int, CaseIterable {
                case nextDay, secondDay, priority = 3, standard

                struct Set: OptionSet, Sendable, CustomStringConvertible, CustomDebugStringConvertible {
                    let rawValue: Int
                    init(rawValue: Int) {
                        self.rawValue = rawValue
                    }
                    /// Creates a new option set with the specified bit index. Asserts on `RawValue` overflow.
                    /// - Parameter bitIndex: The bit index in the `RawValue` bit mask.
                    init(bitIndex: Int) {
                        assert(bitIndex < RawValue.bitWidth, "Option bit index \(bitIndex) exceeds the size of 'Int'")
                        self.init(rawValue: 1 << bitIndex)
                    }
                    /// `ShippingOption.Set(rawValue: 1 << 0)`
                    static let nextDay = Self(bitIndex: 0)
                    /// `ShippingOption.Set(rawValue: 1 << 1)`
                    static let secondDay = Self(bitIndex: 1)
                    /// `ShippingOption.Set(rawValue: 1 << 3)`
                    static let priority = Self(bitIndex: 3)
                    /// `ShippingOption.Set(rawValue: 1 << 4)`
                    static let standard = Self(bitIndex: 4)
                    /// Combination of all set options.
                    static let all: Self = [.nextDay, .secondDay, .priority, .standard]
                    /// Array of `ShippingOption` enum cases in the `rawValue` bit mask, ordered by declaration.
                    var options: [ShippingOption] {
                        [(0, ShippingOption.nextDay), (1, ShippingOption.secondDay), (3, ShippingOption.priority), (4, ShippingOption.standard)].filter {
                            1 << $0.0 & rawValue != 0
                        } .map(\.1)
                    }
                    var description: String {
                        "[\(options.map { "\($0)" } .joined(separator: ", "))]"
                    }
                    var debugDescription: String {
                        "OptionSet(\(rawValue.binaryString))"
                    }
                }
            }
            """#,
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    func testTypeGenericMacroWithPublicEnum() throws {
        #if canImport(EnumOptionSetMacros)
        assertMacroExpansion(
            #"""
            @EnumOptionSet<UInt8>
            public enum ShippingOption {
                case nextDay, secondDay, priority, standard
            }
            """#,
            expandedSource: #"""
            public enum ShippingOption {
                case nextDay, secondDay, priority, standard

                public struct Set: OptionSet, Sendable, CustomStringConvertible, CustomDebugStringConvertible {
                    public let rawValue: UInt8
                    public init(rawValue: UInt8) {
                        self.rawValue = rawValue
                    }
                    /// Creates a new option set with the specified bit index. Asserts on `RawValue` overflow.
                    /// - Parameter bitIndex: The bit index in the `RawValue` bit mask.
                    public init(bitIndex: Int) {
                        assert(bitIndex < RawValue.bitWidth, "Option bit index \(bitIndex) exceeds the size of 'UInt8'")
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
                    public static let all: Self = [.nextDay, .secondDay, .priority, .standard]
                    /// Array of `ShippingOption` enum cases in the `rawValue` bit mask, ordered by declaration.
                    public var options: [ShippingOption] {
                        [(0, ShippingOption.nextDay), (1, ShippingOption.secondDay), (2, ShippingOption.priority), (3, ShippingOption.standard)].filter {
                            1 << $0.0 & rawValue != 0
                        } .map(\.1)
                    }
                    public var description: String {
                        "[\(options.map { "\($0)" } .joined(separator: ", "))]"
                    }
                    public var debugDescription: String {
                        "OptionSet(\(rawValue.binaryString))"
                    }
                }
            }
            """#,
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    func testTypeArgumentMacroWithPublicEnum() throws {
        #if canImport(EnumOptionSetMacros)
        assertMacroExpansion(
            #"""
            @EnumOptionSet(UInt8.self)
            public enum ShippingOption {
                case nextDay, secondDay, priority, standard
            }
            """#,
            expandedSource: #"""
            public enum ShippingOption {
                case nextDay, secondDay, priority, standard

                public struct Set: OptionSet, Sendable, CustomStringConvertible, CustomDebugStringConvertible {
                    public let rawValue: UInt8
                    public init(rawValue: UInt8) {
                        self.rawValue = rawValue
                    }
                    /// Creates a new option set with the specified bit index. Asserts on `RawValue` overflow.
                    /// - Parameter bitIndex: The bit index in the `RawValue` bit mask.
                    public init(bitIndex: Int) {
                        assert(bitIndex < RawValue.bitWidth, "Option bit index \(bitIndex) exceeds the size of 'UInt8'")
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
                    public static let all: Self = [.nextDay, .secondDay, .priority, .standard]
                    /// Array of `ShippingOption` enum cases in the `rawValue` bit mask, ordered by declaration.
                    public var options: [ShippingOption] {
                        [(0, ShippingOption.nextDay), (1, ShippingOption.secondDay), (2, ShippingOption.priority), (3, ShippingOption.standard)].filter {
                            1 << $0.0 & rawValue != 0
                        } .map(\.1)
                    }
                    public var description: String {
                        "[\(options.map { "\($0)" } .joined(separator: ", "))]"
                    }
                    public var debugDescription: String {
                        "OptionSet(\(rawValue.binaryString))"
                    }
                }
            }
            """#,
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    func testMacroWithAllCaseEnumWarningAndFixIt() throws {
        #if canImport(EnumOptionSetMacros)
        assertMacroExpansion(
            #"""
            @EnumOptionSet
            enum ShippingOption {
                case nextDay, secondDay, priority, standard, all
            }
            """#,
            expandedSource: #"""
            enum ShippingOption {
                case nextDay, secondDay, priority, standard, all

                struct Set: OptionSet, Sendable, CustomStringConvertible, CustomDebugStringConvertible {
                    let rawValue: Int
                    init(rawValue: Int) {
                        self.rawValue = rawValue
                    }
                    /// Creates a new option set with the specified bit index. Asserts on `RawValue` overflow.
                    /// - Parameter bitIndex: The bit index in the `RawValue` bit mask.
                    init(bitIndex: Int) {
                        assert(bitIndex < RawValue.bitWidth, "Option bit index \(bitIndex) exceeds the size of 'Int'")
                        self.init(rawValue: 1 << bitIndex)
                    }
                    /// `ShippingOption.Set(rawValue: 1 << 0)`
                    static let nextDay = Self(bitIndex: 0)
                    /// `ShippingOption.Set(rawValue: 1 << 1)`
                    static let secondDay = Self(bitIndex: 1)
                    /// `ShippingOption.Set(rawValue: 1 << 2)`
                    static let priority = Self(bitIndex: 2)
                    /// `ShippingOption.Set(rawValue: 1 << 3)`
                    static let standard = Self(bitIndex: 3)
                    /// `ShippingOption.Set(rawValue: 1 << 4)`
                    static let all = Self(bitIndex: 4)
                    /// Array of `ShippingOption` enum cases in the `rawValue` bit mask, ordered by declaration.
                    var options: [ShippingOption] {
                        [(0, ShippingOption.nextDay), (1, ShippingOption.secondDay), (2, ShippingOption.priority), (3, ShippingOption.standard), (4, ShippingOption.all)].filter {
                            1 << $0.0 & rawValue != 0
                        } .map(\.1)
                    }
                    var description: String {
                        "[\(options.map { "\($0)" } .joined(separator: ", "))]"
                    }
                    var debugDescription: String {
                        "OptionSet(\(rawValue.binaryString))"
                    }
                }
            }
            """#,
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
            #"""
            @EnumOptionSet
            enum ShippingOption {
                case nextDay, secondDay, priority, standard, `all`
            }
            """#,
            expandedSource: #"""
            enum ShippingOption {
                case nextDay, secondDay, priority, standard, `all`

                struct Set: OptionSet, Sendable, CustomStringConvertible, CustomDebugStringConvertible {
                    let rawValue: Int
                    init(rawValue: Int) {
                        self.rawValue = rawValue
                    }
                    /// Creates a new option set with the specified bit index. Asserts on `RawValue` overflow.
                    /// - Parameter bitIndex: The bit index in the `RawValue` bit mask.
                    init(bitIndex: Int) {
                        assert(bitIndex < RawValue.bitWidth, "Option bit index \(bitIndex) exceeds the size of 'Int'")
                        self.init(rawValue: 1 << bitIndex)
                    }
                    /// `ShippingOption.Set(rawValue: 1 << 0)`
                    static let nextDay = Self(bitIndex: 0)
                    /// `ShippingOption.Set(rawValue: 1 << 1)`
                    static let secondDay = Self(bitIndex: 1)
                    /// `ShippingOption.Set(rawValue: 1 << 2)`
                    static let priority = Self(bitIndex: 2)
                    /// `ShippingOption.Set(rawValue: 1 << 3)`
                    static let standard = Self(bitIndex: 3)
                    /// `ShippingOption.Set(rawValue: 1 << 4)`
                    static let `all` = Self(bitIndex: 4)
                    /// Array of `ShippingOption` enum cases in the `rawValue` bit mask, ordered by declaration.
                    var options: [ShippingOption] {
                        [(0, ShippingOption.nextDay), (1, ShippingOption.secondDay), (2, ShippingOption.priority), (3, ShippingOption.standard), (4, ShippingOption.`all`)].filter {
                            1 << $0.0 & rawValue != 0
                        } .map(\.1)
                    }
                    var description: String {
                        "[\(options.map { "\($0)" } .joined(separator: ", "))]"
                    }
                    var debugDescription: String {
                        "OptionSet(\(rawValue.binaryString))"
                    }
                }
            }
            """#,
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    func testMacroWithStringRawValueEnum() throws {
        #if canImport(EnumOptionSetMacros)
        assertMacroExpansion(
            #"""
            @EnumOptionSet
            enum ShippingOption: String {
                case nextDay = "1" // Should be ignored.
                case secondDay
                case priority
                case standard
            }
            """#,
            expandedSource: #"""
            enum ShippingOption: String {
                case nextDay = "1" // Should be ignored.
                case secondDay
                case priority
                case standard

                struct Set: OptionSet, Sendable, CustomStringConvertible, CustomDebugStringConvertible {
                    let rawValue: Int
                    init(rawValue: Int) {
                        self.rawValue = rawValue
                    }
                    /// Creates a new option set with the specified bit index. Asserts on `RawValue` overflow.
                    /// - Parameter bitIndex: The bit index in the `RawValue` bit mask.
                    init(bitIndex: Int) {
                        assert(bitIndex < RawValue.bitWidth, "Option bit index \(bitIndex) exceeds the size of 'Int'")
                        self.init(rawValue: 1 << bitIndex)
                    }
                    /// `ShippingOption.Set(rawValue: 1 << 0)`
                    static let nextDay = Self(bitIndex: 0)
                    /// `ShippingOption.Set(rawValue: 1 << 1)`
                    static let secondDay = Self(bitIndex: 1)
                    /// `ShippingOption.Set(rawValue: 1 << 2)`
                    static let priority = Self(bitIndex: 2)
                    /// `ShippingOption.Set(rawValue: 1 << 3)`
                    static let standard = Self(bitIndex: 3)
                    /// Combination of all set options.
                    static let all: Self = [.nextDay, .secondDay, .priority, .standard]
                    /// Array of `ShippingOption` enum cases in the `rawValue` bit mask, ordered by declaration.
                    var options: [ShippingOption] {
                        [(0, ShippingOption.nextDay), (1, ShippingOption.secondDay), (2, ShippingOption.priority), (3, ShippingOption.standard)].filter {
                            1 << $0.0 & rawValue != 0
                        } .map(\.1)
                    }
                    var description: String {
                        "[\(options.map { "\($0)" } .joined(separator: ", "))]"
                    }
                    var debugDescription: String {
                        "OptionSet(\(rawValue.binaryString))"
                    }
                }
            }
            """#,
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    func testExplicitTypeMacroOverflowError() throws {
        #if canImport(EnumOptionSetMacros)
        assertMacroExpansion(
            #"""
            @EnumOptionSet<UInt8>
            enum ShippingOption {
                case nextDay, secondDay, priority = 7, standard
            }
            """#,
            expandedSource: #"""
            enum ShippingOption {
                case nextDay, secondDay, priority = 7, standard

                struct Set: OptionSet, Sendable, CustomStringConvertible, CustomDebugStringConvertible {
                    let rawValue: UInt8
                    init(rawValue: UInt8) {
                        self.rawValue = rawValue
                    }
                    /// Creates a new option set with the specified bit index. Asserts on `RawValue` overflow.
                    /// - Parameter bitIndex: The bit index in the `RawValue` bit mask.
                    init(bitIndex: Int) {
                        assert(bitIndex < RawValue.bitWidth, "Option bit index \(bitIndex) exceeds the size of 'UInt8'")
                        self.init(rawValue: 1 << bitIndex)
                    }
                    /// `ShippingOption.Set(rawValue: 1 << 0)`
                    static let nextDay = Self(bitIndex: 0)
                    /// `ShippingOption.Set(rawValue: 1 << 1)`
                    static let secondDay = Self(bitIndex: 1)
                    /// `ShippingOption.Set(rawValue: 1 << 7)`
                    static let priority = Self(bitIndex: 7)
                    /// `ShippingOption.Set(rawValue: 1 << 8)`
                    static let standard = Self(bitIndex: 8)
                    /// Combination of all set options.
                    static let all: Self = [.nextDay, .secondDay, .priority, .standard]
                    /// Array of `ShippingOption` enum cases in the `rawValue` bit mask, ordered by declaration.
                    var options: [ShippingOption] {
                        [(0, ShippingOption.nextDay), (1, ShippingOption.secondDay), (7, ShippingOption.priority), (8, ShippingOption.standard)].filter {
                            1 << $0.0 & rawValue != 0
                        } .map(\.1)
                    }
                    var description: String {
                        "[\(options.map { "\($0)" } .joined(separator: ", "))]"
                    }
                    var debugDescription: String {
                        "OptionSet(\(rawValue.binaryString))"
                    }
                }
            }
            """#,
            diagnostics: [.init(message: "Option bit index 8 exceeds the size of 'UInt8'",
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
            #"""
            @EnumOptionSet
            enum ShippingOption {
                case nextDay, secondDay, priority = 63, standard
            }
            """#,
            expandedSource: #"""
            enum ShippingOption {
                case nextDay, secondDay, priority = 63, standard

                struct Set: OptionSet, Sendable, CustomStringConvertible, CustomDebugStringConvertible {
                    let rawValue: Int
                    init(rawValue: Int) {
                        self.rawValue = rawValue
                    }
                    /// Creates a new option set with the specified bit index. Asserts on `RawValue` overflow.
                    /// - Parameter bitIndex: The bit index in the `RawValue` bit mask.
                    init(bitIndex: Int) {
                        assert(bitIndex < RawValue.bitWidth, "Option bit index \(bitIndex) exceeds the size of 'Int'")
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
                    /// Combination of all set options.
                    static let all: Self = [.nextDay, .secondDay, .priority, .standard]
                    /// Array of `ShippingOption` enum cases in the `rawValue` bit mask, ordered by declaration.
                    var options: [ShippingOption] {
                        [(0, ShippingOption.nextDay), (1, ShippingOption.secondDay), (63, ShippingOption.priority), (64, ShippingOption.standard)].filter {
                            1 << $0.0 & rawValue != 0
                        } .map(\.1)
                    }
                    var description: String {
                        "[\(options.map { "\($0)" } .joined(separator: ", "))]"
                    }
                    var debugDescription: String {
                        "OptionSet(\(rawValue.binaryString))"
                    }
                }
            }
            """#,
            diagnostics: [.init(message: "Option bit index 64 exceeds the size of 'Int'",
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

    func testIgnoreOverflowArgumentMacro() throws {
        #if canImport(EnumOptionSetMacros)
        assertMacroExpansion(
            #"""
            @EnumOptionSet(ignoreOverflow: true)
            enum ShippingOption {
                case nextDay, secondDay, priority = 63, standard
            }
            """#,
            expandedSource: #"""
            enum ShippingOption {
                case nextDay, secondDay, priority = 63, standard

                struct Set: OptionSet, Sendable, CustomStringConvertible, CustomDebugStringConvertible {
                    let rawValue: Int
                    init(rawValue: Int) {
                        self.rawValue = rawValue
                    }
                    /// Creates a new option set with the specified bit index.
                    /// - Parameter bitIndex: The bit index in the `RawValue` bit mask.
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
                    /// Combination of all set options.
                    static let all: Self = [.nextDay, .secondDay, .priority, .standard]
                    /// Array of `ShippingOption` enum cases in the `rawValue` bit mask, ordered by declaration.
                    var options: [ShippingOption] {
                        [(0, ShippingOption.nextDay), (1, ShippingOption.secondDay), (63, ShippingOption.priority), (64, ShippingOption.standard)].filter {
                            1 << $0.0 & rawValue != 0
                        } .map(\.1)
                    }
                    var description: String {
                        "[\(options.map { "\($0)" } .joined(separator: ", "))]"
                    }
                    var debugDescription: String {
                        "OptionSet(\(rawValue.binaryString))"
                    }
                }
            }
            """#,
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    func testNonBoolLiteralArgumentMacroErrorAndFixIts() throws {
        #if canImport(EnumOptionSetMacros)
        assertMacroExpansion(
            #"""
            let b = true
            @EnumOptionSet(ignoreOverflow: b)
            enum ShippingOption {
                case nextDay, secondDay, priority, standard
            }
            """#,
            expandedSource: #"""
            let b = true
            enum ShippingOption {
                case nextDay, secondDay, priority, standard
            }
            """#,
            diagnostics: [.init(message: "'ignoreOverflow' argument must be a boolean literal",
                                line: 2,
                                column: 32,
                                fixIts: [.init(message: "'ignoreOverflow' argument must be a boolean literal"),
                                         .init(message: "Remove the 'ignoreOverflow' argument")])],
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    func testMacroWithNonEnumStructErrorAndFixIt() throws {
        #if canImport(EnumOptionSetMacros)
        assertMacroExpansion(
            #"""
            @EnumOptionSet
            struct ShippingOption {
            }
            """#,
            expandedSource: #"""
            struct ShippingOption {
            }
            """#,
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
            #"""
            @EnumOptionSet
            enum ShippingOption {
            }
            """#,
            expandedSource: #"""
            enum ShippingOption {

                struct Set: OptionSet, Sendable, CustomStringConvertible, CustomDebugStringConvertible {
                    let rawValue: Int
                    init(rawValue: Int) {
                        self.rawValue = rawValue
                    }
                    /// Creates a new option set with the specified bit index. Asserts on `RawValue` overflow.
                    /// - Parameter bitIndex: The bit index in the `RawValue` bit mask.
                    init(bitIndex: Int) {
                        assert(bitIndex < RawValue.bitWidth, "Option bit index \(bitIndex) exceeds the size of 'Int'")
                        self.init(rawValue: 1 << bitIndex)
                    }
                    /// Combination of all set options.
                    static let all: Self = []
                    /// Array of `ShippingOption` enum cases in the `rawValue` bit mask, ordered by declaration.
                    var options: [ShippingOption] {
                        [].filter {
                            1 << $0.0 & rawValue != 0
                        } .map(\.1)
                    }
                    var description: String {
                        "[\(options.map { "\($0)" } .joined(separator: ", "))]"
                    }
                    var debugDescription: String {
                        "OptionSet(\(rawValue.binaryString))"
                    }
                }
            }
            """#,
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }
}
