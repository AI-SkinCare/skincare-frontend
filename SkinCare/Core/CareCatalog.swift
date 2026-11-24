import Foundation

struct CareCatalog: Decodable {
    struct Advice: Decodable { let body: String; let source: URL }
    struct Product: Decodable {
        let name, category: String
        let matches, absent: [String]
        let source: URL
    }
    let care, diet: [String: Advice]
    let aliases: [String: [String]]
    let products: [Product]

    static let bundled: Self? = {
        #if SWIFT_PACKAGE
        let bundle = Bundle.module
        #else
        let bundle = Bundle.main
        #endif
        guard let url = bundle.url(forResource: "care-guide", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(Self.self, from: data)
    }()

    func key(_ value: String) -> String {
        let normalized = value.lowercased().filter { !$0.isWhitespace }
        return aliases.first { $0.key == normalized || $0.value.contains(normalized) }?.key ?? ""
    }

    func matched(_ names: [String], avoiding: [String]?) -> [Product] {
        guard let avoiding else { return [] }
        let keys = Set(names.map(key))
        let exclusions = avoiding.map(key)
        return products.filter { product in
            !keys.isDisjoint(with: product.matches) && exclusions.allSatisfy { product.absent.contains($0) }
        }
    }
}
