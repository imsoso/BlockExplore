//
//  ContentView.swift
//  BlockExplore
//
//  Created by soso on 2025/2/21.
//

import SwiftUI
import SwiftData
import NIOConcurrencyHelpers
import Web3

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [Item]

    var body: some View {
        NavigationSplitView {
            List {
                ForEach(items) { item in
                    NavigationLink {
                        Text("Item at \(item.timestamp, format: Date.FormatStyle(date: .numeric, time: .standard))")
                    } label: {
                        VStack(alignment: .leading) {
                            Text("Time: ")
                                .font(.system(size: 16, weight: .bold))
                            + Text("\(item.timestamp, format: Date.FormatStyle(date: .numeric, time: .standard))")
                                .font(.system(size: 16, weight: .regular))
                            Text("Block Number: ")
                                .font(.system(size: 16, weight: .bold))
                            + Text("\(item.blockNumber)")
                                .font(.system(size: 16, weight: .regular))
                            Text("Block Hash: ")
                                .font(.system(size: 16, weight: .bold))
                            + Text("\(item.blockHash)")
                                .font(.system(size: 16, weight: .regular))
                            Text("Transfer log: ")
                                .font(.system(size: 16, weight: .bold))
                            + Text("\(item.transferLog)")
                                .font(.system(size: 16, weight: .regular))

                        }
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
    
    private func addItem() {
        Task {
            do {
                let newItem = try await requestBlcokLogs()
                withAnimation {
                    modelContext.insert(newItem)
                }
            } catch {
                print("Failed to request block logs: \(error)")
            }
        }
    }

    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(items[index])
            }
        }
    }
    
    func requestBlcokLogs() async throws -> Item {
        var subId = ""
        var blockNumber: String = ""
        var blockHash: String = ""
        var transferLog: String = ""

        var newItem: Item?
        
        let cancelled = NIOLockedValueBox(false)

        
        guard let infuraRPC = Bundle.main.object(forInfoDictionaryKey: "INFURA_RPC") as? String else {
            fatalError("INFURA_RPC not found in Configuration.xcconfig")
        }

        let baseURL = "wss://mainnet.infura.io/ws/v3/"
        let infuraWsUrl = baseURL + infuraRPC

        let web3Ws: Web3! = try? Web3(wsUrl: infuraWsUrl)
        let contractAddress = try EthereumAddress(
            hex: "0xdAC17F958D2ee523a2206206994597C13D831ec7", eip55: false)  // USDT Contract Address
        let topic = try [
            EthereumData(
                ethereumValue: "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef")
        ]
        
        var logShown = NIOLockedValueBox(false)
        return try await withCheckedThrowingContinuation { continuation in
            try! web3Ws.eth.subscribeToLogs(
                addresses: [contractAddress], topics: [topic],
                subscribed: { response in
                    subId = response.result ?? ""
                },
                onEvent: { log in
                    guard let topicValue = log.result else {
                        if cancelled.withLockedValue({ $0 }) {
                            switch log.error as? Web3Response<EthereumLogObject>.Error {
                            case .subscriptionCancelled(_):
                                // Expected
                                return
                            default:
                                break
                            }
                        }
                        return
                    }
                    if topicValue.topics.first?.hex()
                        == "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef"
                    {
                        if !logShown.withLockedValue({ let old = $0; $0 = true; return old }) {
                            blockNumber = topicValue.blockNumber?.hex().hexToDecimal() ?? ""
                            blockHash = topicValue.blockHash?.hex() ?? ""
                            transferLog = "Block \(blockNumber)  \(blockHash) \(topicValue.topics[1].hex()) transfer \(topicValue.data.hex().hexToDecimal() ?? "0") USDT to \(topicValue.topics[2].hex())"
                            newItem = Item(timestamp: Date(), blockNumber: blockNumber, blockHash: blockHash, transferLog: transferLog)
                            continuation.resume(returning: newItem!)
                        }
                    }
                    
                    if !cancelled.withLockedValue({
                        let old = $0
                        $0 = true
                        return old
                    }) {
                        try! web3Ws.eth.unsubscribe(
                            subscriptionId: subId,
                            completion: { unsubscribed in
                                print("Unsubscribed: \(unsubscribed)")
                            })
                    }
                }
            )
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Item.self, inMemory: true)
}
