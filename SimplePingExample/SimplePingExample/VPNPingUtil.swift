//
//  VPNPingUtil.swift
//  Nice
//
//  Created by yangjian on 2022/11/4.
//

import Foundation

class VPNPingUtil: NSObject {
    enum PingStatus {
        case start
        case failToSendPacket
        case receivePacket
        case receiveUnpectedPacket
        case timeout
        case error
        case finished
    }

    struct PingItem {
        /// host name
        var hostName: String?
        /// ping status
        var status: PingStatus?
        /// millisecond
        var singleTime: Double?

    }
        
    var hostName: String?
    var pinger: SimplePing?
    var sendTimer: Timer?
    var startDate: Date?
    var runloop: RunLoop?
    var pingCallback: ((_ pingItem: PingItem) -> Void)?
    var count: Int = 0
    
    init(hostName: String, count: Int, pingCallback: @escaping ((_ pingItem: PingItem) -> Void)) {
        super.init()
        self.hostName = hostName
        self.count = count
        self.pingCallback = pingCallback
        let pinger = SimplePing(hostName: hostName)
        self.pinger = pinger
        pinger.addressStyle = .any
        pinger.delegate = self
        pinger.start()
    }
    
    static func startPing(hostName: String, count: Int, pingCallback: @escaping ((_ pingItem: PingItem) -> Void)) -> VPNPingUtil {
        let manager = VPNPingUtil(hostName: hostName, count: count, pingCallback: pingCallback)
        return manager
    }
    
    func stopPing() {
        debugPrint("[IP] ping" + (hostName ?? "nil") + "stop")
        clean(status: .finished)
    }
    
    @objc func pingTimeout() {
        debugPrint("[IP] ping" + (hostName ?? "nil") + "timeout")
        clean(status: .timeout)
    }
    
    func pingFail() {
        debugPrint("[IP] ping" + (hostName ?? "nil") + "fail")
        clean(status: .error)
    }
    
    func clean(status: PingStatus) {
        let item = PingItem(hostName: hostName, status: status)
        pingCallback?(item)
        
        pinger?.stop()
        pinger = nil
        sendTimer?.invalidate()
        sendTimer = nil
        runloop?.cancelPerform(#selector(pingTimeout), target: self, argument: nil)
        runloop = nil
        hostName = nil
        startDate = nil
        pingCallback = nil
    }
    
    @objc func sendPing() {
        if count < 1 {
            stopPing()
            return
        }
        count -= 1
        startDate = Date()
        pinger?.send(with: nil)
        // timeout in two second
        runloop?.perform(#selector(pingTimeout), with: nil, afterDelay: 2.0)
    }
}

extension VPNPingUtil: SimplePingDelegate {
    func simplePing(_ pinger: SimplePing, didStartWithAddress address: Data) {
        debugPrint("[IP] start ping \(hostName ?? "null")")
        sendPing()
        sendTimer = Timer.scheduledTimer(timeInterval: 0.4, target: self, selector: #selector(sendPing), userInfo: nil, repeats: true)
        
        let pingItem = PingItem(hostName: hostName, status: .start)
        pingCallback?(pingItem)
    }
    
    func simplePing(_ pinger: SimplePing, didFailWithError error: Error) {
        debugPrint("[IP] \(hostName ?? "null") \(error.localizedDescription)")
//        pingFail()
    }
    
    func simplePing(_ pinger: SimplePing, didSendPacket packet: Data, sequenceNumber: UInt16) {
        runloop?.cancelPerform(#selector(pingTimeout), target: self, argument: nil)
        debugPrint("[IP] \(hostName ?? "null") #\(sequenceNumber) send packet success")
    }
    
    func simplePing(_ pinger: SimplePing, didFailToSendPacket packet: Data, sequenceNumber: UInt16, error: Error) {
        runloop?.cancelPerform(#selector(pingTimeout), target: self, argument: nil)
        debugPrint("[IP] \(hostName ?? "") send packet failed: \(error.localizedDescription)")
        clean(status: .failToSendPacket)
    }
    
    func simplePing(_ pinger: SimplePing, didReceivePingResponsePacket packet: Data, sequenceNumber: UInt16) {
        runloop?.cancelPerform(#selector(pingTimeout), target: self, argument: nil)
        let time = Date().timeIntervalSince(startDate ?? Date()) * 1000
        debugPrint("[IP] \(hostName ?? "null") #\(sequenceNumber) received, size=\(packet.count), time=\(String(format: "%.2f", time)) ms")
        let pingItem = PingItem(hostName: hostName, status: .receivePacket, singleTime: time)
        pingCallback?(pingItem)
    }
    
    func simplePing(_ pinger: SimplePing, didReceiveUnexpectedPacket packet: Data) {
        runloop?.cancelPerform(#selector(pingTimeout), target: self, argument: nil)
    }
}


