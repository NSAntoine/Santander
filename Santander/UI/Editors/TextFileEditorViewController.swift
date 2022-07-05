//
//  TextFileEditorViewController.swift
//  Santander
//
//  Created by Serena on 02/07/2022
//
	

import UIKit
// Unfortunately, using a dep here for the text editor
// but honestly, it just makes everything easier
// I'm not integrating Syntax highlighting myself.
import Runestone

class TextFileEditorViewController: UIViewController, TextViewDelegate, EditorThemeSettingsDelegate {
    let fileURL: URL
    var originalContents: String
    
    var textView: TextView = TextView()
    var keyboardToolsView: KeyboardToolsView!
    var theme = UserPreferences.textEditorTheme {
        didSet {
            UserPreferences.textEditorTheme = theme
            DispatchQueue.global(qos: .userInitiated).sync {
                let state = TextViewState(text: textView.text, theme: theme.theme)
                DispatchQueue.main.async {
                    self.textView.setState(state)
                }
            }
        }
    }
    
    init(fileURL: URL, contents: String) {
        self.fileURL = fileURL
        self.originalContents = contents
        
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = fileURL.lastPathComponent
        textView.text = originalContents
        textView.theme = theme.theme
        textView.showLineNumbers = true
        
        textView.autocorrectionType = .no
        textView.autocapitalizationType = .none
        
        textView.isEditable = /*FileManager.default.isWritableFile(atPath: fileURL.path)*/ true
        textView.editorDelegate = self
        textView.backgroundColor = .tertiarySystemBackground
        self.keyboardToolsView = KeyboardToolsView(textView: textView)
        textView.inputAccessoryView = keyboardToolsView
        
        let saveBarButton = UIBarButtonItem(barButtonSystemItem: .save, target: self, action: #selector(saveToFile))
        saveBarButton.isEnabled = !textIsSameAsOriginal
        navigationItem.rightBarButtonItems = [saveBarButton, UIBarButtonItem(image: UIImage(systemName: "ellipsis.circle"), menu: makeRightBarMenuItemsMenu())]

        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancel))
        
        textView.keyboardDismissMode = .onDrag
        textView.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(textView)

        setupNavBar()
        
        NSLayoutConstraint.activate([
            textView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            textView.topAnchor.constraint(equalTo: self.view.topAnchor),
            textView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor)
        ])
    }
    
    func makeRightBarMenuItemsMenu() -> UIMenu {
        let settingsAction = UIAction(title: "Settings", image: UIImage(systemName: "gear")) { _ in
            self.presentTextEditorSettings()
        }
        
        return UIMenu(image: UIImage(systemName: "ellipsis.circle"), children: [settingsAction])
    }
    
    func textViewDidChange(_ textView: TextView) {
        self.navigationItem.rightBarButtonItem?.isEnabled = !textIsSameAsOriginal
    }
    
    func setupNavBar() {
        let navigationBarAppearance = UINavigationBarAppearance()
        navigationBarAppearance.configureWithDefaultBackground()
        navigationController?.navigationBar.compactAppearance = navigationBarAppearance
        navigationController?.navigationBar.compactAppearance = navigationBarAppearance
        navigationController?.navigationBar.scrollEdgeAppearance = navigationBarAppearance
    }
    
    @objc
    func saveToFile() {
        let newContentsToSave = textView.text
        
        do {
            try newContentsToSave.write(to: fileURL, atomically: true, encoding: .utf8)
            self.dismiss(animated: true)
        } catch {
            self.errorAlert(error, title: "Unable to save to file")
        }
    }
    
    @objc
    func cancel() {
        self.dismiss(animated: true)
    }
    
    /// Whether or not the inputted text in the textView
    /// is the same as the original text
    var textIsSameAsOriginal: Bool {
        let text = textView.text
        return text == originalContents || text == originalContents.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    @objc func presentTextEditorSettings() {
        let settings = EditorThemeSettingsViewController(style: .insetGrouped, theme: self.theme)
        settings.delegate = self
        let navVC = UINavigationController(rootViewController: settings)
        if #available(iOS 15.0, *) {
            navVC.sheetPresentationController?.detents = [.medium(), .large()]
        }
        self.present(navVC, animated: true)
    }
    
    func themeDidChange(to newTheme: CodableTheme) {
        self.theme = newTheme
    }
    
    func wrapLinesConfigurationDidChange(wrapLines: Bool) {
        self.textView.isLineWrappingEnabled = wrapLines
    }
    
    func showLineCountConfigurationDidChange(showLineCount: Bool) {
        self.textView.showLineNumbers = showLineCount
    }
}
