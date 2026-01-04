// swift
import SwiftUI

@main
struct HyroxAppApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                #if os(macOS)
                .ignoresSafeArea() // allow content to expand to full window on macOS
                #endif
        }
    }
}
