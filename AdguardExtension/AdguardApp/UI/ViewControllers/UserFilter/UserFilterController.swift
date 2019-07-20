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

class UserFilterController : UIViewController, UIViewControllerTransitioningDelegate {
    
    var whitelist = false
    @objc var newRuleText: String?
    
    let resources: AESharedResourcesProtocol = ServiceLocator.shared.getService()!
    let aeService: AEServiceProtocol = ServiceLocator.shared.getService()!
    var theme: ThemeServiceProtocol = { ServiceLocator.shared.getService()! }()
    
    let fileShare: FileShareServiceProtocol = FileShareService()
    lazy var inverted: Bool = { self.resources.sharedDefaults().bool(forKey: AEDefaultsInvertedWhitelist) }()
    
    var tableController : UserFilterTableController?
    
    lazy var model: UserFilterViewModel = {
        let type: UserFilterType = self.whitelist ? (inverted ? .invertedWhitelist : .whitelist) : .blacklist
        let contentBlockerService: ContentBlockerService = ServiceLocator.shared.getService()!
        return UserFilterViewModel(type, resources: self.resources, contentBlockerService: contentBlockerService, antibanner: aeService.antibanner(), theme: theme)}()
    
    // MARK: IB outlets
    
    @IBOutlet weak var rightButtonView: UIView!
    @IBOutlet weak var leftButtonStack: UIStackView!

    @IBOutlet var selectButton: UIButton!
    @IBOutlet var editButton: RoundRectButton!
    @IBOutlet var exportButton: UIButton!
    @IBOutlet var importButton: UIButton!
    @IBOutlet var deleteButton: RoundRectButton!
    @IBOutlet var selectAllButton: UIButton!
    @IBOutlet var cancelButton: UIButton!
    @IBOutlet var saveButton: RoundRectButton!
    @IBOutlet weak var bottomBar: UIView!
    @IBOutlet var bottomBarButtons: [RoundRectButton]!
    @IBOutlet weak var bottomBarSeparator: UIView!
    
    @IBOutlet weak var textView: UITextView!
    
    @IBOutlet weak var rigthButtonViewWidthConstraint: NSLayoutConstraint!
    
    private let buttonSpacing: CGFloat = 8.0
    
    enum BootomBarState {
        case normal
        case select
        case edit
    }
    
    private var barState: BootomBarState = .normal
    
    // MARK: - Viecontroller lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        NotificationCenter.default.addObserver(forName: NSNotification.Name( ConfigurationService.themeChangeNotification), object: nil, queue: OperationQueue.main) {[weak self] (notification) in
            self?.updateTheme()
        }
        
        if newRuleText != nil && newRuleText!.count > 0 {
            tableController?.addRule(rule: newRuleText!)
            showRuleAddedDialog()
        }
        
        if whitelist {
            let inverted = resources.sharedDefaults().bool(forKey: AEDefaultsInvertedWhitelist)
            self.navigationItem.title = ACLocalizedString(inverted ? "inverted_whitelist_title" : "whitelist_title", "")
        }
        else {
            self.navigationItem.title = ACLocalizedString("user_filter_title", "")
        }
        
        editMode(false)
        
        updateTheme()
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "userFilterTableSegue" {
            let controller = segue.destination as! UserFilterTableController
            controller.model = model
            tableController = controller
            
            importButton.setTitle(ACLocalizedString(whitelist ? "import_whitelist_title" : "import_blacklist_title", ""), for: .normal)
            exportButton.setTitle(ACLocalizedString(whitelist ? "export_whitelist_title" : "export_blacklist_title", ""), for: .normal)
            updateBottomBar()
        }
    }
    
    // MARK: - pubilc methods
    
    func selectedRulesChanged() {
        updateButtonStates()
    }
    
    // MARK: - Actions
    
    @IBAction func selectAction(_ sender: Any) {
        tableController?.setCustomEditing(true)
        barState = .select
        updateBottomBar()
    }
    
    @IBAction func editAction(_ sender: Any) {
        textView.text = model.rules.map { $0.rule }.joined(separator: "\n")
        editMode(true)
        barState = .edit
        updateBottomBar()
    }
    
    @IBAction func exportAction(_ sender: UIView) {
        fileShare.exportFile(parentController: self, sourceView: sender, sourceRect: sender.bounds, filename: whitelist ? ( inverted ? "adguard_inverted_whitelist.txt" : "adguard_whitelist.txt") : "adguard_user_filter.txt", text: model.plainText()) { (message) in
            
        }
    }
    
    @IBAction func importAction(_ sender: Any) {
        fileShare.importFile(parentController: self) { [weak self] (text, errorMessage) in
            guard let strongSelf = self else { return }
            if errorMessage != nil {
                ACSSystemUtils.showSimpleAlert(for: strongSelf, withTitle: nil, message: errorMessage)
            }
            else {
                self?.model.importRules(text) { errorMessage in
                    ACSSystemUtils.showSimpleAlert(for: strongSelf, withTitle: nil, message: errorMessage)
                }
            }
        }
    }
    
    @IBAction func cancelSelectionAction(_ sender: Any) {
        cancelAction()
    }
    
    @IBAction func deleteAction(_ sender: Any) {
        model.deleteSelected(completionHandler: { [weak self] in
            DispatchQueue.main.async {
                self?.selectedRulesChanged()
            }
        }) { (message) in
    
        }
        cancelAction()
    }
    
    @IBAction func selectAllAction(_ sender: Any) {
        model.selectAllRules(true)
        tableController?.tableView.reloadData()
        selectedRulesChanged()
    }
    
    @IBAction func saveAction(_ sender: Any) {
        model.importRules(textView.text) { (error) in
            ACSSystemUtils.showSimpleAlert(for: self, withTitle: nil, message: error)
        }
        editMode(false)
        barState = .normal
        updateBottomBar()
    }
    
    // MARK: - Presentation delegate methods
    
    func animationController(forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return CustomAnimatedTransitioning()
    }
    
    
    // MARK: - private methods
    private func cancelAction(){
        tableController?.setCustomEditing(false)
        barState = .normal
        model.selectAllRules(false)
        updateBottomBar()
        selectedRulesChanged()
        editMode(false)
    }
    
    private func updateBottomBar() {
        for subview in rightButtonView.subviews {
            subview.removeFromSuperview()
        }
        
        leftButtonStack.arrangedSubviews.forEach { (view) in
            leftButtonStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
        
        var rightButton = cancelButton!
        switch barState {
        case .normal:
            rightButton = editButton
            
            leftButtonStack.addArrangedSubview(exportButton)
            leftButtonStack.addArrangedSubview(importButton)
            
        case .select:
            
            leftButtonStack.addArrangedSubview(deleteButton)
            leftButtonStack.addArrangedSubview(selectAllButton)
            
        case .edit:
            rightButton = cancelButton
            leftButtonStack.addArrangedSubview(saveButton)
        }
        
        rightButtonView.addSubview(rightButton)
        
        rightButton.sizeToFit()
        rigthButtonViewWidthConstraint.constant = rightButton.frame.size.width
        bottomBar.layoutSubviews()
        rightButton.frame = rightButtonView.bounds
        
        selectedRulesChanged()
    }
    
    private func updateTheme() {
        bottomBar.backgroundColor = theme.bottomBarBackgroundColor
        theme.setupPopupButtons(bottomBarButtons)
        bottomBarSeparator.backgroundColor = theme.separatorColor
        deleteButton.customHighlightedBackgroundColor = theme.selectedCellColor
        theme.setupTextView(textView)
        textView.backgroundColor = theme.backgroundColor
    }
    
    private func updateButtonStates() {
        deleteButton.isEnabled = model.rules.contains { $0.selected }
        selectAllButton.isEnabled = model.rules.contains { !$0.selected }
    }
    
    private func showRuleAddedDialog() {
        guard let controller = storyboard?.instantiateViewController(withIdentifier: "RuleAddedController") as? RuleAddedController else { return }
        controller.modalPresentationStyle = .custom
        controller.transitioningDelegate = self
        
        present(controller, animated: true, completion: nil)
    }
    
    private func editMode(_ edit: Bool) {
        textView.isHidden = !edit
        if edit {
            navigationItem.rightBarButtonItems = []
        }
        else {
            tableController?.updateNavBarButtons()
        }
    }
}
