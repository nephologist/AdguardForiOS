/**
       This file is part of Adguard for iOS (https://github.com/AdguardTeam/AdguardForiOS).
       Copyright © Adguard Software Limited. All rights reserved.
 
       Adguard for iOS is free software: you can redistribute it and/or modify
       it under the terms of the GNU General Public License as published by
       the Free Software Foundation, either version 3 of the License, or
       (at your option) any later version.
 
       Adguard for iOS is distributed in the hope that it will be useful,
       but WITHOUT ANY WARRANTY; without even the implied warranty of
       MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
       GNU General Public License for more details.
 
       You should have received a copy of the GNU General Public License
       along with Adguard for iOS.  If not, see <http://www.gnu.org/licenses/>.
 */

import Foundation

@objc
protocol DnsProxyServiceProtocol : NSObjectProtocol {
    
    func start(upstreams: [String], listenAddr: String, bootstrapDns: String, fallback: String, serverName: String, filtersJson: String, maxQueues: Int) -> Bool
    func stop(callback:@escaping ()->Void)
    func resolve(dnsRequest:Data, callback:  @escaping (_ dnsResponse: Data?)->Void);
}

class DnsProxyService : NSObject, DnsProxyServiceProtocol {
    
    // set it to 2000 to make sure we will quickly fallback if needed
    private let timeout = 2000
    private let dnsRecordsWriter: DnsLogRecordsWriterProtocol;
    
    private let workingQueue = DispatchQueue(label: "dns proxy service working queue")
    private let resolveQueue = DispatchQueue(label: "dns proxy resolve queue", attributes: [.concurrent])
    
    let events: AGDnsProxyEvents
    
    @objc
    init(logWriter: DnsLogRecordsWriterProtocol) {
        DDLogInfo("(DnsProxyService) initializing")
        dnsRecordsWriter = logWriter
        events = AGDnsProxyEvents()
        
        super.init()
        
        events.onRequestProcessed = { [weak self] (event) in
            if event != nil {
                self?.dnsRecordsWriter.handleEvent(event!)
            }
        }
    }
    
    var agproxy: AGDnsProxy?
    
    @objc func start(upstreams: [String], listenAddr: String, bootstrapDns: String, fallback: String, serverName: String, filtersJson: String, maxQueues: Int) -> Bool {
        
        let bootstrapDnsArray = bootstrapDns.components(separatedBy: .whitespacesAndNewlines)
        
        let agUpstreams = upstreams.map { (upstream) -> AGDnsUpstream in
            return AGDnsUpstream(address: upstream, bootstrap: bootstrapDnsArray, timeout: 2000, serverIp: nil)
        }
        
        guard let filterFiles = try? JSONSerialization.jsonObject(with: filtersJson.data(using: .utf8)! , options: []) as? Array<[String:Any]> else {
            return false
        }
        
        var filters = [NSNumber:String]()
        
        for filter in filterFiles! {
            
            let identifier = filter["id"] as! Int
            let path = filter["path"] as! String
            
            let numId = identifier as NSNumber
            
            filters[numId] = path
        }
        let upstream = AGDnsUpstream(address: fallback, bootstrap: bootstrapDnsArray, timeout: 10000, serverIp: nil)

        let dns64Settings = AGDns64Settings(upstream: upstream, maxTries: 2, waitTime: 10000)
        let config = AGDnsProxyConfig(upstreams: agUpstreams, filters: filters, blockedResponseTtl: 0, dns64Settings: dns64Settings)
        agproxy = AGDnsProxy(config: config, handler: events)
        
        return true
    }
    
    @objc func stop(callback:@escaping ()->Void) {
        DDLogInfo("(DnsProxyService) - stop")
        
        workingQueue.async { [weak self] in
            self?.agproxy = nil
            callback()
        }
        
        return
    }
    
    @objc func resolve(dnsRequest: Data, callback: @escaping (Data?) -> Void) {
        
        resolveQueue.async { [weak self] in
            let reply = self?.agproxy?.handlePacket(dnsRequest)
            callback(reply)
        }
    }
}
