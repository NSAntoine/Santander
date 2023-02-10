//
//  KeyboardSearchView.swift
//  Santander
//
//  Created by Serena on 09/02/2023.
//

import UIKit
import Runestone

fileprivate func makeGenericButton(image: UIImage?) -> UIButton {
    let button = UIButton(type: .system)
    button.translatesAutoresizingMaskIntoConstraints = false
    button.setImage(image, for: .normal)
    button.tintColor = .label
    return button
}

// Not stolen, unlike KeyboardToolsView
class KeyboardSearchView: UIInputView {
    weak var textView: TextView?
    
    let searchQueue = DispatchQueue(label: "com.serena.Santander.KeyboardSearchView.search", qos: .background)
    var searchWorkItem: DispatchWorkItem?
    
    var searchMethod: SearchQuery.MatchMethod = .contains
    var isCaseSensitive: Bool = false
    
    var searchTextField: UISearchTextField!
    
    // for the chevron up/down buttons
    var currentIndex: Int = 0
    var chevronUpButton: UIButton!
    var chevronDownButton: UIButton!
    var currentResults: [SearchResult] = []
    
    init(
        frame: CGRect = CGRect(origin: .zero, size: CGSize(width: UIScreen.main.bounds.width, height: 44)),
        textView: TextView
    ) {
        super.init(frame: frame, inputViewStyle: .default)
        self.textView = textView
        commonInit()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func commonInit() {
        let doneButton = UIButton(type: .system)
        doneButton.translatesAutoresizingMaskIntoConstraints = false
        doneButton.setTitle("Done", for: .normal)
        doneButton.titleLabel?.font = .preferredFont(forTextStyle: .body)
        doneButton.setTitleColor(.white, for: .normal)
        doneButton.addTarget(self, action: #selector(doneDismiss), for: .allEvents)
        
        self.chevronUpButton = makeGenericButton(image: UIImage(systemName: "chevron.up"))
        self.chevronDownButton = makeGenericButton(image: UIImage(systemName: "chevron.down"))
        
        chevronUpButton.tag = 0
        chevronDownButton.tag = 1
        
        chevronUpButton.addTarget(self, action: #selector(chevronButtonClicked(sender:)), for: .touchUpInside)
        chevronDownButton.addTarget(self, action: #selector(chevronButtonClicked(sender:)), for: .touchUpInside)
        
        chevronUpButton.isEnabled = false
        chevronDownButton.isEnabled = false
        
        let filterButton = makeGenericButton(image: UIImage(systemName: "line.horizontal.3.decrease.circle")?.withTintColor(.systemBlue, renderingMode: .alwaysOriginal))
        
        filterButton.menu = makeSearchMethodMenu(button: filterButton)
        filterButton.showsMenuAsPrimaryAction = true
        
        let chevronButtonsStackView = UIStackView(arrangedSubviews: [filterButton, chevronUpButton, chevronDownButton])
        chevronButtonsStackView.setCustomSpacing(10, after: filterButton)
        chevronButtonsStackView.translatesAutoresizingMaskIntoConstraints = false
        
        self.searchTextField = UISearchTextField()
        searchTextField.addTarget(self, action: #selector(searchDidChange(searchTextField:)), for: .editingChanged)
        searchTextField.inputAccessoryView = self
        searchTextField.translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(doneButton)
        addSubview(searchTextField)
        addSubview(chevronButtonsStackView)
        
        NSLayoutConstraint.activate([
            doneButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            doneButton.centerYAnchor.constraint(equalTo: layoutMarginsGuide.centerYAnchor),
            
            chevronButtonsStackView.centerYAnchor.constraint(equalTo: layoutMarginsGuide.centerYAnchor),
            chevronButtonsStackView.trailingAnchor.constraint(equalTo: layoutMarginsGuide.trailingAnchor),
            
            searchTextField.leadingAnchor.constraint(equalTo: doneButton.leadingAnchor, constant: 50),
            searchTextField.trailingAnchor.constraint(equalTo: chevronButtonsStackView.leadingAnchor, constant: -10),
            searchTextField.centerYAnchor.constraint(equalTo: layoutMarginsGuide.centerYAnchor),
        ])
    }
    
    func makeSearchMethodMenu(button: UIButton) -> UIMenu {
        let filterButtonItems = SearchQuery.MatchMethod.allCases.reversed().map { meth in
            return UIAction(title: meth.description, state: searchMethod == meth ? .on : .off) { [unowned self] _ in
                searchMethod = meth
                button.menu = makeSearchMethodMenu(button: button) // reload menu
            }
        }
        
        let caseSensitiveAction = UIAction(title: "Case Sensitive", state: isCaseSensitive ? .on : .off) { [unowned self] action in
            isCaseSensitive.toggle()
            button.menu = makeSearchMethodMenu(button: button) // reload menu
        }
        
        let items: [UIMenuElement] = [UIMenu(options: .displayInline, children: [caseSensitiveAction])]
        + filterButtonItems
        return UIMenu(title: "Search Method", children: items)
    }
    
    // Action of the 'Done' button
    @objc
    func doneDismiss() {
        guard let textView else { return }
        textView.highlightedRanges = []
        textView.inputAccessoryView = KeyboardToolsView(textView: textView)
        textView.resignFirstResponder()
    }
    
    @objc
    func searchDidChange(searchTextField: UISearchTextField) {
        searchWorkItem?.cancel()
        
        guard let textView else {
            return
        }
        
        guard let text = searchTextField.text, !text.isEmpty else {
            textView.highlightedRanges = [] // remove highlighted ranges if there is no text or it's empty
            chevronUpButton.isEnabled = false
            chevronDownButton.isEnabled = false
            return
        }
        
        let newItem = DispatchWorkItem(flags: .assignCurrentContext) { [unowned self] in
            update(withResults: textView.search(for: makeSearchQuery(text: text)))
        }
        
        searchWorkItem = newItem
        searchQueue.asyncAfter(deadline: .now().advanced(by: .milliseconds(3)), execute: newItem)
    }
    
    func update(withResults results: [SearchResult]) {
        currentResults = results
        
        let areResultsNotEmpty = !results.isEmpty
        DispatchQueue.main.async { [unowned self] in
            if areResultsNotEmpty {
                textView?.scrollRangeToVisible(results[0].range)
            }
            
            chevronUpButton.isEnabled = areResultsNotEmpty
            chevronDownButton.isEnabled = areResultsNotEmpty
        }
        
        let highlightedRanges = results.map { result in
            HighlightedRange(range: result.range, color: .systemOrange)
        }
        
        textView?.highlightedRanges = highlightedRanges
    }
    
    func makeSearchQuery(text: String) -> SearchQuery {
        return SearchQuery(text: text, matchMethod: searchMethod, isCaseSensitive: isCaseSensitive)
    }
    
    @objc
    func chevronButtonClicked(sender: UIButton) {
        switch sender.tag {
        case 0: // up button
            currentIndex -= 1
        case 1: // down button
            currentIndex += 1
        default:
            break
        }
        
        
        chevronUpButton.isEnabled = currentIndex != 0
        chevronDownButton.isEnabled = currentIndex != (currentResults.count - 1)
        print(currentIndex, currentResults.count)
        
        textView?.scrollRangeToVisible(currentResults[currentIndex].range)
    }
}

extension SearchQuery.MatchMethod: CaseIterable, CustomStringConvertible {
    public static var allCases: [SearchQuery.MatchMethod] = [.startsWith, .endsWith, .contains, .fullWord, .regularExpression]
    
    public var description: String {
        switch self {
        case .contains:
            return "Contains"
        case .fullWord:
            return "Full Word"
        case .startsWith:
            return "Starts With"
        case .endsWith:
            return "Ends With"
        case .regularExpression:
            return "Regex"
        }
    }
}
