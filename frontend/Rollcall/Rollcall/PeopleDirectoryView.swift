import SwiftUI

import SwiftUI

struct PeopleDirectoryView: View {
    @ObservedObject var viewModel: PeopleViewModel

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("People")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Text("\(viewModel.seenCount)/\(viewModel.totalCount) seen")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
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
        } else if viewModel.people.isEmpty {
            Text("No people found")
                .foregroundColor(.secondary)
        } else {
            List {
                ForEach(viewModel.people, id: \.id) { person in
                    HStack(spacing: 14) {
                        AsyncImage(url: imageURL(for: person)) { phase in
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
                        .overlay(
                            Circle()
                                .stroke(person.seen ? Color.green : Color.clear, lineWidth: 3)
                        )

                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(person.firstName) \(person.lastName)")
                                .font(.body)
                            Text(person.seen ? "Seen" : "Not seen")
                                .font(.caption)
                                .foregroundColor(person.seen ? .green : .secondary)
                        }

                        Spacer()

                        if person.seen {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        let person = viewModel.people[index]
                        Task {
                            await viewModel.deletePerson(id: person.id)
                        }
                    }
                }
            }
        }
    }

    private func imageURL(for person: Person) -> URL? {
        guard let imageUrl = person.imageUrl else { return nil }
        return URL(string: "https://bnmvdnswrhkglqcghjrr.supabase.co/storage/v1/object/public/face/\(imageUrl)")
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
