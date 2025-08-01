/*
import Foundation
import SQLite3

// MARK: - Data Models
struct Commander_ {
    let name: String
    let colorIdentity: String
    let cmc: Int
    let hasPartner: Bool
    let partnerWith: String?
}

struct ScryfallResponse: Codable {
    let data: [Card_]
    let has_more: Bool
    let next_page: String?
}

struct Card_: Codable {
    let name: String?
    let oracle_text: String?
    let color_identity: [String]
    let cmc: Double
    let card_faces: [CardFace]?
}

struct CardFace: Codable {
    let name: String
    let oracle_text: String?
}

// MARK: - Database Manager
class DatabaseManager {
    private var db: OpaquePointer?
    
    init(dbPath: String) {
        openDatabase(dbPath: dbPath)
        
        do {
            try dropAllTables() }
        catch{  print("❌ Database creation failed: \(error)") }
    
        createTable()
    }
    
    deinit {
        sqlite3_close(db)
    }
    
    private func openDatabase(dbPath: String) {
        if sqlite3_open(dbPath, &db) == SQLITE_OK {
            print("Successfully opened connection to database at \(dbPath)")
        } else {
            print("Unable to open database")
        }
    }
    
    private func createTable() {
        let createTableString = """
            CREATE TABLE IF NOT EXISTS commanders(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT UNIQUE NOT NULL,
            color_identity TEXT NOT NULL,
            cmc INTEGER NOT NULL,
            has_partner BOOLEAN,
            partner_with TEXT);
            """
        
        if sqlite3_exec(db, createTableString, nil, nil, nil) == SQLITE_OK {
            print("Commanders table created successfully")
        } else {
            print("Commanders table could not be created")
        }
    }
    
    
    func dropAllTables() throws {
        //guard let db = db else { return }
        let dropStatements =
        "DROP TABLE IF EXISTS commanders;"
        
        
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, dropStatements, -1, &statement, nil) == SQLITE_OK {
            // Drop tables in correct order due to foreign key constraints
            
            defer {
                sqlite3_finalize(statement)
            }
            if sqlite3_step(statement) != SQLITE_DONE {
                throw SQLiteError.step(message: "msg")
            }
            print("🗑️ Dropped all existing tables")
        }
    }
    
    func insertCommander(_ commander: Commander_) -> Bool {
        let insertSQL = """
            INSERT OR REPLACE INTO commanders 
            (name, color_identity, cmc, has_partner, partner_with) 
            VALUES (?, ?, ?, ?, ?);
            """
        
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, insertSQL, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, (commander.name as NSString).utf8String, -1, nil)
            sqlite3_bind_text(statement, 2, (commander.colorIdentity as NSString).utf8String, -1, nil)
            sqlite3_bind_int(statement, 3, Int32(commander.cmc))
            sqlite3_bind_int(statement, 4, commander.hasPartner ? 1 : 0)
            
            if let partnerWith = commander.partnerWith {
                sqlite3_bind_text(statement, 5, (partnerWith as NSString).utf8String, -1, nil)
            } else {
                sqlite3_bind_null(statement, 5)
            }
            
            if sqlite3_step(statement) == SQLITE_DONE {
                sqlite3_finalize(statement)
                return true
            }
        }
        
        sqlite3_finalize(statement)
        return false
    }
    
    func getAllCommandersAlphabetical() -> [Commander_] {
        let querySQL = "SELECT name, color_identity, cmc, has_partner, partner_with FROM commanders ORDER BY name ASC;"
        var statement: OpaquePointer?
        var commanders: [Commander_] = []
        
        if sqlite3_prepare_v2(db, querySQL, -1, &statement, nil) == SQLITE_OK {
            while sqlite3_step(statement) == SQLITE_ROW {
                let name = String(cString: sqlite3_column_text(statement, 0))
                let colorIdentity = String(cString: sqlite3_column_text(statement, 1))
                let cmc = sqlite3_column_int(statement, 2)
                let hasPartner = sqlite3_column_int(statement, 3) == 1
                
                var partnerWith: String?
                if let partnerWithCString = sqlite3_column_text(statement, 4) {
                    partnerWith = String(cString: partnerWithCString)
                }
                
                let commander = Commander_(
                    name: name,
                    colorIdentity: colorIdentity,
                    cmc: Int(cmc),
                    hasPartner: hasPartner,
                    partnerWith: partnerWith
                )
                commanders.append(commander)
            }
        }
        
        sqlite3_finalize(statement)
        return commanders
    }
}

// MARK: - Scryfall Scraper
class ScryfallScraper {
    private let session = URLSession.shared
    private let dbManager: DatabaseManager
    
    init(dbManager: DatabaseManager) {
        self.dbManager = dbManager
    }
    
    func scrapeCommanders() async {
        var currentURL = "https://api.scryfall.com/cards/search?order=edhrec&q=(game%3Apaper)+legal%3Acommander+is%3Acommander"
        var allCommanders: [Commander_] = []
        
        repeat {
            do {
                print("Fetching: \(currentURL)")
                
                guard let url = URL(string: currentURL) else {
                    print("Invalid URL: \(currentURL)")
                    break
                }
                
                let (data, _) = try await session.data(from: url)
                let response = try JSONDecoder().decode(ScryfallResponse.self, from: data)
                
                // Process cards from current page
                let commanders = processCards(response.data)
                allCommanders.append(contentsOf: commanders)
                
                print("Processed \(commanders.count) commanders from current page")
                print("First card: \(commanders.first!)")
                
                
                // Check if there are more pages
                if response.has_more, let nextPage = response.next_page {
                    currentURL = nextPage
                    // Add delay to be respectful to the API
                    try await Task.sleep(nanoseconds: 10_000_000) // 0.1 seconds
                } else {
                    break
                }
                
            } catch {
                print("Error fetching data: \(error)")
                break
            }
        } while true
        
        print("Total commanders found: \(allCommanders.count)")
        
        // Save to database
        await saveToDatabase(allCommanders)
        
        // Save to JSON file
        await saveToJSON(allCommanders)
    }
    
    private func processCards(_ cards: [Card_]) -> [Commander_] {
        var commanders: [Commander_] = []
        
        for card in cards {
            // Handle double-faced cards
            if let cardFaces = card.card_faces {
                for face in cardFaces {
                    if let commander = processCardData(
                        name: face.name,
                        oracleText: face.oracle_text,
                        colorIdentity: card.color_identity,
                        cmc: card.cmc
                    ) {
                        commanders.append(commander)
                    }
                }
            } else {
                // Handle single-faced cards
                if let name = card.name,
                   let commander = processCardData(
                    name: name,
                    oracleText: card.oracle_text,
                    colorIdentity: card.color_identity,
                    cmc: card.cmc
                   ) {
                    commanders.append(commander)
                }
            }
        }
        
        return commanders
    }
    
    private func processCardData(
        name: String,
        oracleText: String?,
        colorIdentity: [String],
        cmc: Double
    ) -> Commander_? {
        
        let colorIdentityString = colorIdentity.joined(separator: "")
        let cmcInt = Int(cmc)
        
        // Parse partner information
        var hasPartner = false
        var partnerWith: String?
        
        if let oracle = oracleText {
            let oracleLower = oracle.lowercased()
            
            if oracleLower.contains("partner ") {
                hasPartner = true
            } else if oracleLower.contains("partner with") {
                hasPartner = true
                partnerWith = extractPartnerWithName(from: oracle)
            }
        }
        
        return Commander_(
            name: name,
            colorIdentity: colorIdentityString,
            cmc: cmcInt,
            hasPartner: hasPartner,
            partnerWith: partnerWith
        )
    }
    
    private func extractPartnerWithName(from oracleText: String) -> String? {
        // Look for "Partner with [Name]" pattern
        let pattern = #"[Pp]artner with ([^.\n]+)"#
        
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: [])
            let nsString = oracleText as NSString
            let results = regex.matches(in: oracleText, options: [], range: NSRange(location: 0, length: nsString.length))
            
            if let match = results.first {
                let range = match.range(at: 1)
                return nsString.substring(with: range).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        } catch {
            print("Regex error: \(error)")
        }
        
        return nil
    }
    
    private func saveToDatabase(_ commanders: [Commander_]) async {
        print("Saving to database...")
        var savedCount = 0
        
        for commander in commanders {
            if dbManager.insertCommander(commander) {
                savedCount += 1
            }
        }
        
        print("Saved \(savedCount) of \(commanders.count) commanders to database")
    }
    
    private func saveToJSON(_ commanders: [Commander_]) async {
        print("Saving to JSON file...")
        
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            
            // Convert commanders to a dictionary format for JSON
            let jsonData = commanders.map { commander in
                return [
                    "name": commander.name,
                    "color_identity": commander.colorIdentity,
                    "cmc": commander.cmc,
                    "has_partner": commander.hasPartner,
                    "partner_with": commander.partnerWith ?? NSNull()
                ] as [String: Any]
            }
            
            let data = try JSONSerialization.data(withJSONObject: jsonData, options: .prettyPrinted)
            
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let jsonURL = documentsPath.appendingPathComponent("commanders.json")
            
            try data.write(to: jsonURL)
            print("JSON file saved to: \(jsonURL.path)")
            
        } catch {
            print("Error saving JSON file: \(error)")
        }
    }
}

// MARK: - Main Application
class CommanderApp {
    private let dbManager: DatabaseManager
    private let scraper: ScryfallScraper
    
    init() {
        // Set up database path
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dbPath = documentsPath.appendingPathComponent("commanders.db").path
        
        self.dbManager = DatabaseManager(dbPath: dbPath)
        self.scraper = ScryfallScraper(dbManager: dbManager)
        
        print("Database path: \(dbPath)")
    }
    
    func run() async {
        print("Starting commander scraping...")
        await scraper.scrapeCommanders()
        
        print("\nQuerying all commanders alphabetically:")
        let commanders = dbManager.getAllCommandersAlphabetical()
        
        print("Total commanders in database: \(commanders.count)")
        print("First: \(commanders.first!)")

        
        for commander in commanders.prefix(20) { // Show first 10
            print("Name: \(commander.name)")
            print("Colors: \(commander.colorIdentity), CMC: \(commander.cmc)")
            let hasPartner = commander.hasPartner
            if hasPartner {
                print("Has Partner: \(commander.hasPartner)")
                if let partnerWith = commander.partnerWith {
                    print("Partner With: \(partnerWith)")
                }
            }
            print("---")
        }
        
        print("Total commanders in database: \(commanders.count)")
    }
}

// MARK: - Entry Point
//@main
struct ScryfallCommanderSearchAndSave {
    static func scryfallCommanderSearchAndSave()  {// async {
        let app = CommanderApp()
        Task{
            await app.run()
        }
    }
}
*/
