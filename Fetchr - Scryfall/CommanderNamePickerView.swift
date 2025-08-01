import SwiftUI

@MainActor
struct CommanderNamePickerView: View {
    @Binding var selectedName: String
    @Binding var isPresented: Bool
    
    @State var commanderName: String = ""
    @State var partnerName: String = ""
    @State private var searchLetters: String = ""
    @State private var allNamesByLetter: [String: [String]] = [:]
    @State private var filteredNames: [String] = []
    @StateObject private var CmdrsWithAttributes:  CommanderNamesLoader = CommanderNamesLoader(autoLoad: false)
    
    @State private var isPickingPartner = false
    @State private var hasPickedCommander = false
    @State private var showUsePartnerPrompt = false
    @State private var suggestedPartner: String = ""
    @State private var showAskToPickPartnerPrompt = false
    
    let steelGray = Color(white: 0.2745)
    let alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ".map { String($0) }
    let letterButtonSize = 35.0
    let nLetterColumns = 4
    let nListNames = 12
    
    var body: some View {

            VStack(spacing: 12) {

                if (!showUsePartnerPrompt && !showAskToPickPartnerPrompt && !hasPickedCommander) {
                    if !(filteredNames.count <= nListNames && !filteredNames.isEmpty )  {
                        Spacer()
                        
                        // On-screen letter buttons
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: nLetterColumns), spacing: 4) {
                            ForEach(alphabet, id: \.self) { letter in
                                Button(letter) {
                                    searchLetters.append(letter)
                                    filterNames()
                                }
                                .foregroundColor(.white)
                                .bold()
                                .padding(0)
                                .frame(height: letterButtonSize)
                                .frame(maxWidth: .infinity)
                                .background(Color.blue.opacity(0.2))
                                .cornerRadius(4)
                            }
                            Button("_") {
                                searchLetters.append(" ")
                                filterNames()
                            }
                            .frame(height: letterButtonSize)
                            .frame(maxWidth: .infinity)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(4)
                            
                            Button("⌫") {
                                if !searchLetters.isEmpty {
                                    searchLetters.removeLast()
                                    filterNames()
                                }
                            }
                            .frame(height: letterButtonSize)
                            .frame(maxWidth: .infinity)
                            .background(Color.red.opacity(0.2))
                            .cornerRadius(4)
                        }
                    }
                    
                    
                    if filteredNames.count <= nListNames && !filteredNames.isEmpty {
                        List(filteredNames, id: \.self) { name in
                            Button(name) {
                                //searchLetters = name
                                //selectedName = name
                                if isPickingPartner {
                                    partnerName = name
                                    suggestedPartner = name
                                    showUsePartnerPrompt = true
                                } else {
                                    commanderName = name
                                    handleCommanderSelection(name)
                                }
                                searchLetters = ""
                                filteredNames = []
                            }
                        }
                        .listStyle(PlainListStyle())
                    } else {
                        
                     
                            Text("Search: \(searchLetters)")
                                .font(.headline)
                                .foregroundColor(.white)
             
                    }
                }
                /*
                if selectedName != "" && selectedName != "Not Entered"{
                    Text("\(searchLetters)")
                        .font(.subheadline)
                        .bold()
                        .foregroundColor(.white)
                }
                */
                
                if !commanderName.isEmpty && !isPickingPartner && hasPickedCommander && !showUsePartnerPrompt && !showAskToPickPartnerPrompt {
                    Text("Commander:")
                        .bold()
                        .foregroundColor(.white)
                    Text("\(commanderName)")
                        .bold()
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                
                
                
                if showUsePartnerPrompt {
                    VStack(spacing: 8) {
                        Spacer()
                        Text("Commander:")
                            .foregroundColor(.white)
                        Text("\(commanderName)")
                            .bold()
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                        
                        Spacer()
                        
                        Text("Use Partner:")
                            .foregroundColor(.white)
                        Text("\(suggestedPartner) ?")
                            .foregroundColor(.white)
                            .bold()
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                        
                        HStack {
                            Button("Yes") {
                                partnerName = suggestedPartner
                                finalizeSelection()
                            }
                            .foregroundColor(.green)
                            
                            Button("No") {
                                finalizeSelection()
                            }
                            .foregroundColor(.red)
                        }
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)

                }
                if showAskToPickPartnerPrompt {
                    VStack(spacing: 8) {
                        Spacer()
                        Text("Commander:")
                            .foregroundColor(.white)
                        Text("\(commanderName)")
                            .bold()
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                        
                        Spacer()
                        Text("Would you like to choose a partner?")
                            .foregroundColor(.white)
                            .bold()
                        HStack {
                            Button("Yes") {
                                isPickingPartner = true
                                showAskToPickPartnerPrompt = false
                                filterToPartnerEligibleNames()
                            }
                            .foregroundColor(.green)
                            .bold()
                            
                            Button("No") {
                                finalizeSelection()
                            }
                            .foregroundColor(.red)
                            .bold()
                        }
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                
                
            /*
                HStack (spacing:30) {
                    if selectedName != "" && selectedName != "Not Entered"{
                        Button("Ok") {
                            // Check if commander has partner.
                            if self.commanderName == "" {
                                self.commanderName = selectedName
                                //selectedName = "Not Entered"
                            }
                            if checkCommanderForPartner(self.commanderName){
                                // Hide keyboard
                                // Ask if user wants to enter partner
                                //  - Yes => again but more filter
                                //  - No => isPresented = false, return binding name
                            }
                            
                            isPresented = false
                            // Return name data back to main view
                        }.bold()
                            .foregroundColor(.green)
                            .padding([.bottom],16)
                    }
                    
                    Button("Cancel") {
                        searchLetters = ""
                        filteredNames = []
                        isPresented = false
                        selectedName = "Not Entered"
                    }.foregroundColor(.red)
                    .padding([.bottom],16)
                }
        }
        .background(steelGray)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            loadCardNames()
        }
    }
    */
                HStack(spacing: 30) {
                    if !showUsePartnerPrompt && !isPickingPartner && !showAskToPickPartnerPrompt && hasPickedCommander {
                        Button("Ok") {
                                finalizeSelection()
                        }
                        .bold()
                        .foregroundColor(.green)
                        .padding(.bottom, 16)
                    }
                    Button("Cancel") {
                        searchLetters = ""
                        filteredNames = []
                        commanderName = ""
                        partnerName = ""
                        selectedName = "Not Entered"
                        isPresented = false
                    }
                    .foregroundColor(.red)
                    .padding(.bottom, 16)
                }
                .frame(maxWidth: .infinity)
            }
            .background(steelGray)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onAppear {
                loadCardNames()
                //loadCardNames()
            }
    }
    
    /*
    private func loadCardNames() async  {
        self.CmdrsWithAttributes = gdata.allCommanders
        await self.CmdrsWithAttributes.loadCommanderData()
        self.allNamesByLetter = self.CmdrsWithAttributes.sortedCommanderNames()
        print(self.allNamesByLetter)
        filterNames()
    }
    */
    private func loadCardNames() {
     
        Task{
            await self.CmdrsWithAttributes.commanderData(commanders: DatabaseManager.getCommanders())
            //await self.CmdrsWithAttributes.commanderData(commanders: scryfallCommanders)
            
            //self.allNamesByLetter = self.CmdrsWithAttributes.sortedCommanderNames()
            self.allNamesByLetter = self.CmdrsWithAttributes.sortedCommanderNames()
        }
        filterNames()
        
        
    }
    
    private func checkCommanderForPartner(_ name: String) -> Bool {
        self.CmdrsWithAttributes.cards.first(where: { $0.card_name == name })?.has_partner ?? false
    }
    
    private func autoSelectPartner() -> String {
        guard let partner_with_whom = self.CmdrsWithAttributes.cards.first(where: { $0.card_name == selectedName })?.partner_with else {
            print("No partners found for \(selectedName).")
            return " "}
        self.partnerName = partner_with_whom
        return selectedName
    }
    
    func inputPartnerName() {
        //  Show the NamePicker View again
        //  - with cards filtered for
        //  -
    }
    
    private func filterToPartnerEligibleNames() {
        let eligible = CmdrsWithAttributes.cards.filter { $0.has_partner ?? false}
        var byLetter: [String: [String]] = [:]
        for card in eligible {
            let first = String(card.card_name.prefix(1)).uppercased()
            byLetter[first, default: []].append(card.card_name)
        }
        allNamesByLetter = byLetter
    }
    
    private func handleCommanderSelection(_ name: String) {
        guard let card = CmdrsWithAttributes.cards.first(where: { $0.card_name == name }) else {
            finalizeSelection()
            return
        }
        
        if let partner = card.partner_with {
            if partner != "partner" {
                suggestedPartner = partner
                showUsePartnerPrompt = true}
            else {
                showAskToPickPartnerPrompt = true }
        } else if card.has_partner ?? false   {
            showAskToPickPartnerPrompt = true
        } else {
            //finalizeSelection()
            hasPickedCommander = true
        }
    }
    
    private func finalizeSelection() {
        var namesToReturn = [commanderName]
        if !partnerName.isEmpty && partnerName != "partner" {
            namesToReturn.append(partnerName)
        }
        selectedName = namesToReturn.joined(separator: "//")
        isPresented = false
    }
    
    
    private func filterNames() {
        guard !searchLetters.isEmpty else {
            filteredNames = []
            return
        }
        
        let firstLetter = String(searchLetters.prefix(1)).uppercased()
        let candidates = allNamesByLetter[firstLetter] ?? []
   
        
        filteredNames = candidates.filter {
            $0.lowercased().hasPrefix(searchLetters.lowercased())
        }
        
        print(firstLetter, filteredNames.count)
    }
}




struct CommanderNamePickerView_Previews: PreviewProvider {
    struct PreviewWrapper: View {
        @State private var selectedName: String = ""
        @State private var isPresented: Bool = true
        @State var scryfallCommanders : [Commander_] = []
        
        var body: some View {
            if isPresented {

                CommanderNamePickerView(
                    selectedName: $selectedName,
                    isPresented: $isPresented
                )
            }
        }
    }
    
    static var previews: some View {
        PreviewWrapper()
            .preferredColorScheme(.dark)
            .previewLayout(.sizeThatFits)
            .padding()
    }
}
