//
//  EnumOptionSetMacro.swift
//  EnumOptionSet
//
//  Created by Alexey Demin on 2024-12-09.
//  Copyright © 2024 DnV1eX. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//

import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftDiagnostics

public struct EnumOptionSetMacro: MemberMacro {

    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {

        // Checks that the macro is attached to an enumeration. Suggests a fix by replacing a keyword with `enum`.
        guard let enumeration = declaration.as(EnumDeclSyntax.self) else {
            let diagnostic = Diagnostic(node: declaration.introducer,
                                        message: Message.wrongDeclarationType,
                                        fixIt: .replace(message: Message.wrongDeclarationType,
                                                        oldNode: declaration.introducer,
                                                        newNode: TokenSyntax(.keyword(.enum), presence: .present)))
            context.diagnose(diagnostic)
            return []
        }

        /// Macro attribute arguments, such as `rawValueType`, `checkOverflow` and `generateDescription`.
        let attributeArguments = node.arguments?.as(LabeledExprListSyntax.self) ?? []

        /// The `public` access modifier, if applied to the enumeration, is used to generate the nested structure.
        var accessModifier = declaration.modifiers.first(where: \.isPublic)?.trimmed
        accessModifier?.trailingTrivia = .space

        /// Attribute label for the macro argument flag to check raw value overflow.
        let checkOverflowLabel = "checkOverflow"

        /// Attribute label for the macro argument flag to generate `description` and `debugDescription`.
        let generateDescriptionLabel = "generateDescription"

        /// Name for the generated nested structure that conforms to the `OptionSet` protocol.
        let optionSetStructName = "Set"

        /// Static property name for the generated option set representing combination of all options.
        let combinationOptionName = "all"

        /// Gets the raw value type from the generic clause of the macro attribute.
        /// For example, `Int8` from `@EnumOptionSet<Int8>`.
        let typeFromGenericClause = {
            node.attributeName.as(IdentifierTypeSyntax.self)?.genericArgumentClause?.arguments.first?.argument.trimmed
        }

        /// Gets the raw value type from the first argument of the macro attribute.
        /// For example, `Int8` from `@EnumOptionSet(Int8.self)`.
        let typeFromFirstArgument = {
            if var firstArgument = attributeArguments.first?.expression {
                if let firstMember = firstArgument.as(MemberAccessExprSyntax.self)?.base {
                    firstArgument = firstMember
                }
                if let baseName = firstArgument.as(DeclReferenceExprSyntax.self)?.baseName.trimmed {
                    return "\(baseName)" as TypeSyntax?
                }
            }
            return nil
        }

        /// Option set raw value type, obtained from the macro generic clause or the first argument.
        /// Defaults to `Int`.
        let rawValueType = typeFromGenericClause() ?? typeFromFirstArgument() ?? "Int"
        
        /// Retrieves the argument with the specified label and returns its value as a boolean.
        ///
        /// If the argument is not a boolean literal, provides a diagnostic with syntax fix suggestions.
        /// - Parameters:
        ///   - label: The label of the argument to retrieve.
        ///   - defaultValue: The default value to return if the argument is not specified.
        /// - Returns: The argument value as a boolean, or nil when a diagnostic is provided.
        func argumentFlag(label: String, defaultValue: Bool) -> Bool? {
            if let argument = attributeArguments.first(where: { $0.label?.text == label }) {
                if let boolean = argument.expression.as(BooleanLiteralExprSyntax.self),
                   case .keyword(let keyword) = boolean.literal.tokenKind
                {
                    return keyword == .true
                } else {
                    let diagnostic = Diagnostic(node: argument.expression,
                                                message: Message.expectingBooleanLiteral(label),
                                                fixIts: [.replace(message: Message.expectingBooleanLiteral(label),
                                                                  oldNode: argument.expression,
                                                                  newNode: BooleanLiteralExprSyntax(booleanLiteral: !defaultValue)),
                                                         .replace(message: Message.removeArgument(label),
                                                                  oldNode: attributeArguments,
                                                                  newNode: attributeArguments.filter { $0.label?.text != label })])
                    context.diagnose(diagnostic)
                    return nil
                }
            } else {
                return defaultValue
            }
        }

        /// Flag to check raw value overflow, obtained from the `checkOverflow` macro attribute argument.
        /// Defaults to `true`.
        guard let checkOverflow = argumentFlag(label: checkOverflowLabel, defaultValue: true) else {
            return []
        }

        /// Flag to generate `description` and `debugDescription`, obtained from the `generateDescription` macro attribute argument.
        /// Defaults to `true`.
        guard let generateDescription = argumentFlag(label: generateDescriptionLabel, defaultValue: true) else {
            return []
        }

        /// Bit count of the raw value type, inferred from the type name.
        /// Defaults to `64` for integers, or `Int.max` for unknown types or when overflow check is disabled.
        let rawValueBitCount = rawValueType.description.lowercased().contains("int") && checkOverflow ? Int(rawValueType.description.trimmingCharacters(in: .decimalDigits.inverted)) ?? 64 : .max

        /// Flattened array of enumeration case elements.
        let caseElements = enumeration.memberBlock.members.compactMap { $0.decl.as(EnumCaseDeclSyntax.self) }.flatMap(\.elements)

        /// Indicates whether the enum has associated values.
        let hasAssociatedValues = caseElements.contains { $0.parameterClause != nil }

        /// List of case names with bit indices explicitly assigned using integer literals, or incremented sequentially based on the case element order, starting from zero.
        let enumeratedElementNames = caseElements.reduce(into: [(index: Int, name: String)]()) { result, caseElement in
            let index: Int
            if let rawValue = caseElement.rawValue, let int = Int(rawValue.value.trimmedDescription) {
                index = int
            } else if let lastIndex = result.last?.index {
                index = lastIndex + 1
            } else {
                index = 0
            }
            // Displays warnings for indices that are out of the raw value bit count, suggesting to add the `checkOverflow = false` macro attribute argument to skip all overflow checks.
            if !(0..<rawValueBitCount).contains(index) {
                var attribute = node.trimmed
                var arguments = attributeArguments
                var checkOverflowArgument = LabeledExprSyntax(label: checkOverflowLabel, expression: false as BooleanLiteralExprSyntax)
                var i = arguments.startIndex
                if arguments.isEmpty {
                    attribute.leftParen = .leftParenToken()
                    attribute.rightParen = .rightParenToken()
                } else {
                    if arguments[i].label == nil {
                        checkOverflowArgument.trailingComma = arguments[i].trailingComma
                        checkOverflowArgument.trailingTrivia = arguments[i].trailingTrivia
                        arguments[i].trailingComma = .commaToken()
                        arguments[i].trailingTrivia = .space
                        i = arguments.index(after: i)
                    } else {
                        checkOverflowArgument.trailingComma = .commaToken()
                        checkOverflowArgument.trailingTrivia = .space
                    }
                }
                arguments.insert(checkOverflowArgument, at: i)
                attribute.arguments = .argumentList(arguments)
                let diagnostic = Diagnostic(node: caseElement,
                                            message: Message.indexIsOutOfRawValueSize(index, rawValueType.description),
                                            fixIt: .replace(message: Message.ignoreRawValueOverflow,
                                                            oldNode: node,
                                                            newNode: attribute))
                context.diagnose(diagnostic)
            }
            result.append((index, caseElement.name.text))
        }

        // MARK: Code generation.

        // Generates option set members starting with `rawValue` property.
        let rawValue = try VariableDeclSyntax("\(accessModifier)let rawValue: \(rawValueType)")

        // Generates an initializer with `rawValue`.
        let initRawValue = try InitializerDeclSyntax("\(accessModifier)init(rawValue: \(rawValueType))") {
            "self.rawValue = rawValue"
        }

        // Generates an initializer with `bitIndex`.
        var initBitIndex = try InitializerDeclSyntax("\(accessModifier)init(bitIndex: Int)") {
            if checkOverflow {
                "assert((0 ..< RawValue.bitWidth).contains(bitIndex), \"Option bit index \\(bitIndex) is out of range for '\(rawValueType)'\")"
            }
            "self.init(rawValue: 1 << bitIndex)"
        }
        initBitIndex.leadingTrivia = """
            /// Creates a new option set with the specified bit index.\(checkOverflow ? " Asserts on `RawValue` overflow." : "")
            /// - Parameter bitIndex: The index of the `1` bit in the `rawValue` bit mask.\n
            """

        // Generates static constants for set options.
        let options = try enumeratedElementNames.map { index, name in
            var option = try VariableDeclSyntax("\(accessModifier)static let \(raw: name) = Self(bitIndex: \(raw: index))")
            option.leadingTrivia = "/// `\(enumeration.name.text).\(optionSetStructName)(rawValue: 1 << \(index))` option.\n"
            return option
        }

        // Generates a static constant for the combination of all set options if the name is not already used in one of the options.
        var combination: VariableDeclSyntax?
        // Displays a warning if the combination property is not generated, suggesting a fix to escape the name with backticks to suppress the warning.
        if let combinationCaseName = caseElements.first(where: { $0.name.text == combinationOptionName })?.name {
            let diagnostic = Diagnostic(node: combinationCaseName,
                                        message: Message.skippingCombinationOption(combinationOptionName),
                                        fixIt: .replace(message: Message.putInBackticks,
                                                        oldNode: combinationCaseName,
                                                        newNode: EnumCaseElementSyntax(name: "`\(raw: combinationOptionName)`")))
            context.diagnose(diagnostic)
        } else if !caseElements.map(\.name.text).contains("`\(combinationOptionName)`") {
            combination = try VariableDeclSyntax("\(accessModifier)static let \(raw: combinationOptionName): Self = [\(raw: caseElements.map(\.name.text).joined(separator: ", "))]")
            combination?.leadingTrivia = "/// Combination of all set options.\n"
        }

        // Generates a `bitIndices` computed property.
        var bitIndices = try VariableDeclSyntax("\(accessModifier)var bitIndices: Swift.Set<Int>") { """
            (0 ..< RawValue.bitWidth).reduce(into: []) { result, bitIndex in
                if contains(.init(bitIndex: bitIndex)) {
                    result.insert(bitIndex)
                }
            }
            """
        }
        bitIndices.leadingTrivia = "/// Set of indices corresponding to the `1` bits in the `rawValue` bit mask.\n"

        // Generates an initializer with `bitIndices`.
        var initBitIndices = try InitializerDeclSyntax("\(accessModifier)init(bitIndices: Swift.Set<Int>)") { """
            self = bitIndices.reduce(into: []) { result, bitIndex in
                result.formUnion(.init(bitIndex: bitIndex))
            }
            """
        }
        initBitIndices.leadingTrivia = """
            /// Creates a new option set with the specified bit indices.\(checkOverflow ? " Asserts on `RawValue` overflow." : "")
            /// - Parameter bitIndices: The set of indices corresponding to the `1` bits in the `rawValue` bit mask.\n
            """

        var description: VariableDeclSyntax?
        var debugDescription: VariableDeclSyntax?
        if generateDescription {
            // Generates a description for the option set with an array of option names or bit indices.
            description = try VariableDeclSyntax("\(accessModifier)var description: String") {
                "let names = [\(raw: enumeratedElementNames.map { "\($0.index): \"\($0.name)\"" }.joined(separator: ", "))]"
                """
                return "[" + bitIndices.sorted().map { bitIndex in
                    names[bitIndex] ?? "\\(bitIndex)"
                }.joined(separator: ", ") + "]"
                """
            }

            // Generates a debug description for the option set with a binary representation of the raw value.
            debugDescription = try VariableDeclSyntax("\(accessModifier)var debugDescription: String") {
                #""OptionSet(\(rawValue.binaryString))""#
            }
        }

        var cases: VariableDeclSyntax?
        var initCases: InitializerDeclSyntax?
        if !hasAssociatedValues {
            // Generates a computed property returning an array of enum cases corresponding to the bit mask.
            cases = try VariableDeclSyntax("\(accessModifier)var cases: [\(enumeration.name.trimmed)]") { """
                [\(raw: caseElements.map { "(Self.\($0.name.text), \(enumeration.name.text).\($0.name.text))" }.joined(separator: ", "))].reduce(into: []) { result, element in
                    if contains(element.0) {
                        result.append(element.1)
                    }
                }
                """
            }
            cases?.leadingTrivia = "/// Array of `\(enumeration.name.text)` enum cases in the `rawValue` bit mask, ordered by declaration.\n"

            // Generates an initializer with `cases`.
            initCases = try InitializerDeclSyntax("\(accessModifier)init(cases: [\(enumeration.name.trimmed)])") { """
                self = [\(raw: caseElements.map { "(Self.\($0.name.text), \(enumeration.name.text).\($0.name.text))" }.joined(separator: ", "))].reduce(into: []) { result, element in
                    if cases.contains(element.1) {
                        result.formUnion(element.0)
                    }
                }
                """
            }
            initCases?.leadingTrivia = """
                /// Creates a new option set with the specified array of `\(enumeration.name.text)` enum cases.
                /// - Parameter cases: The array of `\(enumeration.name.text)` enum cases corresponding to the `rawValue` bit mask.\n
                """
        }

        // Generates an option set structure with all previously generated members.
        let setStructure = try StructDeclSyntax("\(accessModifier)struct \(raw: optionSetStructName): OptionSet\(raw: accessModifier != nil ? ", Sendable" : "")\(raw: generateDescription ? ", CustomStringConvertible, CustomDebugStringConvertible" : "")") {
            rawValue
            initRawValue
            initBitIndex
            options
            if let combination { combination }
            bitIndices
            initBitIndices
            if let description { description }
            if let debugDescription { debugDescription }
            if let cases { cases }
            if let initCases { initCases }
        }

        return [.init(setStructure)]
    }
}

extension EnumOptionSetMacro {
    enum Message: DiagnosticMessage, FixItMessage, Error {
        case wrongDeclarationType
        case expectingBooleanLiteral(String)
        case removeArgument(String)
        case skippingCombinationOption(String)
        case putInBackticks
        case indexIsOutOfRawValueSize(Int, String)
        case ignoreRawValueOverflow

        var message: String {
            switch self {
            case .wrongDeclarationType: "@EnumOptionSet can only be applied to 'enum'"
            case .expectingBooleanLiteral(let label): "'\(label)' argument must be a boolean literal"
            case .removeArgument(let label): "Remove the '\(label)' argument"
            case .skippingCombinationOption(let name): "'\(name)' is used as a distinct option, not a combination of all options"
            case .putInBackticks: "Add backticks to silence the warning"
            case .indexIsOutOfRawValueSize(let index, let type): "Option bit index \(index) is out of range for '\(type)'"
            case .ignoreRawValueOverflow: "Ignore the bit mask overflow"
            }
        }

        var diagnosticID: SwiftDiagnostics.MessageID {
            .init(domain: "EnumOptionSetMacros", id: Mirror(reflecting: self).children.first?.label ?? "\(self)")
        }

        var severity: SwiftDiagnostics.DiagnosticSeverity {
            switch self {
            case .wrongDeclarationType, .expectingBooleanLiteral: .error
            case .skippingCombinationOption, .indexIsOutOfRawValueSize: .warning
            case .removeArgument, .putInBackticks, .ignoreRawValueOverflow: .remark
            }
        }

        var fixItID: SwiftDiagnostics.MessageID {
            diagnosticID
        }
    }
}

extension DeclModifierSyntax {
    var isPublic: Bool {
        if case .keyword(let keyword) = name.tokenKind, keyword == .public { true } else { false }
    }
}

@main
struct EnumOptionSetPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        EnumOptionSetMacro.self,
    ]
}
