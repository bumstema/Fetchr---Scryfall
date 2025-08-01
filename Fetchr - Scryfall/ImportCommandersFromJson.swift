import Foundation

//struct Card: Codable {
//    let card_name: String
//    let color_identity: String
//    let cmc: String
//    let has_partner: Bool?
//    let partners_with: String?
//}

public class CommanderNamesAndPartners: ObservableObject {
    @Published var names: Set<String> = []
    @Published var cards: [Card] = []
    
    
    public init() {
        loadJSON()
    }
    
    private func loadJSON() {
        print("Loading JSON...")
        let testBundle = Bundle(for: type(of: self))
        if let url = testBundle.url(forResource: "all_commander_names-colours", withExtension: "json"),

        //if let url = Bundle.main.url(forResource: "all_commander_names-colours", withExtension: "json"),
        
        let data = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder().decode([Card].self, from: data) {
            self.cards = decoded
            self.names = Set(decoded.map { $0.card_name })
        }
    }
    
    public func contains(_ value: String) -> Bool {
        for name in names {
            if value.localizedCaseInsensitiveContains(name) {
                return true
            }
        }
        return false
    }
    
    public func closestMatch(in value: String) -> String? {
        var bestMatch: String?
        var bestMatchLength = Int.max  // Start with a very large number
        
        for name in names {
            if value.localizedCaseInsensitiveContains(name) {
                let lengthDifference = abs(value.count - name.count)
                if lengthDifference < bestMatchLength {
                    bestMatch = name
                    bestMatchLength = lengthDifference
                }
            }
        }
        
        return bestMatch
    }
    
    
    func cardsWithPartner() -> [Card] {
        return cards.filter { $0.has_partner ?? false }
    }

    func whoDoesCommanderPartnerWith(name: String) -> [Card] {
        return cards.filter { $0.partner_with == name }
    }
    
    
    public func total() -> Int {
        return names.count
    }
}

