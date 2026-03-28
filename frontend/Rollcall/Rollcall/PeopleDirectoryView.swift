import SwiftUI

struct PeopleDirectoryView: View {
    @StateObject private var viewModel = PeopleViewModel()

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("People")
                .task {
                    await viewModel.fetchPeople()
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading {
            Spacer()
            ProgressView("Loading...")
            Spacer()
        } else if let error = viewModel.errorMessage {
            VStack(spacing: 12) {
                Text("Something went wrong")
                    .font(.headline)
                Text(error)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Button("Retry") {
                    Task { await viewModel.fetchPeople() }
                }
            }
        } else if viewModel.people.isEmpty {
            Text("No people found")
                .foregroundColor(.secondary)
        } else {
            List {
                ForEach(viewModel.people, id: \.id) { person in
                    HStack(spacing: 14) {
                        AsyncImage(url: URL(string: person.imageUrl ?? "")) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill()
                            case .failure:
                                placeholderAvatar(for: person)
                            case .empty:
                                ProgressView()
                            @unknown default:
                                placeholderAvatar(for: person)
                            }
                        }
                        .frame(width: 50, height: 50)
                        .clipShape(Circle())

                        Text("\(person.firstName) \(person.lastName)")
                                        .font(.body)

                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private func placeholderAvatar(for person: Person) -> some View {
        Circle()
            .fill(Color.blue.opacity(0.3))
            .frame(width: 50, height: 50)
            .overlay(
                Text(String(person.firstName.prefix(1)).uppercased())
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            )
    }
}
