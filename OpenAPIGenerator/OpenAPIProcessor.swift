import Foundation

class SwaggerProcessor {
    let jsonURL: URL
    let customBaseURL: URL?
    private var json: NSDictionary?

    private(set) var schemes: [String: ObjectScheme] = [:]
    private(set) var operations: [Operation] = []
    private(set) var operationsByTag: [String: [Operation]] = [:]
    private(set) var host: String!
    private(set) var basePath: String!
    var jsonBaseURL: URL! {
        var comps = URLComponents()
        comps.scheme = "https"
        comps.host = host
        comps.path = basePath
        return comps.url
    }
    
    var baseURL: URL { customBaseURL ?? jsonBaseURL }

    init(jsonURL: URL, customBaseURL: URL?) {
        self.jsonURL = jsonURL
        self.customBaseURL = customBaseURL
    }

    func run() {
        let data = try! Data(contentsOf: jsonURL)
        json = try! JSONSerialization.jsonObject(with: data, options: []) as! NSDictionary
        host = json?["host"] as? String
        basePath = json?["basePath"] as? String
        
        let paths = json?["paths"] as? [String: Any] ?? [:]
        operations = []
        operationsByTag = [:]

        for (key, value) in paths {
            print("xxxv \(value)")
            let info = value as? [String: Any] ?? [:]
            operations.append(contentsOf: parserPath(path: key, info: info))
        }

        operations.forEach { op in
            op.tags.forEach { tag in
                var array = operationsByTag[tag] ?? []
                array.append(op)
                operationsByTag[tag] = array
            }
        }
    }

    private func parserPath(path: String, info: [String: Any]) -> [Operation] {
        var operations: [Operation] = []
        for (key, value) in info {
            let info = value as? [String: Any] ?? [:]
            print("zzzzz \(path)")
            operations.append(Operation(path: path, method: key, info: info, processor: self))
        }
        return operations
    }

    func parseObject(at ref: String?) {
        guard let ref = ref, schemes[ref] == nil else {
            return
        }

        schemes[ref] = ObjectScheme.placeholder

        let keyPath = ref.components(separatedBy: "/").dropFirst().joined(separator: ".")
        print("xxxx \(keyPath)")
        var  info = json?.value(forKeyPath: keyPath) as! [String: Any]
        info["title"] = keyPath.components(separatedBy: ".").last

        schemes[ref] = ObjectScheme(info: info, processor: self)
    }
}
