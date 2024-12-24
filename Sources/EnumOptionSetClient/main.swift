//
//  main.swift
//  EnumOptionSet
//
//  Created by Alexey Demin on 2024-12-09.
//  Copyright © 2024 DnV1eX. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//

import EnumOptionSet

//struct ShippingOptions: OptionSet {
//    let rawValue: Int
//
//    static let nextDay = Self(rawValue: 1 << 0)
//    static let secondDay = Self(rawValue: 1 << 1)
//    static let priority = Self(rawValue: 1 << 3)
//    static let standard = Self(rawValue: 1 << 4)
//
//    static let express: Self = [.nextDay, .secondDay]
//    static let all: Self = [.express, .priority, .standard]
//}

@EnumOptionSet<Int8>
enum ShippingOption: Int {
    case nextDay, secondDay, priority = 3, standard
}
typealias ShippingOptions = ShippingOption.Set
extension ShippingOptions {
    static let express: Self = [nextDay, secondDay]
}
assert(ShippingOptions.standard.rawValue == 16)
assert(ShippingOptions.RawValue.bitWidth == 8)
assert(ShippingOptions.express.description == "[nextDay, secondDay]")
assert(ShippingOptions.express.debugDescription == "OptionSet(0b00000011)")

var shippingOptions = ShippingOptions.all
assert(shippingOptions == [.express, .priority, .standard])
shippingOptions[.express].toggle()
assert(shippingOptions == [.priority, .standard])

shippingOptions = .init(options: [.secondDay, .priority])
assert(shippingOptions.options == [.secondDay, .priority])
