import SwiftUI
import AppKit
import ServiceManagement
import LumaCore

private let canvas = Color(nsColor:.windowBackgroundColor)
struct Surface<Content:View>:View {
    @ViewBuilder var content:Content
    var body:some View { content.padding(22).frame(maxWidth:.infinity,alignment:.leading).background(Color(nsColor:.controlBackgroundColor),in:RoundedRectangle(cornerRadius:14)).overlay(RoundedRectangle(cornerRadius:14).stroke(Color.primary.opacity(0.08),lineWidth:1)) }
}
struct StatusLabel:View {
    var title:String;var active:Bool
    var body:some View { Label { Text(title) } icon: { Circle().fill(active ? Color.green : Color.secondary.opacity(0.45)).frame(width:6,height:6) }.font(.system(size:12)).foregroundStyle(.secondary) }
}
struct MainView:View {
    @EnvironmentObject var model:AppModel
    var body:some View {
        NavigationSplitView {
            List(selection:Binding<Page?>(get:{model.page},set:{if let p = $0 { model.page = p }})) {
                Section { ForEach(Page.allCases,id:\.self) { page in Label(page.rawValue,systemImage:page.icon).tag(page).padding(.vertical,4) } }
            }.listStyle(.sidebar).navigationSplitViewColumnWidth(min:180,ideal:200,max:240)
            .safeAreaInset(edge:.bottom) { HStack { Text("Luma").fontWeight(.medium);Spacer();Text(Product.version).foregroundStyle(.tertiary) }.font(.system(size:11)).padding(18) }
        } detail: {
            ScrollView {
                VStack(alignment:.leading,spacing:24) {
                    if let error = model.error { message(error,icon:"exclamationmark.triangle.fill",color:.orange) { model.error = nil } }
                    else if let notice = model.notice { message(notice,icon:"checkmark.circle.fill",color:.green) { model.notice = nil } }
                    switch model.page {
                    case .overview: Overview()
                    case .console: ConsoleSetup()
                    case .diagnostics: Diagnostics()
                    case .settings: SettingsPage()
                    case .about: AboutPage()
                    }
                }.padding(32).frame(maxWidth:820,alignment:.leading).frame(maxWidth:.infinity)
            }.background(canvas).navigationTitle(model.page.rawValue)
            .toolbar {
                ToolbarItem { StatusLabel(title:model.gateway.running ? "PS5 bağlı" : (model.engineRunning ? "Bağlantı açık" : "Bağlantı kapalı"),active:model.engineRunning) }
                ToolbarItem { Button { model.refresh() } label: { Label("Yenile",systemImage:"arrow.clockwise") }.help("Bağlantı durumunu yenile") }
            }
        }.frame(minWidth:920,minHeight:670).tint(.blue)
        .alert("PS5 paylaşımı açık",isPresented:$model.showStopEngine) { Button("Tamam",role:.cancel) {} } message: { Text("Motoru durdurmadan önce PS5 paylaşımını kapatın.") }
        .alert("Discord yeniden bağlansın mı?",isPresented:$model.showReconnectDiscord) {
            Button("Yeniden bağlan") { model.reconnectDiscord() }
            Button("Vazgeç",role:.cancel) {}
        } message: { Text("Discord kapatılıp Luma bağlantısıyla yeniden açılacak. Varsa devam eden sesli görüşmeniz kesilir.") }

    }
    func message(_ text:String,icon:String,color:Color,dismiss:@escaping ()->Void)->some View {
        HStack(alignment:.top,spacing:10) { Image(systemName:icon).foregroundStyle(color);Text(text).font(.callout).frame(maxWidth:.infinity,alignment:.leading);Button(action:dismiss) { Image(systemName:"xmark").foregroundStyle(.secondary) }.buttonStyle(.plain).help("Bildirimi kapat") }.padding(14).background(color.opacity(0.07),in:RoundedRectangle(cornerRadius:10))
    }
}
struct PageHeading:View {
    var title:String;var detail:String
    var body:some View { VStack(alignment:.leading,spacing:8) { Text(title).font(.system(size:28,weight:.semibold));Text(detail).font(.system(size:13)).foregroundStyle(.secondary).fixedSize(horizontal:false,vertical:true) } }
}
struct Overview:View {
    @EnvironmentObject var model:AppModel
    var body:some View {
        PageHeading(title:"Bağlantılar",detail:"Discord ve konsol bağlantınızı yönetin.")
        Surface {
            HStack(spacing:18) {
                Image(systemName:"power").font(.system(size:24)).foregroundStyle(model.engineRunning ? Color.blue : Color.secondary)
                VStack(alignment:.leading,spacing:5) {
                    Text(model.engineRunning || model.gateway.running ? "Bağlantı açık" : "Bağlantı kapalı").font(.headline)
                    Text(model.busy ? "İşlem sürüyor…" : "Kapatınca Mac bağlantısı ve PS5 paylaşımı durur.").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button(model.engineRunning || model.gateway.running ? "Bağlantıyı kapat" : "Bağlantıyı aç") {
                    if model.engineRunning || model.gateway.running { model.stopConnections() } else { model.startEngine(openDiscord:true) }
                }.buttonStyle(.borderedProminent).controlSize(.large).disabled(model.busy)
            }
        }

        Surface {
            VStack(spacing:24) {
                HStack(alignment:.top,spacing:18) {
                    deviceIcon("laptopcomputer")
                    VStack(alignment:.leading,spacing:7) { Text("Mac").font(.title3.weight(.semibold));Text("Discord’u bağlantı ve güncelleme desteğiyle açın.").font(.callout).foregroundStyle(.secondary);StatusLabel(title:model.engineRunning ? "Bağlantı hazır" : "Bağlı değil",active:model.engineRunning) }
                    Spacer()
                    VStack(alignment:.trailing,spacing:10) {
                        Button("Discord’u aç") { model.startEngine(openDiscord:true) }.controlSize(.large).disabled(model.busy)
                        Button("Yeniden bağlan") { model.showReconnectDiscord = true }.font(.caption).buttonStyle(.link).disabled(model.busy)
                    }
                }
                Divider()
                HStack(alignment:.top,spacing:18) {
                    deviceIcon("gamecontroller")
                    VStack(alignment:.leading,spacing:7) { Text("PlayStation 5").font(.title3.weight(.semibold));Text("Aynı yerel ağdaki konsolunuzla bağlantıyı paylaşın.").font(.callout).foregroundStyle(.secondary);StatusLabel(title:model.gateway.running ? "Paylaşım açık" : (model.clientIP.isEmpty ? "Kurulum gerekli" : "Paylaşım kapalı"),active:model.gateway.running) }
                    Spacer()
                    Button(model.gateway.running ? "Yönet" : "Kurulum") { model.page = .console }.controlSize(.large)
                }
            }
        }
        VStack(alignment:.leading,spacing:12) {
            Text("Yerel ağ").font(.headline)
            Surface { VStack(spacing:14) { InfoRow(label:"Mac IP adresi",value:model.network?.address ?? "Bağlantı bulunamadı");Divider();InfoRow(label:"Router",value:model.network?.router ?? "—");Divider();InfoRow(label:"Alt ağ maskesi",value:model.network?.mask ?? "—") } }
        }
        HStack { Label("Bağlantı sorunu mu var?",systemImage:"stethoscope").foregroundStyle(.secondary);Spacer();Button("Bağlantıyı kontrol et") { model.checkConnection() }.disabled(model.testing) }.font(.callout)
    }
    func deviceIcon(_ name:String)->some View { Image(systemName:name).font(.system(size:25,weight:.regular)).foregroundStyle(.blue).frame(width:52,height:52).background(Color.blue.opacity(0.07),in:RoundedRectangle(cornerRadius:12)) }
}
struct InfoRow:View {
    var label:String;var value:String;var accent = false
    var body:some View { HStack(alignment:.firstTextBaseline,spacing:16) { Text(label).foregroundStyle(.secondary);Spacer(minLength:12);Text(value).fontDesign(.monospaced).foregroundStyle(accent ? Color.blue : Color.primary).textSelection(.enabled) }.font(.system(size:12)) }
}
struct ConsoleSetup:View {
    @EnvironmentObject var model:AppModel
    var body:some View {
        PageHeading(title:"PS5 kurulumu",detail:"Mac ve konsol aynı yerel IPv4 ağına bağlı olmalıdır. Mac’in ağ bilgileri otomatik algılanır.")
        Surface {
            VStack(alignment:.leading,spacing:16) {
                Label("Konsol adresi",systemImage:"gamecontroller").font(.headline)
                Text("PS5’te Ayarlar → Ağ → Bağlantı Durumu → Bağlantı Durumunu Görüntüle bölümündeki IPv4 adresini girin.").font(.callout).foregroundStyle(.secondary).fixedSize(horizontal:false,vertical:true)
                HStack(spacing:12) {
                    TextField("PS5 IPv4 adresi",text:$model.clientIP).textFieldStyle(.roundedBorder).controlSize(.large).fontDesign(.monospaced).accessibilityLabel("PS5 IP adresi").disabled(model.gateway.running || model.busy)
                    Button("Temizle") { model.clientIP = "" }.disabled(model.clientIP.isEmpty || model.gateway.running || model.busy)
                }
                if let problem = model.clientValidation { Label(problem,systemImage:"exclamationmark.circle").font(.caption).foregroundStyle(.orange).fixedSize(horizontal:false,vertical:true) }
                if model.network == nil { Text("Devam etmek için Mac’i bir yerel ağa bağlayın.").font(.caption).foregroundStyle(.orange) }
            }
        }
        Surface {
            VStack(alignment:.leading,spacing:16) {
                HStack { Label("Paylaşım",systemImage:"network").font(.headline);Spacer();StatusLabel(title:model.gateway.running ? "Açık" : "Kapalı",active:model.gateway.running) }
                if !model.helperApproved {
                    Text("Ağ yönlendirmesi için macOS izni gerekir. Bu işlem bir kez yapılır.").font(.callout).foregroundStyle(.secondary)
                    Button(model.helperNeedsApproval ? "Sistem Ayarları’nı aç" : "Paylaşım iznini ayarla") { if model.helperNeedsApproval { SMAppService.openSystemSettingsLoginItems() } else { model.approveHelper() } }.buttonStyle(.borderedProminent).controlSize(.large)
                } else {
                    HStack(spacing:20) {
                        Text(model.gateway.running ? "Mac’i açık tutun ve dizüstünün kapağını kapatmayın." : "Yalnızca girdiğiniz konsolun trafiği yönlendirilir.").font(.callout).foregroundStyle(.secondary).fixedSize(horizontal:false,vertical:true)
                        Spacer(minLength:0)
                        Button(model.gateway.running ? "Paylaşımı durdur" : "Paylaşımı başlat") { if model.gateway.running { model.stopGateway() } else { model.startGateway() } }.buttonStyle(.borderedProminent).controlSize(.large).disabled(model.busy || (!model.gateway.running && !model.canStartPS5))
                    }
                }
                if model.busy { HStack { ProgressView().controlSize(.small);Text(model.gateway.running ? "Durduruluyor…" : "Bağlanıyor…").font(.caption).foregroundStyle(.secondary) } }
            }
        }
        if model.validClient {
            VStack(alignment:.leading,spacing:12) {
                HStack { Text("PS5 ağ ayarları").font(.headline);Spacer();Button { model.copySetup() } label: { Label("Kopyala",systemImage:"doc.on.doc") } }
                Surface { VStack(spacing:13) {
                    InfoRow(label:"IP adresi",value:model.clientIP);Divider()
                    InfoRow(label:"Alt ağ maskesi",value:model.network?.mask ?? "—");Divider()
                    InfoRow(label:"Ağ geçidi",value:model.network?.address ?? "—",accent:true);Divider()
                    InfoRow(label:"Birincil DNS",value:"1.1.1.1");Divider()
                    InfoRow(label:"İkincil DNS",value:"1.0.0.1");Divider()
                    InfoRow(label:"MTU",value:"Otomatik");Divider()
                    InfoRow(label:"Proxy sunucusu",value:"Kullanma")
                } }
                Text("Bu değerleri PS5’te ayrı bir LAN profiline kaydedin. Normal bağlantıya dönmek için önceki otomatik profilinizi seçin. Adreslerin değişmemesi için router’da DHCP rezervasyonu kullanabilirsiniz.").font(.caption).foregroundStyle(.secondary).fixedSize(horizontal:false,vertical:true)
            }
        }
    }
}
struct Diagnostics:View {
    @EnvironmentObject var model:AppModel
    var body:some View {
        PageHeading(title:"Bağlantı kontrolü",detail:"Yerel ağ ve Discord sunucularına erişimi kontrol edin.")
        HStack { Button(model.testing ? "Kontrol ediliyor…" : "Kontrolleri çalıştır") { model.checkConnection() }.buttonStyle(.borderedProminent).controlSize(.large).disabled(model.testing);Spacer();Button("Raporu kaydet") { model.exportDiagnostics() }.disabled(model.testing) }
        Surface {
            if model.checks.isEmpty { VStack(spacing:12) { Image(systemName:"stethoscope").font(.system(size:35,weight:.light)).foregroundStyle(.secondary);Text("Henüz kontrol yapılmadı").font(.headline);Text("Bağlantıyı açın ve kontrolleri çalıştırın.").font(.callout).foregroundStyle(.secondary) }.frame(maxWidth:.infinity).padding(.vertical,48) }
            else { VStack(spacing:0) { ForEach(Array(model.checks.enumerated()),id:\.element.id) { index,item in
                HStack(spacing:14) { if item.state == .checking { ProgressView().controlSize(.small).frame(width:20) } else { Image(systemName:item.state == .good ? "checkmark.circle.fill" : (item.state == .failed ? "exclamationmark.circle.fill" : "circle")).foregroundStyle(item.state == .good ? Color.green : (item.state == .failed ? Color.orange : Color.secondary)).frame(width:20) };VStack(alignment:.leading,spacing:5) { Text(item.title).font(.system(size:13,weight:.medium));Text(item.detail).font(.caption).foregroundStyle(.secondary) };Spacer() }.padding(.vertical,16)
                if index < model.checks.count-1 { Divider() }
            } } }
        }
        Text("Rapor; IP adresi, kullanıcı adı, Discord oturum bilgisi veya mesaj içeriği içermez. Bu kontrol, konsolda ses ve oyun bağlantısı testinin yerine geçmez.").font(.caption).foregroundStyle(.secondary)
    }
}
struct SettingsPage:View {
    @EnvironmentObject var model:AppModel
    var body:some View {
        PageHeading(title:"Ayarlar",detail:"Bağlantı yöntemi ve uygulama seçenekleri.")
        Surface { VStack(alignment:.leading,spacing:18) {
            Text("Bağlantı yöntemi").font(.headline)
            Picker("Yöntem",selection:$model.preset) { ForEach(ConnectionPreset.allCases,id:\.self) { Text($0.title).tag($0) } }.pickerStyle(.segmented).labelsHidden().disabled(model.engineRunning || model.busy)
            Text(model.preset.detail).font(.callout).foregroundStyle(.secondary)
            if model.engineRunning { Text("Yöntemi değiştirmek için bağlantıyı durdurun.").font(.caption).foregroundStyle(.secondary) }
        } }
        Surface { VStack(spacing:20) {
            VStack(alignment:.leading,spacing:6) {
                Toggle("Discord bağlantısını otomatik koru",isOn:$model.maintainDiscord).toggleStyle(.switch)
                Text("Luma bağlantısı açıkken Discord’un kendi güncellemeleri normal çalışır. Güncelleme veya açılış sonrası bağlantı ayarları kaybolursa Discord otomatik yeniden açılır.").font(.caption).foregroundStyle(.secondary)
            }
            Divider()
            Toggle("Mac açıldığında Luma’yı aç",isOn:Binding(get:{model.autoStart},set:{model.setAutoStart($0)})).toggleStyle(.switch)
            Divider()
            HStack { VStack(alignment:.leading,spacing:5) { Text("Bağlantı motoru");Text("Mac ve PS5 için ortak bağlantı.").font(.caption).foregroundStyle(.secondary) };Spacer();Button(model.engineRunning ? "Durdur" : "Başlat") { if model.engineRunning { model.stopEngine() } else { model.startEngine() } }.disabled(model.busy) }
            if model.helperApproved || model.helperNeedsApproval { Divider();HStack { VStack(alignment:.leading,spacing:5) { Text("Paylaşım yardımcısı");Text("Uygulamayı kaldırmadan önce kaydını kaldırın.").font(.caption).foregroundStyle(.secondary) };Spacer();Button("Kaydı kaldır") { model.removeHelper() }.disabled(model.gateway.running || model.busy) } }
        }.font(.callout) }
        Text("PS5 paylaşımı otomatik başlamaz. Sistem genelindeki proxy ayarları değiştirilmez.").font(.caption).foregroundStyle(.secondary)
    }
}
struct AboutPage:View {
    var body:some View {
        VStack(spacing:16) {
            Image(nsImage:NSApplication.shared.applicationIconImage).resizable().frame(width:88,height:88)
            Text("Luma").font(.system(size:26,weight:.semibold))
            Text("Sürüm \(Product.version)").font(.callout).foregroundStyle(.secondary)
            Text("Onur Ozan Sünger tarafından geliştirildi.").font(.callout).foregroundStyle(.secondary)
            Text("Discord ve PlayStation 5 bağlantı yöneticisi.").font(.callout).foregroundStyle(.secondary)
        }.frame(maxWidth:.infinity).padding(.vertical,24)
        Surface { VStack(alignment:.leading,spacing:16) {
            Text("Lisanslar").font(.headline)
            Text("ByeDPI ve tun2socks bileşenleri ile bunların bağımlılıklarına ait lisans bildirimleri uygulama paketinde bulunur.").font(.callout).foregroundStyle(.secondary)
            Button("Lisans bildirimlerini göster") { if let url = Bundle.main.resourceURL?.appendingPathComponent("Licenses") { NSWorkspace.shared.open(url) } }
        } }
        Text("Luma bir VPN veya anonimlik hizmeti değildir. Discord veya Sony ile bağlantılı resmî bir ürün değildir.").font(.caption).foregroundStyle(.secondary)
    }
}
