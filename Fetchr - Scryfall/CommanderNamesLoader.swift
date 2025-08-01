import Foundation

/// Data structure representing a Magic: The Gathering card with commander information
public struct Card: Codable, Identifiable, Hashable {
    public let id = UUID()
    public let card_name: String
    public let color_identity: String
    public let cmc: String
    public let has_partner: Bool?
    public let partner_with: String?
    
    public init(card_name: String, color_identity: String, cmc: String, has_partner: Bool?, partner_with: String) {
        self.card_name = card_name
        self.color_identity = color_identity
        self.cmc = cmc
        self.has_partner = has_partner ?? false
        self.partner_with = partner_with ?? ""
    }

    public init(card_name: String, color_identity: String, cmc: String) {
        self.card_name = card_name
        self.color_identity = color_identity
        self.cmc = cmc
        self.has_partner = nil
        self.partner_with = nil
    }
    
    public init(commander: Commander_) {
        self.card_name = commander.name
        self.color_identity = commander.colorIdentity
        self.cmc = String(commander.cmc)
        self.has_partner = commander.hasPartner
        self.partner_with = commander.partnersWith
        
    }

    
    // Custom Hashable implementation since we have a UUID
    public func hash(into hasher: inout Hasher) {
        hasher.combine(card_name)
        hasher.combine(color_identity)
        hasher.combine(cmc)
    }
    
    public static func == (lhs: Card, rhs: Card) -> Bool {
        return lhs.card_name == rhs.card_name &&
               lhs.color_identity == rhs.color_identity &&
               lhs.cmc == rhs.cmc
    }
    
    /// Parsed color identity as an array
    public var colorIdentityArray: [String] {
        return color_identity.compactMap { String($0) }
    }
    
    /// Converted mana cost as integer
    public var convertedManaCost: Int {
        return Int(cmc) ?? 0
    }
    
    /// Color identity description
    public var colorDescription: String {
        let colors: [String: String] = [
            "W": "White",
            "U": "Blue", 
            "B": "Black",
            "R": "Red",
            "G": "Green"
        ]
        
        let colorNames = colorIdentityArray.compactMap { colors[$0] }
        
        if colorNames.isEmpty {
            return "Colorless"
        } else if colorNames.count == 1 {
            return colorNames.first!
        } else {
            return colorNames.joined(separator: ", ")
        }
    }
}

/// Loads and manages commander name data from JSON files
@MainActor
public class CommanderNamesLoader: ObservableObject {
    @Published public var names: Set<String> = []
    @Published public var cards: [Card] = []
    @Published public var isLoaded = false
    @Published public var loadingError: String?
    
    // Cached search results for performance
    private var searchResultsCache: [String: [Card]] = [:]
    private let maxCacheSize = 100
    
    public init(autoLoad: Bool = false)  {
        if autoLoad{
            
        }
    }
    
    // MARK: - Data Loading
    
    public func loadCommanderData() async {
         await loadFromBundle()
    }
    
    
    public func commanderData(commanders : [Commander_]) async {
        //let commanders = scryfallSearch()
        print("Loading \(commanders.count) [Commander_] into [Card] format")
        
        let defaultCards = commanders.map {
            Card(commander: $0)
        }
        
        print("Loaded \(defaultCards.count) [Card] format")

        //DispatchQueue.main.async {
            self.cards = defaultCards
            self.names = Set(defaultCards.map { $0.card_name })
            self.isLoaded = true
            self.loadingError = nil
            print("✅ Loaded \(self.cards.count) commander names from Scryfall import.")
       // }
        
        //self.sortedCommanderNames()
    }
    
    private func loadFromBundle() async {
        // Try to load the main commander data file
       // let testBundle = Bundle(for: type(of: self))
       // guard let url = testBundle.url(forResource: "all_commander_names-colours", withExtension: "json") else{
        //    print("x")
        //    return
        //}

        guard let url = Bundle.main.url(forResource: "all_commander_names-colours", withExtension: "json") else {
            // Fallback to alternative file
           loadFallbackData()
        return
        }
        
        do {
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode([Card].self, from: data)
            
           
            self.cards = decoded
            self.names = Set(decoded.map { $0.card_name })
            self.isLoaded = true
            self.loadingError = nil
            print(url)
            print("✅ Loaded from bundle - \(self.names.count) commander names - \(self.totalWithPartner()) with partner.")

        
        } catch {
            print("❌ Failed to load commander data from bundle: \(error)")
            loadingError = "Failed to load commander data: \(error.localizedDescription)"
            loadFallbackData()
        }
    }
    
    private func loadFallbackData() {
        // Try alternative file
        
        print("⚠️...Attempting to load fallback JSON data...")
        //FileManager.SearchPathDomainMask(for: "all_commander_names-colours", in: .allDomainsMask)
        let documentsPath = FileManager.default.urls(for: .documentDirectory , in: .userDomainMask)
        print(documentsPath)
        let jsonURL = documentsPath[0].appendingPathComponent("Podable/podable/data/all_commander_names-sorted_by_letter.json")
        print(jsonURL)

        
        guard let url = Bundle.main.url(forResource: "all_commander_names-sorted_by_letter", withExtension: "json") else {
            createDefaultData()
            return
        }
        
        do {
            let data = try Data(contentsOf: url)
            // This file might have a different structure, so we need to handle it
            if let jsonObject = try JSONSerialization.jsonObject(with: data) as? [String] {
                // Simple array of names
                let defaultCards = jsonObject.map { name in
                    Card(card_name: name, color_identity: "", cmc: "0")
                }
                
                DispatchQueue.main.async {
                    self.cards = defaultCards
                    self.names = Set(jsonObject)
                    self.isLoaded = true
                    self.loadingError = nil
                    print("✅ Loaded \(self.names.count) commander names from fallback file")
                }
            }
        } catch {
            print("❌ Failed to load fallback commander data: \(error)")
            createDefaultData()
        }
    }
    
    private func createDefaultData() {
        // Create a minimal set of default commanders if all else fails
        let defaultCommanders = [
            "Atraxa, Praetors' Voice",
            "Edgar Markov",
            "The Ur-Dragon",
            "Kaalia of the Vast",
            "Meren of Clan Nel Toth",
            "Rhys the Redeemed",
            "Narset, Enlightened Master",
            "Prossh, Skyraider of Kher",
            "Oloro, Ageless Ascetic",
            "Animar, Soul of Elements"
        ]
        
        let defaultCards = defaultCommanders.map { name in
            Card(card_name: name, color_identity: "", cmc: "0")
        }
        
        DispatchQueue.main.async {
            self.cards = defaultCards
            self.names = Set(defaultCommanders)
            self.isLoaded = true
            self.loadingError = "Using default commander data - full data failed to load"
            print("⚠️ Using default commander data")
        }
    }
    
    // MARK: - Search and Filtering
    
    /// Check if the collection contains a specific commander name
    public func contains(_ value: String) -> Bool {
        let cleanValue = value.formattedCommanderName()
        return names.contains { name in
            cleanValue.localizedCaseInsensitiveContains(name) || 
            name.localizedCaseInsensitiveContains(cleanValue)
        }
    }
    
    /// Find the closest matching commander name
    public func closestMatch(for value: String) -> String? {
        let cleanValue = value.formattedCommanderName().lowercased()
        var bestMatch: String?
        var bestScore = Double.infinity
        
        for name in names {
            let score = levenshteinDistance(cleanValue, name.lowercased())
            if score < bestScore {
                bestMatch = name
                bestScore = score
            }
        }
        
        // Only return if the match is reasonably close
        return bestScore <= Double(cleanValue.count) * 0.5 ? bestMatch : nil
    }
    
    /// Search for commanders matching a query string
    public func searchCommanders(query: String) -> [Card] {
        guard !query.isEmpty else { return [] }
        
        let cleanQuery = query.formattedCommanderName().lowercased()
        
        // Check cache first
        if let cachedResults = searchResultsCache[cleanQuery] {
            return cachedResults
        }
        
        let results = cards.filter { card in
            let name = card.card_name.lowercased()
            return name.contains(cleanQuery) ||
                   cleanQuery.contains(name) ||
                   levenshteinDistance(name, cleanQuery) <= 2
        }.sorted { $0.card_name < $1.card_name }
        
        // Cache the results
        cacheSearchResults(query: cleanQuery, results: results)
        
        return results
    }
    
    /// Get commanders by color identity
    public func commandersByColor(identity: String) -> [Card] {
        return cards.filter { $0.color_identity == identity }
            .sorted { $0.card_name < $1.card_name }
    }
    
    /// Get commanders by converted mana cost
    public func commandersByCMC(_ cmc: Int) -> [Card] {
        return cards.filter { $0.convertedManaCost == cmc }
            .sorted { $0.card_name < $1.card_name }
    }
    
    /// Get random commander suggestions
    public func randomCommanders(count: Int = 5) -> [Card] {
        return Array(cards.shuffled().prefix(count))
    }
    
    // MARK: - Utility Methods
    
    public func total() -> Int {
        return names.count
    }

    private func cardsWithPartner() -> [Card] {
        return cards.filter { $0.has_partner == true ?? false}
    }
    
    private func cardsWithoutPartnersWith() -> [Card] {
        return cardsWithPartner().filter( {$0.partner_with == "partner"} )
    }
    
    public func totalWithPartner() -> Int {
        return cardsWithPartner().count
    }
    
    public func doesCommanderHavePartner(name: String) -> Bool {
        if let hasPrtnr = cards.first(where: {$0.card_name == name})?.has_partner { return hasPrtnr }
        return false
    }
    
    public func whoDoesCommanderPartnerWith(name: String) -> [String] {
        guard let cmdrCard = cards.first(where: {$0.card_name == name}) else {return [""]}
        print("\n",cmdrCard,"\n")
        if let prtnrName = cmdrCard.partner_with, prtnrName != "partner" { return [prtnrName] }
        if let hasPrtnr = cmdrCard.has_partner { return cardsWithoutPartnersWith().map({$0.card_name}) }
        return [""]
    }
    
    public func sortedCommanderCards() -> [String: [Card]] {
        return Dictionary(grouping: self.cards) { String($0.card_name.first!) }
    }
    
    public func sortedCommanderNames() -> [String: [String]] {
        print("number of cards: \(self.cards.count)")
        let cardNames = self.cards.map { $0.card_name }
        print("number of cardNames: \(cardNames.count)")
        let grouped = Dictionary(grouping: cardNames) { String($0.first!).uppercased() }
        print("number of grouped: \(grouped.count)")
        let sortedValues = grouped.mapValues { $0.sorted(by: { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }) }
        
        print("sorted card names: \(sortedValues.count)")
        
        return sortedValues
    }

    
    /// Get all unique color identities
    public var allColorIdentities: [String] {
        return Array(Set(cards.map { $0.color_identity })).sorted()
    }
    
    /// Get statistics about the commander database
    public var availableCommandersStatistics: AvailableCommandersStatistics {
        return AvailableCommandersStatistics(
            totalCommanders: total(),
            uniqueColors: allColorIdentities.count,
            averageCMC: cards.compactMap { Double($0.cmc) }.reduce(0, +) / max(1, Double(cards.count)),
            colorlessCommanders: cards.filter { $0.color_identity.isEmpty }.count,
            multicolorCommanders: cards.filter { $0.color_identity.count > 1 }.count
        )
    }
    
    // MARK: - Private Helpers
    
    private func cacheSearchResults(query: String, results: [Card]) {
        // Maintain cache size limit
        if searchResultsCache.count >= maxCacheSize {
            // Remove oldest entries (simple strategy)
            let keysToRemove = Array(searchResultsCache.keys.shuffled().prefix(10))
            for key in keysToRemove {
                searchResultsCache.removeValue(forKey: key)
            }
        }
        
        searchResultsCache[query] = results
    }
    
    /// Calculate Levenshtein distance between two strings
    private func levenshteinDistance(_ s1: String, _ s2: String) -> Double {
        let s1Array = Array(s1)
        let s2Array = Array(s2)
        let s1Length = s1Array.count
        let s2Length = s2Array.count
        
        var matrix = Array(repeating: Array(repeating: 0, count: s2Length + 1), count: s1Length + 1)
        
        for i in 0...s1Length {
            matrix[i][0] = i
        }
        
        for j in 0...s2Length {
            matrix[0][j] = j
        }
        
        for i in 1...s1Length {
            for j in 1...s2Length {
                let cost = s1Array[i-1] == s2Array[j-1] ? 0 : 1
                matrix[i][j] = min(
                    matrix[i-1][j] + 1,      // deletion
                    matrix[i][j-1] + 1,      // insertion
                    matrix[i-1][j-1] + cost  // substitution
                )
            }
        }
        
        return Double(matrix[s1Length][s2Length])
    }
    
    // MARK: - Data Management
    
    public func clearCache() {
        searchResultsCache.removeAll()
    }
    
    public func reloadData() async {
   
        isLoaded = false
        loadingError = nil
        clearCache()
        Task {
            await loadCommanderData()
        }
    }
}

// MARK: - Supporting Data Structures

public struct AvailableCommandersStatistics {
    public let totalCommanders: Int
    public let uniqueColors: Int
    public let averageCMC: Double
    public let colorlessCommanders: Int
    public let multicolorCommanders: Int
    
    public init(totalCommanders: Int, uniqueColors: Int, averageCMC: Double, colorlessCommanders: Int, multicolorCommanders: Int) {
        self.totalCommanders = totalCommanders
        self.uniqueColors = uniqueColors
        self.averageCMC = averageCMC
        self.colorlessCommanders = colorlessCommanders
        self.multicolorCommanders = multicolorCommanders
    }
    
    public var formattedAverageCMC: String {
        return String(format: "%.1f", averageCMC)
    }
    
    public var multicolorPercentage: Double {
        return totalCommanders > 0 ? Double(multicolorCommanders) / Double(totalCommanders) * 100 : 0
    }
}


// MARK: - Commander Name Extensions

public extension String {
    /// Clean and format commander names
    func formattedCommanderName() -> String {
        let cleaned = self.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Handle partner commanders
        if cleaned.contains("//") {
            let parts = cleaned.components(separatedBy: "//")
            let cleanedParts = parts.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            return cleanedParts.joined(separator: " // ")
        }
        
        return cleaned
    }
    
    /// Check if this is a partner commander pairing
    var isPartnerPair: Bool {
        return contains("//")
    }
    
    /// Get the primary commander name (first part if partner pair)
    var primaryCommanderName: String {
        if isPartnerPair {
            let parts = components(separatedBy: "//")
            return parts.first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? self
        }
        return self
    }
    
    /// Get the partner name (second part if partner pair)
    var partnerName: String? {
        if isPartnerPair {
            let parts = components(separatedBy: "//")
            return parts.count > 1 ? parts[1].trimmingCharacters(in: .whitespacesAndNewlines) : nil
        }
        return nil
    }
    
    /// Capitalize first letter of each word
    var titleCased: String {
        return self.split(separator: " ").map { $0.prefix(1).uppercased() + $0.dropFirst().lowercased() }.joined(separator: " ")
    }
}


// MARK: - Color Identity Helpers

public extension CommanderNamesLoader {
    /// Get color combinations for filtering
    static var commonColorCombinations: [String: String] {
        return [
            "": "Colorless",
            "W": "White",
            "U": "Blue",
            "B": "Black", 
            "R": "Red",
            "G": "Green",
            "WU": "Azorius (W/U)",
            "WB": "Orzhov (W/B)",
            "WR": "Boros (W/R)",
            "WG": "Selesnya (W/G)",
            "UB": "Dimir (U/B)",
            "UR": "Izzet (U/R)",
            "UG": "Simic (U/G)",
            "BR": "Rakdos (B/R)",
            "BG": "Golgari (B/G)",
            "RG": "Gruul (R/G)",
            "WUB": "Esper (W/U/B)",
            "WUR": "Jeskai (W/U/R)",
            "WUG": "Bant (W/U/G)",
            "WBR": "Mardu (W/B/R)",
            "WBG": "Abzan (W/B/G)",
            "WRG": "Naya (W/R/G)",
            "UBR": "Grixis (U/B/R)",
            "UBG": "Sultai (U/B/G)",
            "URG": "Temur (U/R/G)",
            "BRG": "Jund (B/R/G)",
            "WUBR": "Four-Color (No Green)",
            "WUBG": "Four-Color (No Red)",
            "WURG": "Four-Color (No Black)",
            "WBRG": "Four-Color (No Blue)",
            "UBRG": "Four-Color (No White)",
            "WUBRG": "Five-Color (WUBRG)"
        ]
    }
}
