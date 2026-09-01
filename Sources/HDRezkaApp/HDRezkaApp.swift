import SwiftUI
import HDRezkaCore

@main
struct HDRezkaApp: App {
    var body: some Scene {
        WindowGroup {
            AppRootView()
                .preferredColorScheme(.dark)
        }
    }
}
