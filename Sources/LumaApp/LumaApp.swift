import SwiftUI
import AppKit

final class AppDelegate:NSObject,NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender:NSApplication)->Bool { false }
}
@main struct LumaApp:App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var model = AppModel()
    var body:some Scene {
        Window("Luma",id:"main") { MainView().environmentObject(model) }
            .defaultSize(width:1040,height:800).windowStyle(.titleBar)
            .commands {
                CommandGroup(replacing:.appTermination) { Button("Luma’dan çık") { model.requestQuit() }.keyboardShortcut("q",modifiers:.command) }
                CommandGroup(replacing:.newItem) {}
            }
        MenuBarExtra("Luma",systemImage:model.gateway.running ? "point.3.connected.trianglepath.dotted" : "arrow.triangle.branch") {
            MenuContent().environmentObject(model)
        }
    }
}
struct MenuContent:View {
    @EnvironmentObject var model:AppModel
    @Environment(\.openWindow) var openWindow
    var body:some View {
        Text(model.engineRunning ? "Bağlantı motoru açık" : "Bağlantı motoru kapalı")
        if model.gateway.running { Text("PS5 paylaşımı açık") }
        Divider()
        Button("Luma’yı göster") { NSApplication.shared.activate();openWindow(id:"main") }
        Button(model.engineRunning || model.gateway.running ? "Bağlantıyı kapat" : "Bağlantıyı aç") { if model.engineRunning || model.gateway.running { model.stopConnections() } else { model.startEngine() } }.disabled(model.busy)
        Button("Discord’u aç") { model.startEngine(openDiscord:true) }.disabled(model.busy)
        Button(model.gateway.running ? "PS5 paylaşımını durdur" : "PS5 kurulumu") { if model.gateway.running { model.stopGateway() } else { model.page = .console;NSApplication.shared.activate();openWindow(id:"main") } }
        Divider()
        Button("Çık") { model.requestQuit() }
    }
}
