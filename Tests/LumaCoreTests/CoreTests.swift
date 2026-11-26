import Testing
import Foundation
@testable import LumaCore

final class AddressValidationTests {
    let network = NetworkSnapshot(interface:"en0",address:"10.42.0.10",mask:"255.255.255.0",router:"10.42.0.1")
    @Test func testValidClientOnSameNetwork() throws { try network.validateClient("10.42.0.20") }
    @Test func testRejectOwnRouterAndSubnetAddresses() {
        for ip in ["10.42.0.10","10.42.0.1","10.42.0.0","10.42.0.255"] { expectThrows(try network.validateClient(ip),ip) }
    }
    @Test func testRejectInjectionAndAmbiguousAddress() {
        for ip in ["10.42.0.20;id","10.42.0.20\npass all","$(whoami)","10.42.00.26"," 10.42.0.20","10.42.0.256","1.2.3",""] { expectNil(IPv4(ip),ip) }
    }
    @Test func testRejectOutsideLANAndPublicAddress() { for ip in ["10.42.1.26","8.8.8.8","127.0.0.1","0.0.0.0","224.0.0.1"] { expectThrows(try network.validateClient(ip)) } }
    @Test func testRFC1918Boundaries() {
        for ip in ["10.0.0.1","10.255.255.254","172.16.0.1","172.31.255.254","192.168.0.1"] { expectTrue(IPv4(ip)!.isPrivate) }
        for ip in ["11.0.0.1","172.15.0.1","172.32.0.1","192.169.0.1"] { expectFalse(IPv4(ip)!.isPrivate) }
    }
    @Test func testMaskMustBeContiguous() { expectFalse(IPv4.validMask(IPv4("255.0.255.0")!));expectTrue(IPv4.validMask(IPv4("255.255.252.0")!)) }
    @Test func testNon24Network() throws {
        let n = NetworkSnapshot(interface:"en4",address:"10.4.8.4",mask:"255.255.252.0",router:"10.4.8.1")
        expectEqual(n.cidr,"10.4.8.0/22");try n.validateClient("10.4.11.25");expectThrows(try n.validateClient("10.4.12.25"))
    }
    @Test func testRejectInterfaceInjection() { let n = NetworkSnapshot(interface:"en0\npass all",address:network.address,mask:network.mask,router:network.router);expectThrows(try n.validateClient("10.42.0.20")) }
    @Test func testIPv4RoundTrip() { for value:UInt32 in [0,1,0x0a2a0014,UInt32.max] { expectEqual(IPv4(IPv4(value:value).description)?.value,value) } }
}
final class RuleScopeTests {
    @Test func testRulesOnlySelectConsoleAndPreserveLAN() throws {
        let n = NetworkSnapshot(interface:"en0",address:"10.42.0.10",mask:"255.255.255.0",router:"10.42.0.1")
        let rules = try PFPlan.rules(client:"10.42.0.20",network:n,tunnel:"utun180",tunnelIP:"198.18.0.1")
        expectTrue(rules.contains("from 10.42.0.20 to ! 10.42.0.0/24"));expectFalse(rules.contains("from any"));expectFalse(rules.contains("flush"));expectTrue(rules.contains("proto { tcp udp }"))
    }
    @Test func testRejectTunnelInjection() {
        let n = NetworkSnapshot(interface:"en0",address:"10.42.0.10",mask:"255.255.255.0",router:"10.42.0.1")
        expectThrows(try PFPlan.rules(client:"10.42.0.20",network:n,tunnel:"utun1)\npass all",tunnelIP:"198.18.0.1"))
    }
    @Test func testStatusRoundTrip() throws { let s = GatewayStatus(running:true,client:"10.0.0.4",message:"Hazır",startedAt:Date());let d = try JSONEncoder().encode(s);let result = try JSONDecoder().decode(GatewayStatus.self,from:d);expectTrue(result.running);expectEqual(result.client,s.client) }
}
final class ProxyParserTests {
    @Test func testHTTPSConnect() throws { let t = try ConnectTarget.parse("CONNECT updates.discord.com:443 HTTP/1.1\r\nHost: updates.discord.com\r\n\r\n");expectEqual(t.host,"updates.discord.com");expectEqual(t.port,443) }
    @Test func testRejectNonCONNECT() { expectThrows(try ConnectTarget.parse("GET https://discord.com/ HTTP/1.1\r\n\r\n")) }
    @Test func testRejectUnexpectedPort() { for port in ["22","0","65536","80",""] { expectThrows(try ConnectTarget.parse("CONNECT discord.com:\(port) HTTP/1.1\r\n\r\n")) } }
    @Test func testRejectCredentialsAndInvalidHost() { for host in ["user:pass@discord.com","discord.com/path","evil;command","discord.com\0",""] { expectThrows(try ConnectTarget.parse("CONNECT \(host):443 HTTP/1.1\r\n\r\n")) } }
    @Test func testRejectMalformedHostLabels() {
        for host in ["discord..com","-discord.com","discord-.com",String(repeating:"a",count:64)+".com"] { expectThrows(try ConnectTarget.parse("CONNECT \(host):443 HTTP/1.1\r\n\r\n")) }
    }
    @Test func testRejectIncompleteAndOversizedHeaders() {
        expectThrows(try ConnectTarget.parse("CONNECT discord.com:443 HTTP/1.1"))
        expectThrows(try ConnectTarget.parse("CONNECT discord.com:443 HTTP/1.1\r\nX: " + String(repeating:"a",count:16_384) + "\r\n\r\n"))
    }
    @Test func testNoArbitraryPresetArguments() { for p in ConnectionPreset.allCases { expectFalse(p.arguments.contains("--ip"));expectFalse(p.arguments.contains("-i"));expectFalse(p.arguments.contains("--daemon")) } }
}
final class ProcessTests {
    @Test func testChildSharesSupervisorGroupAndTerminates() throws {
        let child = try ManagedChild(executable:"/bin/sleep",arguments:["10"])
        expectTrue(child.isRunning)
        expectEqual(getpgid(child.processIdentifier),getpgrp())
        child.stop()
        expectFalse(child.isRunning)
        child.stop() // Stopping twice must not signal a recycled process ID.
    }
    @Test func testExecutablePathIsAbsoluteAndExists() {
        let url = Executable.currentURL()
        expectTrue(url.path.hasPrefix("/"))
        expectTrue(FileManager.default.isExecutableFile(atPath:url.path))
    }
    @Test func testArgumentsAreNotShellExpanded() throws { let r = try Command.run("/usr/bin/printf",["%s","$(id); untouched"]);expectEqual(r.text,"$(id); untouched") }
    @Test func testTimeoutStopsProcess() throws { let start = Date();let r = try Command.run("/bin/sleep",["10"],timeout:0.1);expectNotEqual(r.status,0);expectLess(Date().timeIntervalSince(start),2) }
}

private func expectTrue(_ value:Bool,_ message:String = "") { #expect(value, Comment(rawValue:message)) }
private func expectFalse(_ value:Bool,_ message:String = "") { #expect(!value, Comment(rawValue:message)) }
private func expectNil<T>(_ value:T?,_ message:String = "") { #expect(value == nil, Comment(rawValue:message)) }
private func expectEqual<T:Equatable>(_ a:T,_ b:T) { #expect(a == b) }
private func expectNotEqual<T:Equatable>(_ a:T,_ b:T) { #expect(a != b) }
private func expectLess<T:Comparable>(_ a:T,_ b:T) { #expect(a < b) }
private func expectThrows<T>(_ expression:@autoclosure () throws -> T,_ message:String = "") { #expect(throws:(any Error).self, Comment(rawValue:message)) { _ = try expression() } }
