# EnumOptionSet
[@EnumOptionSet](https://github.com/DnV1eX/EnumOptionSet) is a Swift attached member macro to declare option sets using an enumeration notation.

## Purpose
The built-in [OptionSet](https://developer.apple.com/documentation/swift/optionset#overview) declaration syntax in Swift is quite cumbersome and repetitive:
```Swift
struct ShippingOptions: OptionSet {
    let rawValue: Int

    static let nextDay = Self(rawValue: 1 << 0)
    static let secondDay = Self(rawValue: 1 << 1)
    static let priority = Self(rawValue: 1 << 2)
    static let standard = Self(rawValue: 1 << 3)

    static let all: Self = [.nextDay, .secondDay, .priority, .standard]
}
```
The same option set can be declared with the `@EnumOptionSet` macro and the enum like this:
```Swift
@EnumOptionSet
enum ShippingOption {
    case nextDay, secondDay, priority, standard
}
```
> [!NOTE]
> The macro generates a nested `Set` structure with options extracted from the names of enumerated cases.
> It also generates the `all` property as an option composition, along with some other helper members.

Then you can create a typealias and extend it with additional composite options:
```Swift
typealias ShippingOptions = ShippingOption.Set
extension ShippingOptions {
    static let express: Self = [.nextDay, .secondDay]
}
```

> [!IMPORTANT]
> I hope you enjoy the project and find it useful. Please bookmark it with ⭐️ and share your feedback. Thank you!

## Advanced usage
The macro also supports custom raw value types and indices:
```Swift
@EnumOptionSet<Int8>    // OptionSet RawValue = Int8
enum ShippingOption: Int {
    case nextDay        // Starting with index 0.       (rawValue: 1 << 0)
    case secondDay      // Incrementing by 1.           (rawValue: 1 << 1)
    case priority = 3   // Skipping index 2.            (rawValue: 1 << 3)
    case standard       // Continuing to increment.     (rawValue: 1 << 4)
}
```
> [!TIP]
> The OptionSet RawValue type can also be declared as a first argument `@EnumOptionSet(Int8.self)`.
> Currently, an even shorter form `@EnumOptionSet(Int8)` works, but this may be a bug of the Swift syntax analyzer, so use it at your own risk.

> [!NOTE]
> Enum raw values expressed otherwise than by `Int` literals are ignored. The enum raw value can be declared as an arbitrary type.
> Conformance to `CaseIterable` is also not required.

Another big advantage of the macro over the built-in declaration is that it checks for index duplication and raw value overflow.
A compile-time check is performed on the type name and a runtime assertion is added using the `bitWidth` property of the `FixedWidthInteger` raw value type.

Both of checks can be disabled with the `ignoreOverflow` attribute flag:
```Swift
@EnumOptionSet<Int8>(ignoreOverflow: true)
enum ShippingOption: Int {
    case nextDay, secondDay, priority, standard = 8 // Option bit index 8 exceeds the size of 'Int8'.
}
```
> [!NOTE]
> The raw values of overflowed options are set to zero and these options are ignored.

## Other goodies
The macro generates easy to read `description` and `debugDescription` properties:
```Swift
ShippingOptions.express.description // "[nextDay, secondDay]"

ShippingOptions.express.debugDescription // "OptionSet(0b00000011)"
```

It also contains an `OptionSet` extension for accessing options as boolean flags using subscript notation:
```Swift
var shippingOptions: ShippingOptions = []
shippingOptions[.standard] = true
shippingOptions[.express].toggle()
shippingOptions[.priority] = shippingOptions[.standard]
shippingOptions == .all // true
```

There are also multiple format checks and syntax fix suggestions. The macro code is fully covered with unit tests.

## Installation
To add the package to your Xcode project, open `File -> Add Package Dependencies...` and search for the URL:
```
https://github.com/DnV1eX/EnumOptionSet.git
```
Then, simply **import EnumOptionSet** and add the **@EnumOptionSet** attribute before the target enum.
> [!WARNING]
> Xcode may ask to `Trust & Enable` the macro on first use or after an update.

## References
- Proposal for adding a variant of this macro to the standard library (it never happened) with detailed discussion: [[Pitch] `@OptionSet` macro](https://forums.swift.org/t/pitch-optionset-macro/63547).
- Also try [@EnumRawValues](https://github.com/DnV1eX/EnumRawValues) - Swift macro that enables full-fledged raw values for enumerations.

## License
Copyright © 2024 DnV1eX. All rights reserved. Licensed under the Apache License, Version 2.0.
