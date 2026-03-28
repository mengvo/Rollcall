import SwiftUI
import Supabase
import Combine

@MainActor
class PeopleViewModel: ObservableObject {
    @Published var people: [Person] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    func fetchPeople() async {
        isLoading = true
        errorMessage = nil
        do {
            let response: [Person] = try await supabase
                .from("person")
                .select()
                .execute()
                .value

            // Preserve seen status from current list
            let seenIds = Set(people.filter { $0.seen }.map { $0.id })

            people = response.map { person in
                var p = person
                p.seen = seenIds.contains(p.id)
                return p
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func markSeen(id: Int) {
        if let index = people.firstIndex(where: { $0.id == id }) {
            people[index].seen = true
        }
    }

    var seenCount: Int {
        people.filter { $0.seen }.count
    }

    var totalCount: Int {
        people.count
    }
    
    func deletePerson(id: Int) async {
        // Grab the image filename before removing
        let imageUrl = people.first(where: { $0.id == id })?.imageUrl
        
        // Remove locally first so List animation stays consistent
        people.removeAll { $0.id == id }
        
        do {
            if let imageUrl = imageUrl {
                try await supabase.storage
                    .from("face")
                    .remove(paths: [imageUrl])
            }
            
            try await supabase
                .from("person")
                .delete()
                .eq("id", value: id)
                .execute()
        } catch {
            errorMessage = error.localizedDescription
            await fetchPeople()
        }
    }
}
