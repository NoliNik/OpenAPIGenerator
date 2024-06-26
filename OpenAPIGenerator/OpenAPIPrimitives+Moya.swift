import Foundation

extension AuthorizationType {
    var moyaString: String {
        switch self {
        case .none: return ".none"
        case .basic: return ".basic"
        case .bearer: return ".bearer"
        case .custom(let value): return ".custom(\"\(value)\")"
        }
    }
}

extension PropertyObject {
    var moyaFormDataString: String {
        let dataString: String
        switch type {
        case .file:
            dataString = "\(nameSwiftString)?.moyaFormData(name: \"\(nameSwiftString)\")"
        default:
            dataString = "MultipartFormData(provider: .data(String(describing: \(nameSwiftString)).data(using: .utf8)!), name: \"\(nameSwiftString)\")"
        }

        return required ? dataString : "\(nameSwiftString) == nil ? nil : \(dataString)"
    }
}

extension Operation {
    var caseName: String {
        return id.loweredFirstLetter.escaped
    }

    var caseDocumetation: String {
        let keys = responses.keys.sorted()
        var strings: [String] = []
        strings.append("\(indent)/// \(descriptionText ?? "")")
        strings.append("\(indent)/// - respones:")
        strings.append(contentsOf: keys.map { "\(indent)/// \(indent)- \($0): \(responses[$0]!.primitive.typeSwiftString)" })
        return strings.joined(separator: "\n")
    }

    var swiftEnum: String? {
        let enums = parameters.compactMap({ $0.swiftEnum })
        return enums.isEmpty ? nil : enums.joined(separator: "\n")
    }
    
    var sortedParameters: [OperationParameter] {
        return parameters.sorted {
            if $0.in == $1.in { return $0.nameSwiftString < $1.nameSwiftString}
            else { return $0.in.rawValue == $1.in.rawValue }
        }
    }
    
    var caseDeclaration: String {
        return parameters.isEmpty ? caseName : "\(caseName)(\(sortedParameters.map({ $0.nameTypeSwiftString }).joined(separator: ", ")))"
    }

    var funcDeclaration: String {
        return "\(caseName)(\(sortedParameters.map({ $0.nameTypeSwiftString }).joined(separator: ", ")))"
    }

    var caseUsage: String {
        return parameters.isEmpty ? caseName : "\(caseName)(\(sortedParameters.map({ "\($0.nameSwiftString): \($0.nameSwiftString)" }).joined(separator: ", ")))"
    }
    
    func caseWithParams(position: [ParameterPosition]) -> String {
        let needParams = parameters.contains(where: { position.contains($0.in) })
        return needParams == false ? caseName : "\(caseName)(\(sortedParameters.map({ position.contains($0.in) ? "let \($0.nameSwiftString)" : "_" }).joined(separator: ", ")))"
    }
    
    var moyaPath: String {
        let params = parameters.filter { $0.in == .path }
        var result = path
        for param in params {
            result = result.replacingOccurrences(of: "{\(param.name)}", with: "\\(\(param.nameSwiftString))")
        }
        return result
    }
    
    var moyaTask: String {
        let body = parameters.filter { $0.in == .body }
        let query = parameters.filter { $0.in == .query }
        let form = parameters.filter { $0.in == .formData }

        let queryHasOpt = query.contains(where: { $0.required == false })
        let bodyHasOpt = body.contains(where: { $0.required == false })

        let urlParams = query.isEmpty ? "[:]" : "[\(query.map({ "\"\($0.nameSwiftString)\": \($0.nameSwiftString)" }).joined(separator: ", "))]\(queryHasOpt ? ".unopt()" : "")"
        let bodyParams = body.isEmpty ? "[:]" : "[\(body.map({ "\"\($0.name)\": \($0.name)" }).joined(separator: ", "))]\(bodyHasOpt ? ".unopt()" : "")"
        let formParams = form.isEmpty ? "[]" : "[\(form.map({ $0.moyaFormDataString }).joined(separator: ", "))].compactMap({ $0 })"

        if form.isEmpty == false {
            return ".uploadCompositeMultipart(\(formParams), urlParameters: \(urlParams))"
        } else if body.isEmpty && query.isEmpty {
            return ".requestPlain"
        } else if body.count == 1, query.isEmpty {
            return ".requestJSONEncodable(\(body[0].name))"
        } else {
            return ".requestCompositeParameters(bodyParameters: \(bodyParams), bodyEncoding: JSONEncoding(), urlParameters: \(urlParams))"
        }
    }

    var moyaTaskHeaders: String {
        let header = parameters.filter { $0.in == .header }
        var headerStrings = header.map({ "(\"\($0.name)\", \($0.nameSwiftString))" })
        if let type = consumes.first(where: { $0 != "*/*" }) {
            headerStrings.append("(\"Content-Type\", \"\(type)\")")
        }
        return headerStrings.isEmpty ? "nil" : "Dictionary<String, Any?>(dictionaryLiteral: \(headerStrings.joined(separator: ", "))).unoptString()"
    }

    func moyaTaskAuth(type: AuthorizationType) -> String {
        return (hasAuthorization ? type : AuthorizationType.none).moyaString
    }

    var firstSuccessResponseType: String {
        if let key = responses.keys.sorted().first, let primitive = responses[key]?.primitive {
            return primitive.typeSwiftString
        } else {
            return "Void"
        }
    }

    func moyaResponseDecoder(responseName: String, indentLevel: Int = 2) -> String {
        let primitives = responses.reduce(into: [String: PrimitiveObject]()) { (result, kv) in
            result[kv.key] = kv.value.primitive
        }

        let keys = primitives.keys.sorted()

        var baseIndent = ""
        for _ in 0..<indentLevel { baseIndent += indent }

        var strings: [String] = []
        strings.append("\(baseIndent)switch \(responseName).statusCode {")
        for key in keys {
            let primitive = primitives[key]!
            if primitive.type == .none {
                strings.append("\(baseIndent)case \(key): return Void()")
            } else {
                strings.append("\(baseIndent)case \(key): return try JSONDecoder().decodeSafe(\(primitive.typeSwiftString).self, from: \(responseName).data)")
            }
        }
        strings.append("\(baseIndent)default: throw ResponseDecodeError.unknowCode")
        strings.append("\(baseIndent)}")

        return strings.joined(separator: "\n")
    }
}
