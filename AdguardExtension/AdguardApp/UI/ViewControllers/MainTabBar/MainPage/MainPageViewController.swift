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

import UIKit

class MainPageViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    @IBAction func whatsNew(_ sender: UIButton) {
        StoriesManager.showStories(forVC: self, fromGroup: .whatsNew)
    }
    
    @IBAction func dnsProtection(_ sender: UIButton) {
        StoriesManager.showStories(forVC: self, fromGroup: .dnsProtection)
    }
    
    @IBAction func vpnProtection(_ sender: UIButton) {
        StoriesManager.showStories(forVC: self, fromGroup: .vpnProtection)
    }
    
    @IBAction func safariProtection(_ sender: UIButton) {
        StoriesManager.showStories(forVC: self, fromGroup: .safariProtection)
    }
    
    @IBAction func youtubeAds(_ sender: UIButton) {
        StoriesManager.showStories(forVC: self, fromGroup: .youtubeAds)
    }
    
    @IBAction func dnsServers(_ sender: UIButton) {
        StoriesManager.showStories(forVC: self, fromGroup: .dnsServers)
    }
}
