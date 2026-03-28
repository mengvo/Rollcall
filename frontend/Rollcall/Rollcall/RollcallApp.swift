import SwiftUI

@main
struct RollcallApp: App {
    @StateObject private var authManager = AuthManager()

    var body: some Scene {
        WindowGroup {
            if authManager.isAuthenticated {
                TabView {
                    MatchView(authManager: authManager)
                        .tabItem {
                            Image(systemName: "camera.fill")
                            Text("Scan")
                        }

                    PeopleDirectoryView()
                        .tabItem {
                            Image(systemName: "person.3.fill")
                            Text("People")
                        }
                }
            } else {
                AuthView(authManager: authManager)
            }
        }
    }
}
