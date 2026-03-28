import SwiftUI

@main
struct RollcallApp: App {
    @StateObject private var authManager = AuthManager()
    @StateObject private var peopleViewModel = PeopleViewModel()

    var body: some Scene {
        WindowGroup {
            if authManager.isAuthenticated {
                TabView {
                    ContentView(authManager: authManager, peopleViewModel: peopleViewModel)
                        .tabItem {
                            Image(systemName: "camera.fill")
                            Text("Enroll")
                        }
                    
                    MatchView(authManager: authManager, peopleViewModel: peopleViewModel)
                        .tabItem {
                            Image(systemName: "camera.fill")
                            Text("Match")
                        }
                    
                    PeopleDirectoryView(viewModel: peopleViewModel)
                        .tabItem {
                            Image(systemName: "person.3.fill")
                            Text("People")
                        }
                }
                .task {
                    await peopleViewModel.fetchPeople()
                }
            } else {
                AuthView(authManager: authManager)
            }
        }
    }
}
