import Testing
@testable import LumaCore

struct DiscordLaunchTests {
    func buffer(arguments: [String], environment: [String]) -> [UInt8] {
        let count = UInt32(arguments.count)
        var bytes = (0..<4).map { UInt8(truncatingIfNeeded:count >> ($0 * 8)) }
        bytes += Array("/Applications/Discord.app/Contents/MacOS/Discord".utf8) + [0,0,0]
        for value in arguments + environment { bytes += Array(value.utf8) + [0] }
        return bytes + [0]
    }
    let args = ["Discord","--proxy-server=socks5://127.0.0.1:17881"]
    let env = ["HTTPS_PROXY","HTTP_PROXY","https_proxy","http_proxy"].map { "\($0)=http://127.0.0.1:17882" }
    @Test func configuredLaunchIsPreserved() { #expect(DiscordLaunchConfiguration.parse(buffer(arguments:args,environment:env)) == true) }
    @Test func updateRelaunchNeedsRepair() { #expect(DiscordLaunchConfiguration.parse(buffer(arguments:["Discord"],environment:[])) == false) }
    @Test func updaterEnvironmentMustAlsoSurvive() { #expect(DiscordLaunchConfiguration.parse(buffer(arguments:args,environment:[])) == false) }
    @Test func environmentDoesNotMasqueradeAsArgument() { #expect(DiscordLaunchConfiguration.parse(buffer(arguments:["Discord"],environment:env + [args[1]])) == false) }
    @Test func unreadableDataDoesNotAuthorizeRestart() {
        #expect(DiscordLaunchConfiguration.parse([]) == nil)
        #expect(DiscordLaunchConfiguration.parse([2,0,0,0,65]) == nil)
    }
}
