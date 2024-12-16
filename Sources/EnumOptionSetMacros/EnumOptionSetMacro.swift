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

        /// Macro attribute arguments, such as `rawValueType` and `ignoreOverflow`.
        let attributeArguments = node.arguments?.as(LabeledExprListSyntax.self) ?? []

        /// The `public` access modifier, if applied to the enumeration, is used to generate the nested structure.
        var accessModifier = declaration.modifiers.first(where: \.isPublic)?.trimmed
        accessModifier?.trailingTrivia = .space

        /// Attribute label for the macro argument flag to ignore raw value overflow checks.
        let ignoreOverflowLabel = "ignoreOverflow"

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

        /// Flag to ignore raw value overflow, obtained from the `ignoreOverflow` macro attribute argument.
        /// Defaults to `false`.
        var ignoreOverflow = false
        // Checks that the `ignoreOverflow` argument is a boolean literal and suggests syntax fixes if necessary.
        if let ignoreOverflowArgument = attributeArguments.first(where: { $0.label?.text == ignoreOverflowLabel }) {
            guard let boolean = ignoreOverflowArgument.expression.as(BooleanLiteralExprSyntax.self),
                  case .keyword(let keyword) = boolean.literal.tokenKind
            else {
                let diagnostic = Diagnostic(node: ignoreOverflowArgument.expression,
                                            message: Message.expectingBooleanLiteral(ignoreOverflowLabel),
                                            fixIts: [.replace(message: Message.expectingBooleanLiteral(ignoreOverflowLabel),
                                                              oldNode: ignoreOverflowArgument.expression,
                                                              newNode: BooleanLiteralExprSyntax(booleanLiteral: true)),
                                                     .replace(message: Message.removeArgument(ignoreOverflowLabel),
                                                              oldNode: attributeArguments,
                                                              newNode: attributeArguments.filter { $0.label?.text != ignoreOverflowLabel })])
                context.diagnose(diagnostic)
                return []
            }
            ignoreOverflow = (keyword == .true)
        }

        /// Bit count of the raw value type, inferred from the type name.
        /// Defaults to `64` for integers, or `Int.max` for unknown types or when overflow is ignored.
        let rawValueBitCount = rawValueType.description.lowercased().contains("int") && !ignoreOverflow ? Int(rawValueType.description.trimmingCharacters(in: .decimalDigits.inverted)) ?? 64 : .max

        /// Flattened array of enumeration case elements.
        let caseElements = enumeration.memberBlock.members.compactMap { $0.decl.as(EnumCaseDeclSyntax.self) }.flatMap(\.elements)

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
            // Displays warnings for indices that are out of the raw value bit count, suggesting to add the `ignoreOverflow` macro attribute argument to skip all overflow checks.
            if index >= rawValueBitCount {
                var attribute = node.trimmed
                var arguments = attributeArguments
                if arguments.isEmpty {
                    attribute.leftParen = .leftParenToken()
                    attribute.rightParen = .rightParenToken()
                } else {
                    let lastIndex = arguments.index(before: arguments.endIndex)
                    arguments[lastIndex].trailingComma = .commaToken()
                    arguments[lastIndex].trailingTrivia = .space
                }
                arguments.append(.init(label: ignoreOverflowLabel, expression: true as BooleanLiteralExprSyntax))
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
            if !ignoreOverflow {
                "assert(bitIndex < RawValue.bitWidth, \"Option bit index \\(bitIndex) exceeds the size of '\(rawValueType)'\")"
            }
            "self.init(rawValue: 1 << bitIndex)"
        }
        initBitIndex.leadingTrivia = """
            /// Creates a new option set with the specified bit index.\(ignoreOverflow ? "" : " Asserts on `RawValue` overflow.")
            /// - Parameter bitIndex: The bit index in the `RawValue` bit mask.\n
            """

        // Generates static constants for set options.
        let members = try enumeratedElementNames.map { index, name in
            var member = try VariableDeclSyntax("\(accessModifier)static let \(raw: name) = Self(bitIndex: \(raw: index))")
            member.leadingTrivia = "/// `\(enumeration.name.text).\(optionSetStructName)(rawValue: 1 << \(index))`\n"
            return member
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
            combination = try VariableDeclSyntax("\(accessModifier)static let \(raw: combinationOptionName): Self = [\(raw: caseElements.map { ".\($0.name.text)" }.joined(separator: ", "))]")
            combination?.leadingTrivia = "/// Combination of all set options.\n"
        }

        // Generates a computed property returning an array of enum cases corresponding to the bit mask.
        var options = try VariableDeclSyntax("\(accessModifier)var options: [\(enumeration.name.trimmed)]") {
            "[\(raw: enumeratedElementNames.map { "(\($0.index), \(enumeration.name.text).\($0.name))" }.joined(separator: ", "))].filter { 1 << $0.0 & rawValue != 0 }.map(\\.1)"
        }
        options.leadingTrivia = "/// Array of `\(enumeration.name.text)` enum cases in the `rawValue` bit mask, ordered by declaration.\n"

        // Generates a description for the option set with an array of enum cases.
        let description = try VariableDeclSyntax("\(accessModifier)var description: String") {
            #""[\(options.map { "\($0)" }.joined(separator: ", "))]""#
        }

        // Generates a debug description for the option set with a binary representation of the raw value.
        let debugDescription = try VariableDeclSyntax("\(accessModifier)var debugDescription: String") {
            #""OptionSet(\(rawValue.binaryString))""#
        }

        // Generates an option set structure with all previously generated members.
        let setStructure = try StructDeclSyntax("\(accessModifier)struct \(raw: optionSetStructName): OptionSet, Sendable, CustomStringConvertible, CustomDebugStringConvertible") {
            rawValue
            initRawValue
            initBitIndex
            members
            if let combination { combination }
            options
            description
            debugDescription
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
            case .indexIsOutOfRawValueSize(let index, let type): "Option bit index \(index) exceeds the size of '\(type)'"
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
