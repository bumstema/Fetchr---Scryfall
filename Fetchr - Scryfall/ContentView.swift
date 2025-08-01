import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [Item]

    @State var commanders: [Commander_] = []

    @State private var selectedName: String = ""
    @State private var isPresented: Bool = true
    @State private var isLoading: Bool = false
    
    
    var body: some View {
        
        VStack(spacing: 24){
            Text("Fetchr - Scryfall")
                .font(.title)
            
            
            VStack{
                Button(action: {isLoading = true
                    Task{
                      scryfallSearch()
                        isLoading = false

                    }
                } , label: {Text("Get Data from Scryfall")})
                
                if isLoading {
                    Text("Loading")
                }
         
            }
            
            
            NavigationSplitView {
                List {
                    ForEach(items) { item in
                        NavigationLink {
                            
                           
                                // View inside
                                CommanderNamePickerView(
                                    selectedName: $selectedName,
                                    isPresented: $isPresented
                                )
                            
                                
                            } label: {
                                Text(item.timestamp, format: Date.FormatStyle(date: .numeric, time: .standard))
                            }
                        
                    }
                    .onDelete(perform: deleteItems)
                }
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        EditButton()
                    }
                    ToolbarItem {
                        Button(action: addItem) {
                            Label("Add Item", systemImage: "plus")
                        }
                    }
                }
            } detail: {
                Text("Select an item")
            }
        }
    }

    private func addItem() {
        withAnimation {
            let newItem = Item(timestamp: Date())
            modelContext.insert(newItem)
        }
    }

    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(items[index])
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Item.self, inMemory: true)
}
