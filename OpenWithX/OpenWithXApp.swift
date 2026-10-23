import SwiftUI

@main
struct OpenWithXApp: App {
    @StateObject private var failureInbox = OpenFailureInbox()

    var body: some Scene {
        Window("OpenWithX", id: "main") {
            ContentView(failureInbox: failureInbox)
        }
    }
}
