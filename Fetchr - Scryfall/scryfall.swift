/**/
import Foundation
import SQLite

// MARK: - Data Models

public struct Commander_: Codable {
    let name: String
    let hasPartner: Bool?
    let partnersWith: String?
    let colorIdentity: String
    let cmc: Int
    
    func toJSON() -> [String: Any] {
        var dict: [String: Any] = [
            "name": name,
            "hasPartner": hasPartner ?? false,
            "partnersWith": partnersWith ?? "",
            "colorIdentity": colorIdentity,
            "cmc": cmc
        ]
        
        if let partnersWith = partnersWith {
            dict["partnersWith"] = partnersWith
        }
        
        return dict
    }
}

// MARK: - Scryfall API Client

class ScryfallClient {
    private let baseURL = "https://api.scryfall.com/cards/search?order=edhrec&q=(game%3Apaper)+legal%3Acommander+is%3Acommander"
    
    func fetchAllCommanders(completion: @escaping ([Commander_]) -> Void) {
        var allCommanders: [Commander_] = []
        fetchCommandersRecursively(url: baseURL) { commanders in
            allCommanders.append(contentsOf: commanders)
            completion(allCommanders)
        }
    }
    
    private func fetchCommandersRecursively(url: String, completion: @escaping ([Commander_]) -> Void) {
        guard let url = URL(string: url) else {
            print("Invalid URL")
            completion([])
            return
        }
        
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                print("Error fetching data: \(error.localizedDescription)")
                completion([])
                return
            }
            
            guard let data = data else {
                print("No data received")
                completion([])
                return
            }
            
            do {
                let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
                guard let json = json else {
                    print("Invalid JSON format")
                    completion([])
                    return
                }
                
                let hasMore = json["has_more"] as? Bool ?? false
                let nextPage = json["next_page"] as? String
                
                guard let cardsData = json["data"] as? [[String: Any]] else {
                    print("No card data found")
                    completion([])
                    return
                }
                
                let commanders = self.parseCommanders(cardsData)
                
                if hasMore, let nextPage = nextPage {
                    // Fetch next page recursively
                    self.fetchCommandersRecursively(url: nextPage) { nextCommanders in
                        completion(commanders + nextCommanders)
                    }
                } else {
                    completion(commanders)
                }
                
            } catch {
                print("Error parsing JSON: \(error.localizedDescription)")
                completion([])
            }
        }
        
        task.resume()
    }
    
    private func parseCommanders(_ cardsData: [[String: Any]]) -> [Commander_] {
        var commanders: [Commander_] = []
        
        for cardData in cardsData {
            let commander = parseCommanderData(cardData)
            if let commander = commander {
                commanders.append(commander)
            }
        }
        
        return commanders
    }
    
    private func parseCommanderData(_ cardData: [String: Any]) -> Commander_? {
        // Check if it's a double-faced card
        if let cardFaces = cardData["card_faces"] as? [[String: Any]], !cardFaces.isEmpty {
            // Use the front face for name and oracle text
            let frontFace = cardFaces[0]
            return extractCommanderInfo(frontFace, cardData: cardData)
        } else {
            // Single-faced card
            return extractCommanderInfo(cardData, cardData: cardData)
        }
    }
    
    private func extractCommanderInfo(_ faceData: [String: Any], cardData: [String: Any]) -> Commander_? {
        guard let name = faceData["name"] as? String else {
            print("Card name not found")
            return nil
        }
        
        let oracleText = faceData["oracle_text"] as? String ?? ""
        
        // Parse partner ability
        let hasPartner = oracleText.contains("Partner") || oracleText.contains("partner")
        var partnersWith: String? = nil
        
        if hasPartner && oracleText.contains("Partner with") {
            // Extract the specific partner name
            let pattern = "Partner with ([^\\n.,;()]+)"
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                let range = NSRange(oracleText.startIndex..<oracleText.endIndex, in: oracleText)
                if let match = regex.firstMatch(in: oracleText, options: [], range: range) {
                    if let partnerNameRange = Range(match.range(at: 1), in: oracleText) {
                        partnersWith = String(oracleText[partnerNameRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                }
            }
        }
        
        // Get color identity and CMC from the main card data
        let colorIdentityArray = cardData["color_identity"] as? [String] ?? []
        let colorIdentity = colorIdentityArray.joined()
        let cmc = Int(cardData["cmc"] as? Int ?? 0)
        
        return Commander_(
            name: name,
            hasPartner: hasPartner,
            partnersWith: partnersWith,
            colorIdentity: colorIdentity,
            cmc: cmc
        )
    }
}

// MARK: - Database Manager

public class DatabaseManager {
    public var db: Connection?
    public let commandersTable = Table("commanders")
    
    private let id = Expression<Int64>("id")
    private let name = Expression<String>("name")
    private let hasPartner = Expression<Bool>("hasPartner")
    private let partnersWith = Expression<String?>("partnersWith")
    private let colorIdentity = Expression<String>("colorIdentity")
    private let cmc = Expression<Int>("cmc")
    
    public init() {
        do {
            let path = NSSearchPathForDirectoriesInDomains(
                .documentDirectory, .userDomainMask, true
            ).first!
            let dbPath = "\(path)/commanders.sqlite3"
            db = try Connection(dbPath)
            
            try setupDatabase()
        } catch {
            print("Database initialization error: \(error.localizedDescription)")
        }
    }
    
    private func setupDatabase() throws {
        guard let db = db else { return }
        
        try db.run(commandersTable.create(ifNotExists: true) { table in
            table.column(id, primaryKey: .autoincrement)
            table.column(name, unique: true)
            table.column(hasPartner)
            table.column(partnersWith)
            table.column(colorIdentity)
            table.column(cmc)
        })
        
        // Create index for alphabetical ordering
        try db.run(commandersTable.createIndex(name, unique: true, ifNotExists: true))
    }
    
    public func saveCommanders(_ commanders: [Commander_]) {
        guard let db = db else { return }
        
        do {
            for commander in commanders {
                let query = commandersTable.filter(name == commander.name)
                let count = try db.scalar(query.count)
                
                if count == 0 {
                    // Insert new commander
                    let insert = commandersTable.insert(
                        name <- commander.name,
                        hasPartner <- commander.hasPartner ?? false,
                        partnersWith <- commander.partnersWith,
                        colorIdentity <- commander.colorIdentity,
                        cmc <- commander.cmc
                    )
                    try db.run(insert)
                } else {
                    // Update existing commander
                    let update = query.update(
                        hasPartner <- commander.hasPartner ?? false,
                        partnersWith <- commander.partnersWith,
                        colorIdentity <- commander.colorIdentity,
                        cmc <- commander.cmc
                    )
                    try db.run(update)
                }
            }
            print("Saved \(commanders.count) commanders to database")
        } catch {
            print("Database error: \(error.localizedDescription)")
        }
    }
    
    public func getAllCommanders() -> [Commander_] {
        guard let db = db else { return [] }
        
        var commanders: [Commander_] = []
        
        do {
            let query = commandersTable.order(name.asc)
            for row in try db.prepare(query) {
                let commander = Commander_(
                    name: row[name],
                    hasPartner: row[hasPartner],
                    partnersWith: row[partnersWith],
                    colorIdentity: row[colorIdentity],
                    cmc: row[cmc]
                )
                commanders.append(commander)
            }
        } catch {
            print("Database query error: \(error.localizedDescription)")
        }
        
        return commanders
    }
    
    public static func getCommanders() ->  [Commander_] {
        let shared = DatabaseManager()
       
        let allCmdrs = shared.getAllCommanders()
        print("Total loaded from DB: \(allCmdrs.count)")
        return allCmdrs
    }
}

// MARK: - JSON Manager

class JSONManager {
    func saveCommandersToJSON(_ commanders: [Commander_]) {
        let jsonArray = commanders.map { $0.toJSON() }
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: jsonArray, options: .prettyPrinted)
            let path = NSSearchPathForDirectoriesInDomains(
                .documentDirectory, .userDomainMask, true
            ).first!
            let filePath = "\(path)/commanders.json"
            
            try jsonData.write(to: URL(fileURLWithPath: filePath))
            
            print("Saved commanders to JSON file at: \(filePath)")
        } catch {
            print("Error saving JSON: \(error.localizedDescription)")
        }
    }
}

// MARK: - Main Execution

//@MainActor
func scryfallSearch() {
    let scryfallClient = ScryfallClient()
    let dbManager = DatabaseManager()
    let jsonManager = JSONManager()
    //var loadedCommanders : [Commander_] = []
    
    
    //let loadedCommanders = dbManager.getAllCommanders()
    //print("Total commanders in database: \(loadedCommanders.count) \(loadedCommanders.isEmpty)")
    
    //if loadedCommanders.isEmpty {
    Task{
        scryfallClient.fetchAllCommanders { commanders in
            // Save to database
            dbManager.saveCommanders(commanders)
            
            // Save to JSON
            jsonManager.saveCommandersToJSON(commanders)
            
            //loadedCommanders = commanders
            print("Successfully processed \(commanders.count) commanders")
            
        }
    }
    
    
    RunLoop.main.run(until: Date(timeIntervalSinceNow: 10))
}
//    guard  let names = loadedCommanders.first else {
//        print("Error")
//        return [] }
//    print("First: \(names)")
//    print("Last: \(loadedCommanders.last!)")
//    print()
    
    // Keep the program running until network operations complete
   
    
    //return loadedCommanders


//main()

/**/
