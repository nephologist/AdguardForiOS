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

class DnsLogRecordsWriter: NSObject, DnsLogRecordsWriterProtocol {
    
    var server = ""
    
    private let dnsLogService: DnsLogRecordsServiceProtocol
    private var records = [DnsLogRecord]()
    
    private let saveRecordsMinimumTime = 3.0 // seconds
    private var nextSaveTime: Double
    
    private let recordsQueue = DispatchQueue(label: "DnsLogRecordsWriter recods queue")
    
    @objc init(dnsLogService: DnsLogRecordsServiceProtocol) {
        self.dnsLogService = dnsLogService
        
        nextSaveTime = Date().timeIntervalSince1970 + saveRecordsMinimumTime
    }
    
    deinit {
        flush()
    }
    
    func handleEvent(_ event: AGDnsRequestProcessedEvent) {
        if event.error != nil && event.error != "" {
            DDLogError("(DnsLogRecordsWriter) handle event error occured - \(event.error!)")
            return
        }
        
        let blacklisted = event.filterListIds.contains(1)
        let whitelisted = event.whitelist
        
        let status:DnsLogRecordStatus = whitelisted ? .whitelisted : (blacklisted ? .blacklisted : .processed)

        let record = DnsLogRecord(domain: event.domain, date: Date(timeIntervalSince1970: TimeInterval(event.startTime / 1000)), elapsed: Int(event.elapsed), type: event.type, answer: event.answer, server: server, upstreamAddr: event.upstreamAddr, bytesSent: Int(event.bytesSent), bytesReceived: Int(event.bytesReceived), status: status, userStatus: .none, blockRules: event.rules)
        addRecord(record: record, flush: false)
    }
    
    private func addRecord(record: DnsLogRecord, flush: Bool) {
        
        recordsQueue.async { [weak self] in
            guard let sSelf = self else { return }
            
            sSelf.records.append(record)
            
            let now = Date().timeIntervalSince1970
            if now < sSelf.nextSaveTime && !flush {
                return
            }
            
            sSelf.save()
            sSelf.nextSaveTime = now + sSelf.saveRecordsMinimumTime
        }
    }
    
    private func flush() {
        recordsQueue.async { [weak self] in
            self?.save()
        }
    }
    
    private func save() {
        dnsLogService.writeRecords(records)
        records.removeAll()
    }
}
