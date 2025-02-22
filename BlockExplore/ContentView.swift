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

    private func addItem() {
        withAnimation {
            
//            let newItem = Item(timestamp: Date(),)
//            modelContext.insert(newItem)
        }
    }

    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(items[index])
            }
        }
    }
    
    func requestBlcokLogs() async throws {
        var subId = ""
        var blockNumber: String = ""
        var blockHash: String = ""
        
        let cancelled = NIOLockedValueBox(false)

        
        guard let infuraRPC = Bundle.main.object(forInfoDictionaryKey: "INFURA_RPC") as? String
        else {
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
        
        var logShown = false
        try! web3Ws.eth.subscribeToLogs(
            addresses: [contractAddress], topics: [topic],
            subscribed: {
                response in
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
                //The string 0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef is a hexadecimal representation of a topic in the Ethereum blockchain. Specifically, it is the Keccak-256 hash of the Transfer event signature in the ERC-20 token standard, which is: Transfer(address,address,uint256). This event is emitted when tokens are transferred between addresses.This topic is used to filter and identify Transfer events in the Ethereum logs. When subscribing to logs, you can use this topic to listen for all Transfer events emitted by a specific contract.
                if topicValue.topics.first?.hex()
                    == "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef"
                    && !logShown
                {
                    logShown = true
                    DispatchQueue.main.async {
                        blockNumber = topicValue.blockNumber?.hex().hexToDecimal() ?? ""
                        print("Topic Number: \(blockNumber)")
                        blockHash = topicValue.blockHash?.hex() ?? ""
                        print(
                            "在 \(blockNumber) 区块 \(blockHash) 交易中从 \(topicValue.topics[1].hex()) 转账 \(topicValue.data.hex().hexToDecimal() ?? "0") USDT 到 \(topicValue.topics[2].hex())"
                        )

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

#Preview {
    ContentView()
        .modelContainer(for: Item.self, inMemory: true)
}
