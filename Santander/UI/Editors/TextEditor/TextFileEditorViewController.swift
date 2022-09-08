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
    var fileURL: URL
    var originalContents: String
    
    var textView: TextView = TextView()
    var keyboardToolsView: KeyboardToolsView!
    var theme: CodableTheme = UserPreferences.textEditorTheme {
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
    
    convenience init(fileURL: URL) throws {
        self.init(fileURL: fileURL, contents: try String(contentsOf: fileURL))
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = fileURL.lastPathComponent
        textView.showLineNumbers = UserPreferences.showLineCount
        textView.isLineWrappingEnabled = UserPreferences.wrapLines
        textView.setState(TextViewState(text: originalContents, theme: theme.theme))
        
        textView.autocorrectionType = .no
        textView.autocapitalizationType = .none
        if UserPreferences.useCharacterPairs {
            textView.characterPairs = AnyCharacterPair.all()
        }
        
        textView.isEditable = /*FileManager.default.isWritableFile(atPath: fileURL.path)*/ true
        textView.editorDelegate = self
        textView.backgroundColor = theme.textEditorBackgroundColor?.uiColor ?? .tertiarySystemBackground
        self.keyboardToolsView = KeyboardToolsView(textView: textView)
        textView.inputAccessoryView = keyboardToolsView
        
        let saveBarButton = UIBarButtonItem(barButtonSystemItem: .save, target: self, action: #selector(saveToFile))
        saveBarButton.isEnabled = !textIsSameAsOriginal
        navigationItem.rightBarButtonItems = [saveBarButton, UIBarButtonItem(image: UIImage(systemName: "ellipsis.circle"), menu: makeRightBarMenuItemsMenu())]
        
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancel))
        
#if compiler(>=5.7)
        if #available(iOS 16.0, *) {
            navigationItem.style = .editor
            self.navigationItem.renameDelegate = self
            self.navigationItem.documentProperties = UIDocumentProperties(url: self.fileURL)
        }
#endif
        
        textView.keyboardDismissMode = .onDrag
        textView.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(textView)
        
        configureNavigationBarToNormal()
        
        NSLayoutConstraint.activate([
            textView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            textView.topAnchor.constraint(equalTo: self.view.topAnchor),
            textView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor)
        ])
        
        splitViewController?.preferredDisplayMode = .secondaryOnly
    }
    
    func makeRightBarMenuItemsMenu() -> UIMenu {
        let settingsAction = UIAction(title: "Settings", image: UIImage(systemName: "gear")) { _ in
            self.presentTextEditorSettings()
        }
        
        let goToLineAction = UIAction(title: "Go to line") { _ in
            self.showGoToLine()
        }
        
        return UIMenu(image: UIImage(systemName: "ellipsis.circle"), children: [settingsAction, goToLineAction])
    }
    
    func showGoToLine() {
        let alert = UIAlertController(title: "Go to line", message: nil, preferredStyle: .alert)
        alert.addTextField { textField in
            textField.keyboardType = .numberPad
        }
        
        let goToLineAction = UIAlertAction(title: "Go to line", style: .default) { _ in
            guard let text = alert.textFields?.first?.text, let line = Int(text) else {
                print("\(#function) should not have reached here!")
                return
            }
            
            
            self.textView.goToLine(line - 1)
        }
        
        alert.addAction(.cancel())
        alert.addAction(goToLineAction)
        self.present(alert, animated: true)
    }
    
    func textViewDidChange(_ textView: TextView) {
        self.navigationItem.rightBarButtonItem?.isEnabled = !textIsSameAsOriginal
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
        if !textIsSameAsOriginal {
            let alert = UIAlertController(title: "Unsaved changes", message: "the file \"\(fileURL.lastPathComponent)\" has some unsaved changes, are you sure you want to close the file?", preferredStyle: .alert)
            let saveAction = UIAlertAction(title: "Save", style: .default) { _ in
                self.saveToFile()
            }
            let dontSaveAction = UIAlertAction(title: "Don't save", style: .destructive) { _ in
                self.dismiss(animated: true)
            }
            alert.addAction(dontSaveAction)
            alert.addAction(saveAction)
            self.present(alert, animated: true)
        } else {
            self.dismiss(animated: true)
        }
    }
    
    /// Whether or not the inputted text in the textView
    /// is the same as the original text
    var textIsSameAsOriginal: Bool {
        let text = textView.text
        return text == originalContents || text == originalContents.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    @objc func presentTextEditorSettings() {
        let settings = TextEditorThemeSettingsViewController(style: .insetGrouped, theme: self.theme)
        settings.delegate = self
        let navVC = UINavigationController(rootViewController: settings)
        
        if UIDevice.current.isiPad {
            splitViewController?.setViewController(navVC, for: .primary)
            splitViewController?.preferredDisplayMode = .oneBesideSecondary
        } else {
            if #available(iOS 15.0, *) {
                navVC.sheetPresentationController?.detents = [.medium(), .large()]
            }
            self.present(navVC, animated: true)
        }
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
    
    func didChangeEditorBackground(to color: CodableColor) {
        self.textView.backgroundColor = color.uiColor
        self.theme.textEditorBackgroundColor = color
    }
    
    func characterPairConfigurationDidChange(useCharacterPairs: Bool) {
        textView.characterPairs = useCharacterPairs ? AnyCharacterPair.all() : []
    }
}

#if compiler(>=5.7)
extension TextFileEditorViewController: UINavigationItemRenameDelegate {
    func navigationItem(_: UINavigationItem, didEndRenamingWith title: String) {
        let newURL = self.fileURL.deletingLastPathComponent().appendingPathComponent(title)
        
        // make sure the new filename isn't the same as the current
        guard newURL != self.fileURL else {
            return
        }
        
        do {
            try FileManager.default.moveItem(at: self.fileURL, to: newURL)
            self.fileURL = newURL
        } catch {
            self.errorAlert(error, title: "Uname to rename \(fileURL.lastPathComponent)")
            // renaming automatically changes title
            // so we need to change back the title to the original
            // in case of a failure
            self.title = fileURL.lastPathComponent
        }
    }
}
#endif
