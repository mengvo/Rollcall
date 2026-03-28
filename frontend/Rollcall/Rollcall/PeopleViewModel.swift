//
//  PeopleViewModel.swift
//  Rollcall
//
//  Created by Mengzhen Vo on 3/28/26.
//

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
            print(response)
            people = response
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
