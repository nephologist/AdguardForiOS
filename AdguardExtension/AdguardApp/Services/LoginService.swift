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

/**
 LoginService - this service is responsible for working with adguard logins and licenses
 */
protocol LoginServiceProtocol {
    
    var loggedIn: Bool { get }
    var hasPremiumLicense: Bool { get }
    // not expired
    var active: Bool { get }
    
    func checkStatus( callback: @escaping (Error?)->Void )
    func logout()->Bool
    
    /*  login on backend server and check license information
     the results will be posted through notification center
     
     we can use adguard license in two ways
     1) login throuh oauth in safari and get access_tolken. Then we make auth_token request and get license key. Then bind this key to user device id(app_id) through status request with license key in params
     2) login directly with license key. In this case we immediately send status request with this license key
     */
    func login(accessToken: String, callback: @escaping  (_: Error?)->Void)
    func login(licenseKey: String, callback: @escaping  (_: Error?)->Void)
    
    var activeChanged: (() -> Void)? { get set }
}

class LoginService: LoginServiceProtocol {
    
    var activeChanged: (() -> Void)? {
        didSet {
            setExpirationTimer()
        }
    }
    
    var loginResponseParser: LoginResponseParserProtocol = LoginResponseParser()
    
    // errors
    static let loginErrorDomain = "loginErrorDomain"
    
    static let loginError = -1
    static let loginBadCredentials = -2
    
    // keychain constants
    private let LOGIN_SERVER = "https://mobile-api.adguard.com"
    
    
    // login request
    private let LOGIN_URL = "https://mobile-api.adguard.com/api/2.0/auth"
    private let STATUS_URL = "https://mobile-api.adguard.com/api/1.0/status.html"
    private let AUTH_TOKEN_URL = "https://mobile-api.adguard.com/api/2.0/auth_token"
    private let LOGIN_EMAIL_PARAM = "email"
    private let LOGIN_PASSWORD_PARAM = "password"
    private let LOGIN_APP_NAME_PARAM = "app_name"
    private let LOGIN_APP_ID_PARAM = "app_id"
    private let LOGIN_LICENSE_KEY_PARAM = "license_key"
    private let LOGIN_ACCESS_TOKEN_PARAM = "access_token"
    private let LOGIN_APP_VERSION_PARAM = "app_version"
    private let STATUS_DEVICE_NAME_PARAM = "device_name"
    
    private let LOGIN_APP_NAME_VALUE = "adguard_ios_pro"
    
    private var defaults: UserDefaults
    private var network: ACNNetworkingProtocol
    private var keychain: KeychainServiceProtocol
    
    private var timer: Timer?
    
    var expirationDate: Date? {
        get {
            return defaults.object(forKey: AEDefaultsPremiumExpirationDate) as? Date
        }
        set {
            if newValue == nil {
                defaults.removeObject(forKey: AEDefaultsPremiumExpirationDate)
            }
            else {
                defaults.set(newValue, forKey: AEDefaultsPremiumExpirationDate)
                setExpirationTimer()
            }
        }
    }
    
    var hasPremiumLicense: Bool {
        get {
            return defaults.bool(forKey: AEDefaultsHasPremiumLicense)
        }
        set {
            defaults.set(newValue, forKey: AEDefaultsHasPremiumLicense)
        }
    }
    
    // MARK: - public methods
    
    init(defaults: UserDefaults, network: ACNNetworkingProtocol, keychain: KeychainServiceProtocol) {
        self.defaults = defaults
        self.network = network
        self.keychain = keychain
    }
    
    var loggedIn: Bool {
        get {
            return defaults.bool(forKey: AEDefaultsIsProPurchasedThroughLogin)
        }
        set {
            let oldValue = defaults.bool(forKey: AEDefaultsIsProPurchasedThroughLogin)
            defaults.set(newValue, forKey: AEDefaultsIsProPurchasedThroughLogin)
            
            if newValue != oldValue {
                if let callback = activeChanged {
                    callback()
                }
            }
        }
    }
    
    var active: Bool {
        get {
            if expirationDate == nil {
                return false
            }
            return expirationDate! > Date()
        }
    }
    
    func login(licenseKey: String, callback: @escaping (Error?) -> Void) {
        requestStatus(licenseKey: licenseKey, callback: callback)
    }
    
    func login(accessToken: String, callback: @escaping  (_: Error?)->Void) {
        loginInternal(name: nil, password: nil, accessToken: accessToken, callback: callback)
    }
    
    // todo: name/password are deprecated and must be removed in future versions, when all 3.0.0 user will be migrated to new authorization scheme
    private func loginInternal(name: String?, password: String?, accessToken: String?, callback: @escaping (Error?) -> Void) {
        
        guard let appId = keychain.appId else {
            DDLogError("(LoginService) loginInternal error - can not obtain appId)")
            callback(NSError(domain: LoginService.loginErrorDomain, code: LoginService.loginError, userInfo: [:]))
            return
        }
        
        let loginByToken = accessToken != nil
        
        DDLogInfo("(LoginService) loginInternal. login with " + (loginByToken ? "access_token": "login/password"))
        
        var params = [LOGIN_APP_NAME_PARAM: LOGIN_APP_NAME_VALUE,
                      LOGIN_APP_ID_PARAM: appId]
        
        if !loginByToken {
            params[LOGIN_EMAIL_PARAM] = name
            params[LOGIN_PASSWORD_PARAM] = password
        }
        
        guard let url = URL(string: loginByToken ? AUTH_TOKEN_URL : LOGIN_URL) else  {
            callback(NSError(domain: LoginService.loginErrorDomain, code: LoginService.loginError, userInfo: nil))
            DDLogError("(LoginService) login error. Can not make URL from String \(LOGIN_URL)")
            return
        }
        
        var headers: [String : String] = [:]
        
        if loginByToken {
            headers["Authorization"] = "Bearer \(accessToken!)"
        }
        
        let request: URLRequest = ABECRequest.post(for: url, parameters: params, headers: headers)
        
        network.data(with: request) { [weak self] (dataOrNil, response, error) in
            guard let sSelf = self else { return }
            
            guard error == nil else {
                DDLogError("(LoginService) loginInternal - got error \(error!.localizedDescription)")
                callback(error!)
                return
            }
            
            guard let data = dataOrNil  else{
                DDLogError("(LoginService) loginInternal - got empty response")
                callback(NSError(domain: LoginService.loginErrorDomain, code: LoginService.loginError, userInfo: nil))
                return
            }
            
            let (loggedIn, premium, expirationDate, licenseKey, error) = sSelf.loginResponseParser.processLoginResponse(data: data)
            
            DDLogInfo("(LoginService) loginInternal - processLoginResponse: loggedIn - \(loggedIn ? "true" : "false") premium = \(premium) expirationDate = " + (expirationDate == nil ? "nil" : expirationDate!.description))
            
            if error != nil {
                DDLogError("(LoginService) loginInternal - processLoginResponse error: \(error!.localizedDescription)")
                callback(error!)
                return
            }
            
            sSelf.requestStatus(licenseKey: licenseKey, callback: callback)
        }
    }
    
    func checkStatus(callback: @escaping (Error?) -> Void) {
        requestStatus(licenseKey: nil, callback: callback)
    }
    
    private func requestStatus(licenseKey: String?, callback: @escaping (Error?)->Void ) {
        
        DDLogInfo("(LoginService) requestStatus " + (licenseKey == nil ? "without license key" : "with license key"))
        
        guard let appId = keychain.appId else {
            DDLogError("(LoginService) loginInternal error - can not obtain appId)")
            callback(NSError(domain: LoginService.loginErrorDomain, code: LoginService.loginError, userInfo: [:]))
            return
        }
        
        var params = [LOGIN_APP_NAME_PARAM: LOGIN_APP_NAME_VALUE,
                      LOGIN_APP_ID_PARAM: appId,
                      LOGIN_APP_VERSION_PARAM:ADProductInfo.version()!,
                      STATUS_DEVICE_NAME_PARAM: UIDevice.current.name,
                      "key": "KPQ8695OH49KFCWC9EMX95OH49KFF50S" // legacy backend restriction
                      ]
        if licenseKey != nil {
            params[LOGIN_LICENSE_KEY_PARAM] = licenseKey
        }
        
        guard let url = URL(string: STATUS_URL) else  {
            callback(NSError(domain: LoginService.loginErrorDomain, code: LoginService.loginError, userInfo: nil))
            DDLogError("(PurchaseService) checkStatus error. Can not make URL from String \(STATUS_URL)")
            return
        }
        
        let request: URLRequest = ABECRequest.post(for: url, parameters: params, headers: nil)
        
        network.data(with: request) { [weak self] (dataOrNil, response, error) in
            guard let sSelf = self else { return }
            
            guard error == nil else {
                DDLogError("(LoginService) checkStatus - got error \(error!.localizedDescription)")
                callback(error!)
                return
            }
            
            guard let data = dataOrNil  else {
                DDLogError("(LoginService) checkStatus - got empty response")
                callback(NSError(domain: LoginService.loginErrorDomain, code: LoginService.loginError, userInfo: nil))
                return
            }
            
            let (premium, expirationDate, error) = sSelf.loginResponseParser.processStatusResponse(data: data)
            
            DDLogInfo("(LoginService) checkStatus - processStatusResponse: premium = \(premium) " + (expirationDate == nil ? "" : "expirationDate = \(expirationDate!)"))
            
            
            if error != nil {
                DDLogError("(LoginService) checkStatus - processStatusResponse error: \(error!.localizedDescription)")
                callback(error!)
                return
            }
            
            // todo: remove this in future
            if sSelf.migrateFrom3_0_0IfNeeded(premium: premium, licenseKey: licenseKey, callback: callback) {
                return
            }
            
            sSelf.expirationDate = expirationDate
            sSelf.hasPremiumLicense = premium
            sSelf.loggedIn = premium && sSelf.active
            
            callback(nil)
        }
    }
    
    func logout()->Bool {
        
        loggedIn = false
        expirationDate = nil
        
        // for logged in 3.0.0 users
        _ = keychain.deleteAuth(server: LOGIN_SERVER)
        _ = keychain.deleteLicenseKey(server: LOGIN_SERVER)
        
        return true
    }
    
    // MARK: - private methods
    
    private func setExpirationTimer() {
        
        if timer != nil {
            timer?.invalidate()
            timer = nil
        }
        guard let time = expirationDate else { return }
        if time < Date() { return }
        
        timer = Timer(fire: time, interval: 0, repeats: false) { [weak self] (timer) in
            guard let sSelf = self else { return }
            
            DDLogInfo("(LoginService) expiration timer fired")
                
            if let callback = sSelf.activeChanged {
                callback()
            }
            sSelf.timer = nil
        }
        
        RunLoop.main.add(timer!, forMode: .common)
    }
    
    // todo: remove this in future
    private func migrateFrom3_0_0IfNeeded (premium: Bool, licenseKey:String?, callback: @escaping (Error?)->Void)->Bool {
        
        let oldAuth = keychain.loadAuth(server: LOGIN_SERVER)
        let oldLicenseKey = keychain.loadLicenseKey(server: LOGIN_SERVER)
        
        if !premium && (oldAuth != nil || oldLicenseKey != nil) {
            
            DDLogInfo("(LoginService) - start migration from 3.0.0")
            
            // delete saved in 3.0.0 logins
            _ = keychain.deleteAuth(server: LOGIN_SERVER)
            _ = keychain.deleteLicenseKey(server: LOGIN_SERVER)
            
            if oldLicenseKey != nil {
                
                DDLogInfo("(LoginService) - migrate with license key")
                
                requestStatus(licenseKey: licenseKey) { [weak self] (error) in
                    guard let sSelf = self else { return }
                    if error != nil {
                        // rollback
                        DDLogError("(LoginService) - migration failed with error: \(error!.localizedDescription)")
                        _ = sSelf.keychain.saveLicenseKey(server: sSelf.LOGIN_SERVER, key: oldLicenseKey!)
                    }
                    else {
                        DDLogError("(LoginService) - migration succeeded")
                    }
                    
                    callback(error)
                }
            }
            else {
                
                DDLogInfo("(LoginService) - migrate with login/password")
                loginInternal(name: oldAuth?.login, password: oldAuth?.password, accessToken: nil) { [weak self] (error) in
                    guard let sSelf = self else { return }
                    if error != nil {
                        // rollback
                        DDLogError("(LoginService) - migration failed with error: \(error!.localizedDescription)")
                        _ = sSelf.keychain.saveAuth(server: sSelf.LOGIN_SERVER, login: oldAuth!.login, password: oldAuth!.password)
                    } else {
                        DDLogError("(LoginService) - migration succeeded")
                    }
                    
                    callback(error)
                }
            }
            
            return true
        }
        
        return false
    }
}
