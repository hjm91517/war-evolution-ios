import SwiftUI

@main
struct WarForgeApp: App {
    var body: some Scene {
        WindowGroup {
            ZStack {
                Color.black.ignoresSafeArea()
                Text("战争演变")
                    .font(.largeTitle)
                    .foregroundColor(.white)
            }
        }
    }
}
