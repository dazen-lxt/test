//
//  ContentView.swift
//  LiteTest
//
//  Created by Carlos Mario Muñoz on 5/03/25.
//

import Combine
import SwiftUI

struct ContentView: View {
    
    @StateObject private var viewModel: ViewModel = ViewModel()
    
    var body: some View {
        NavigationView {
            VStack {
                if viewModel.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(2)
                        .padding()
                } else if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage).foregroundStyle(.red)
                    Button("Retry") {
                        Task {
                            await viewModel.loadItems()
                        }
                    }
                } else {
                    List {
                        ForEach(viewModel.items) { item in
                            NavigationLink(destination: DetailView(viewModel: viewModel, itemId: item.id)) {
                                Text(item.title)
                            }

                        }
                    }
                }
            }
            .padding(0)
            .task {
                await viewModel.loadItems()
            }
            .navigationTitle("Items")
        }
    }
}

struct DetailView: View {
    
    @ObservedObject var viewModel: ViewModel
    var itemId: Int
    
    var body: some View {
        VStack(alignment: .leading) {
            if let item = viewModel.selectedItem {
                Text(item.title).fontWeight(.bold)
                Text(item.body)
                Spacer()
            } else {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                    .scaleEffect(2)
                    .padding().task {
                    await viewModel.getItemDetail(itemId: itemId)
                }
            }
        }.padding(10)
        .alert(viewModel.errorMessage ?? "", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK", role: .cancel) {
                viewModel.errorMessage = nil
            }
        }
    }
}

class ViewModel: ObservableObject {
    @Published var items: [Item] = []
    @Published var selectedItem: Item?
    @Published var errorMessage: String?
    @Published var isLoading: Bool = false
    
    private let service: ItemService = .init()
    
    @MainActor
    func loadItems() async {
        isLoading = true
        errorMessage = nil
        do {
            items = try await service.getItems()
        } catch {
            self.errorMessage = "Error fetching items: \(error.localizedDescription)"
        }
        isLoading = false
    }
    
    @MainActor
    func getItemDetail(itemId: Int) async {
        do {
            selectedItem = try await service.getItemDetail(itemId: itemId)
        } catch {
            self.errorMessage = "Error fetching item detail: \(error.localizedDescription)"
        }
    }
}

class ItemService {
    var cancellables = Set<AnyCancellable>()
    private let baseUrl: String = "https://jsonplaceholder.typicode.com"
    func getItems() async throws -> [Item] {
        let url = URL(string: "\(baseUrl)/posts")!
        try await Task.sleep(nanoseconds: 1_000_000_000)
        return try await withCheckedThrowingContinuation { continuation in
            URLSession.shared.dataTaskPublisher(for: url)
                .map(\.data)
                .decode(type: [Item].self, decoder: JSONDecoder())
                .receive(on: DispatchQueue.main)
                .sink(receiveCompletion: { completion in
                    if case let .failure(error) = completion {
                        continuation.resume(throwing: error)
                    }
                }, receiveValue: { items in
                    continuation.resume(returning: items)
                })
                .store(in: &cancellables)
        }
    }
    
    func getItemDetail(itemId: Int) async throws -> Item {
        let url = URL(string: "\(baseUrl)/posts/\(itemId)")!
        try await Task.sleep(nanoseconds: 2 * 1_000_000_000)
        return try await withCheckedThrowingContinuation { continuation in
            URLSession.shared.dataTaskPublisher(for: url)
                .map(\.data)
                .decode(type: Item.self, decoder: JSONDecoder())
                .receive(on: DispatchQueue.main)
                .sink(receiveCompletion: { completion in
                    if case let .failure(error) = completion {
                        continuation.resume(throwing: error)
                    }
                }, receiveValue: { item in
                    continuation.resume(returning: item)
                })
                .store(in: &cancellables)
        }
    }
}

struct Item: Codable, Identifiable {
    var userId: Int
    var id: Int
    var title: String
    var body: String
}

#Preview {
    ContentView()
}
