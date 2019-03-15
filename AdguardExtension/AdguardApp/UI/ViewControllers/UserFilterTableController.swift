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

class NewRuleCell: UITableViewCell {
    @IBOutlet weak var addButton: UIButton!
}

class RuleCell: UITableViewCell {
    @IBOutlet weak var ruleLabel: ThemableLabel!
    @IBOutlet var themableLabels: [ThemableLabel]!
}

class UserFilterTableController: UITableViewController, UISearchBarDelegate, UIViewControllerTransitioningDelegate, AddRuleControllerDelegate, ImportRulesControllerDelegate, RuleDetailsControllerDelegate {
    
    lazy var theme: ThemeServiceProtocol = { ServiceLocator.shared.getService()! }()
    
    let resources: AESharedResourcesProtocol = ServiceLocator.shared.getService()!
    let aeService: AEServiceProtocol = ServiceLocator.shared.getService()!
    var model: UserFilterViewModel?
    
    let fileShare = FileShareService()
    
    @IBOutlet weak var searchButton: UIBarButtonItem!
    @IBOutlet weak var cancelButton: UIBarButtonItem!
    @IBOutlet var addButton: UIBarButtonItem!
    
    @IBOutlet var headerView: UIView!
    @IBOutlet var searchView: UIView!
    @IBOutlet weak var searchBar: UISearchBar!
    @IBOutlet var searchButtonView: UIView!
    @IBOutlet weak var headerTextView: UITextView!
    
    var observation: NSKeyValueObservation?
    
    private var isCustomEditing = false
    
    // MARK: - View controller lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad();
        updateUI()
        
        observation = model?.observe(\.rules) {[weak self](_, _) in
            DispatchQueue.main.async {
                self?.tableView.reloadData()
            }
        }
        
        var title: String?
        switch (model!.type) {
        case (.blacklist):
            title = ACLocalizedString("blacklist_title", nil)
            let htmlString = ACLocalizedString("blacklist_text", nil)
            if let headerText = htmlString.attributedStringFromHtml() {
                headerText.alignCenter()
                headerText.addAttribute(.foregroundColor, value: theme.lightGrayTextColor, range: NSRange(location: 0, length: headerText.length))
                headerText.addAttribute(.font, value: UIFont.systemFont(ofSize: 12), range: NSRange(location: 0, length: headerText.length))
                headerTextView.attributedText = headerText
            }
        case(.whitelist):
            title = ACLocalizedString("whitelist_title", nil)
            headerTextView.text = ACLocalizedString("whitelist_text", nil)
            headerTextView.textColor = theme.lightGrayTextColor
            headerTextView.textAlignment = .center
        case (.invertedWhitelist):
            title = ACLocalizedString("inverted_whitelist_title", nil)
            headerTextView.text = ACLocalizedString("inverted_whitelist_text", nil)
            headerTextView.textColor = theme.lightGrayTextColor
            headerTextView.textAlignment = .center
        }
        
        self.navigationItem.title = title
        
        searchButton.customView = searchButtonView
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateTheme()
    }
    
    // MARK: - public methds
    
    func setCustomEditing(_ editing: Bool) {
        
        isCustomEditing = editing
        tableView.allowsMultipleSelection = editing
        
        tableView.reloadData()
    }
    
    func selectAllCells() {
        
        tableView.indexPathsForVisibleRows?.forEach({ (indexPath) in
            tableView.selectRow(at: indexPath, animated: false, scrollPosition: .none)
            tableView.reloadData()
        })
        
        DispatchQueue(label: "update rule cells").async {
            [weak self] in
            
            guard let count = self?.model?.rules.count else { return }
            for row in 0..<count {
                self?.tableView.selectRow(at: IndexPath(row: row, section: 1), animated: false, scrollPosition: .none)
            }
            
            DispatchQueue.main.async {
                self?.tableView.reloadData()
            }
        }
    }
    
    // MARK: - UITableView
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            return 1
        }
        else {
            return model?.rules.count ?? 0
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        if indexPath.section == 0 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "NewRuleCellID") as! NewRuleCell
            updateUI()
            cell.addButton.setTitle(model?.addRuleTitle(), for: .normal)
            theme.setupTableCell(cell)
            return cell
        }
        else {
            let cell = tableView.dequeueReusableCell(withIdentifier: "RuleCellID") as! RuleCell
            let rule = model!.rules[indexPath.row]
            cell.ruleLabel.text = rule.rule
            theme.setupLabels(cell.themableLabels)
            
            let selected = rule.selected
            configureCell(cell, selected: selected)
            
            theme.setupLabel(cell.ruleLabel)
            theme.setupTableCell(cell)
            
            return cell
        }
    }
    
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        if indexPath.section == 0 {
            addRuleButtonAction(self)
        }
        else {
            guard let rule = model?.rules[indexPath.row] else { return }
            if isCustomEditing {
                if let cell = tableView.cellForRow(at: indexPath) as? RuleCell {
                    rule.selected = true
                    configureCell(cell, selected: true)
                }
            }
            else {
                showRuleDetails(rule)
            }
        }
    }
    
    override func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        if indexPath.section == 0 {
            
        }
        else {
            if let cell = tableView.cellForRow(at: indexPath) as? RuleCell {
                model?.rules[indexPath.row].selected = false
                configureCell(cell, selected: false)
            }
        }
    }
    
    // MARK: - searchbar delegate methods
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        model?.searchString = searchText
    }
    
    // MARK: - actions
    
    func deleteAction(sender: UIButton) {
        let index = sender.tag
        
        model?.deleteRule(index: index, errorHandler: { (error) in
            
        }) {
            DispatchQueue.main.async {
                self.tableView.reloadData()
            }
        }
    }
    
    @IBAction func searchAction(_ sender: Any) {
        searchBar.text = ""
        model?.searchString = ""
        updateUI()
    }
    
    @IBAction func cancelSearchAction(_ sender: Any) {
        searchBar.text = ""
        model?.searchString = nil
        updateUI()
    }
    
    @IBAction func addRuleButtonAction(_ sender: Any) {
        searchBar.text = ""
        model?.searchString = nil
        
        updateUI()
        
        guard let controller = storyboard?.instantiateViewController(withIdentifier: "AddRuleController") as? AddRuleController else { return }
        controller.modalPresentationStyle = .custom
        controller.transitioningDelegate = self
        controller.delegate = self
        controller.blacklist = model!.type == .blacklist
        
        present(controller, animated: true, completion: nil)
    }
    
    // MARK: - Presentation delegate methods
    
    func animationController(forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return CustomAnimatedTransitioning()
    }
    
    // MARK: - AddRuleController delegate
    
    func addRule(rule: String) {
        
        model?.addRule(ruleText: rule, errorHandler: { [weak self] (error) in
                        ACSSystemUtils.showSimpleAlert(for: self, withTitle: nil, message: error.description)
                        self?.tableView.reloadData()
            },
                      completionHandler: { [weak self] in
                        self?.tableView.reloadData()
        })
        
        tableView.reloadData()
        
        updateUI()
    }
    
    func importRules() {
        (parent as! UserFilterController).importAction(self)
    }
    
    // MARK: - ImportRulesControllerDelegate
    
    func loadRules(url: String, completion: @escaping (Bool) -> Void) {
        
        let parser = AASFilterSubscriptionParser()
        parser.parse(from: URL(string: url)) { [weak self]  (result, error) in
            
            guard let strongSelf = self else {return}
            if let parserError = error {
                ACSSystemUtils.showSimpleAlert(for: self, withTitle: nil, message: parserError.localizedDescription)
                return
            }
            
            if let rules = result?.rules as? [ASDFilterRule] {
                let ruleTexts = rules.map({$0.ruleText!})
                self?.model?.addRules(ruleTexts: ruleTexts, errorHandler: { (error) in
                    
                    }, completionHandler: {
                    DispatchQueue.main.async {
                        strongSelf.updateUI()
                        strongSelf.tableView.reloadData()
                        completion(true)
                    }
                })
                return
            }
        }
    }
    
    // MARK: - RuleDetailsController delegate methods
    
    func removeRule(rule: RuleInfo) {
        model?.deleteRule(rule, errorHandler: { (message) in
            
        }, completionHandler: {
            
        })
    }
    
    func changeRule(rule: RuleInfo, newText: String) {
        model?.changeRule(rule: rule, newText: newText, errorHandler: { (error) in
            
        }, completionHandler: { [weak self] in
            self?.tableView.reloadData()
        })
    }
    
    // MARK: - private methods
    func updateUI() {
        
        if model?.searchString != nil {
            // add searchbar if needed
            if tableView.tableHeaderView != searchView {
                tableView.tableHeaderView = searchView
                tableView.layoutIfNeeded()
            }
            
            parent?.navigationItem.rightBarButtonItems = [cancelButton]
        }
        else {
            // hide searchbar if needed
            if tableView.tableHeaderView != headerView {
                tableView.tableHeaderView = headerView
            }
            
            parent?.navigationItem.rightBarButtonItems = [addButton, searchButton]
        }
    }
    
    private func updateTheme() {
        view.backgroundColor = theme.backgroundColor
        theme.setupNavigationBar(navigationController?.navigationBar)
        theme.setupSearchBar(searchBar)
        theme.setupTable(tableView)
    }
    
    func configureCell(_ cell: RuleCell, selected: Bool) {
        
        if isCustomEditing {
            if cell.accessoryView == nil {
                let image = UIImageView(frame: CGRect(x: 0, y: 0, width: 22, height: 22))
                image.image = UIImage.init(named: "round-check")
                image.highlightedImage = UIImage.init(named: "round-check-checked")
                cell.accessoryView = image
            }
            cell.selectionStyle = .none
            
            (cell.accessoryView as? UIImageView)?.isHighlighted = selected
        }
        else {
            cell.accessoryView = nil
            cell.selectionStyle = .gray
        }
    }
    
    func showRuleDetails(_ rule: RuleInfo) {
        guard let controller = storyboard?.instantiateViewController(withIdentifier: "RuleDetailsController") as? RuleDetailsController else { return }
        controller.modalPresentationStyle = .custom
        controller.transitioningDelegate = self
        
        controller.delegate = self
        controller.rule = rule
        controller.blacklist = model?.type == .blacklist
        
        present(controller, animated: true, completion: nil)
    }
}



