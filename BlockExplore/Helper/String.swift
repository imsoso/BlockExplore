//
//  String.swift
//  SOKX
//
//  Created by soso on 2025/2/14.
//

import Foundation

extension String {

    static var empty: String {
        return ""
    }

    func hexToDecimal() -> String? {
        // Remove "0x" if it exists
        let hexString = self.hasPrefix("0x") ? String(self.dropFirst(2)) : self

        guard let hexNumber = Int(hexString, radix: 16) else {
            return nil
        }
        return String(describing: hexNumber)
    }
}
