import SwiftUI

@main
struct OpenWithXApp: App {
    @StateObject private var failureInbox = OpenFailureInbox()

    init() {
        AppText.configureSystemLocalization()
    }

    var body: some Scene {
        Window("OpenWithX", id: "main") {
            ContentView(failureInbox: failureInbox)
        }
    }
}
