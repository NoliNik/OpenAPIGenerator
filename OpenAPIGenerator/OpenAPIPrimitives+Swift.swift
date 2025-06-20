import Foundation

extension ParameterType {
    var swiftString: String {
        switch self {
        case .none: return "Void"
        case .integer: return "Int"
        case .string: return "String"
        case .boolean: return "Bool"
        case .object: return "AnyObjectValue"
        case .dictionary: return "[String: AnyObjectValue]"
        case .array: return "[AnyObjectValue]"
        case .number: return "Double"
        case .file: return "FileValue"
        }
    }
}

extension ParameterFormat {
    var swiftString: String {
        switch self {
        case .uuid: return "UUID"
        case .double: return "Double"
        case .int32: return "Int32"
        case .int64: return "Int64"
        case .dateTime: return "Int64"
        }
    }
}

extension PrimitiveObject {
    var typeSwiftString: String {
        switch type {
        case .none: return type.swiftString
        case .integer: return format?.swiftString ?? type.swiftString
        case .string: return type.swiftString
        case .boolean: return type.swiftString
        case .object: return (schema != nil ? processor.schemes[schema!]?.title.escaped : nil) ?? type.swiftString
        case .dictionary: return "[\(ParameterType.string.swiftString): \(items!.typeSwiftString)]"
        case .array: return "[\(items!.typeSwiftString)]"
        case .number: return format?.swiftString ?? type.swiftString
        case .file: return type.swiftString
        }
    }
}

extension PropertyObject {
    var swiftEnum: String? {
        guard let values = self.enum else { return nil }

        var strings: [String] = []
        strings.append("\(indent)\(genNonClassAccessLevel) enum \(nameSwiftString.capitalizedFirstLetter.escaped): String, CaseIterable, Codable {")
        strings.append(contentsOf: values.sorted().map({ "\(indent)\(indent)case \($0.lowercased().escaped) = \"\($0)\"" }))
        strings.append("\(indent)}\n")
        return strings.joined(separator: "\n")
    }

    var propertyTypeSwiftString: String {
        switch type {
        case .string: return self.enum != nil ? nameSwiftString.capitalizedFirstLetter.escaped : type.swiftString
        case .object:
            if let additionalProperties = self.additionalProperties {
                return "[String: \(additionalProperties.typeSwiftString)]"
            } else {
                return super.typeSwiftString
            }
        default: return super.typeSwiftString
        }
    }

    var nameSwiftString: String {
        return name.loweredFirstLetter.escaped
    }

    var nameTypeSwiftString: String {
        return "\(nameSwiftString): \(propertyTypeSwiftString)\(required ? "" : "?")"
    }

    func swiftString(useVar: Bool) -> String {
        return "\(indent)\(genNonClassAccessLevel) \(useVar ? "var" : "let") \(nameTypeSwiftString)"
    }
}

extension ObjectScheme {
    func swiftString(optinalInit: Bool, useVar: Bool) -> String {
        let sorted = properties.sorted {  $0.name < $1.name }

        var strings: [String] = []
        strings.append("\(genNonClassAccessLevel) struct \(title.escaped): Codable {")
        strings.append(contentsOf: sorted.compactMap({ $0.swiftEnum }))
        strings.append(contentsOf: sorted.map({ $0.swiftString(useVar: useVar) }))
        strings.append("")

        let params = sorted.map({
            if optinalInit && !$0.required {
                return $0.nameTypeSwiftString + " = nil"
            } else {
                return $0.nameTypeSwiftString
            }
        }).joined(separator: ", ")
        strings.append("\(indent)\(genNonClassAccessLevel) init(\(params)) {")
        strings.append(contentsOf: sorted.map({ "\(indent)\(indent)self.\($0.nameSwiftString) = \($0.nameSwiftString)" }))
        strings.append("\(indent)}")

        strings.append("}")

        return strings.joined(separator: "\n")
    }
}
