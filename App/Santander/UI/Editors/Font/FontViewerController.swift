//
//  FontViewerController.swift
//  Santander
//
//  Created by Serena on 03/09/2022.
//

import UIKit

/// A ViewController displaying a seleceted font, with a Text View to type text with the font
/// and a slider to change the size of the font
class FontViewerController: UIViewController {
    var selectedFont: UIFont
    var descriptors: [CTFontDescriptor]
    
    var textView: UITextView!
    var amountLabel: UILabel!
    
    init(selectedFont: UIFont, descriptors: [CTFontDescriptor]) {
        self.selectedFont = selectedFont
        self.descriptors = descriptors
        super.init(nibName: nil, bundle: nil)
        
        self.title = selectedFont.familyName
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationController?.navigationBar.prefersLargeTitles = false
        
        view.backgroundColor = .systemBackground
        
        setupRightBarButton()
        
        self.textView = UITextView()
        textView.text = "The quick brown fox jumps over the lazy dog and runs away."
        textView.font = self.selectedFont
        textView.inputAccessoryView = makeKeyboardToolbar(textView: textView)
        textView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(textView)
        
        NSLayoutConstraint.activate([
            textView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            textView.topAnchor.constraint(equalTo: view.topAnchor),
            textView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        configureNavigationBarToNormal()
        setupBottomView()
    }
    
    func setupRightBarButton() {
        let presentInfoAction = UIAction {
            if self.descriptors.count > 1 {
                // if there is more than just one font
                // display an action sheet to choose between those
                let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
                let actions = self.descriptors.map { descriptor in
                    let uiFont = descriptor.uiFont
                    return UIAlertAction(title: uiFont.fontName, style: .default) { _ in
                        let vc = FontInformationViewController(font: uiFont)
                        self.present(UINavigationController(rootViewController: vc), animated: true)
                    }
                }
                
                for action in actions {
                    alert.addAction(action)
                }
                
                alert.addAction(.cancel())
                self.present(alert, animated: true)
            } else {
                // else, if there's just one font in the URL, just present the info vc for that
                let vc = FontInformationViewController(font: self.selectedFont)
                self.present(UINavigationController(rootViewController: vc), animated: true)
            }
        }
        
        let infoButton = UIBarButtonItem(image: UIImage(systemName: "info.circle"), primaryAction: presentInfoAction)

        // if there is more than one font descriptor
        // that means we can select more than 1 font
        // so, display a menu for choosing between those
        if descriptors.count > 1 {
            // the actions to change the selected font
            let selectFontActions = descriptors.map { descr in
                let uiFont = descr.uiFont
                return UIAction(title: uiFont.fontName, state: uiFont == self.selectedFont ? .on : .off) { _ in
                    self.selectedFont = uiFont.withSize(self.selectedFont.pointSize)
                    self.updateFontSize(newSize: self.selectedFont.pointSize)
                    self.setupRightBarButton()
                }
            }
            
            let selectFontMenu = UIMenu(children: selectFontActions)
            navigationItem.rightBarButtonItems = [
                UIBarButtonItem(title: "Select font..", menu: selectFontMenu),
                infoButton
            ]
        } else {
            // else, just display the info button and nothing else
            navigationItem.rightBarButtonItem = infoButton
        }
    }
    
    func updateFontSize(newSize: CGFloat) {
        UserPreferences.fontViewerFontSize = newSize
        self.selectedFont = selectedFont.withSize(newSize)
        self.textView.font = selectedFont
        amountLabel.text = Int(newSize).description
    }
    
    func setupBottomView() {
        let newView = UIView()
        newView.backgroundColor = .secondarySystemBackground
        
        // label displaying the current font size
        self.amountLabel = UILabel()
        amountLabel.text = Int(selectedFont.pointSize).description
        
        let slider = UISlider()
        slider.maximumValue = 90
        slider.value = Float(selectedFont.pointSize)
        
        let sliderChangedAction = UIAction {
            self.updateFontSize(newSize: CGFloat(slider.value))
        }
        
        slider.addAction(sliderChangedAction, for: .valueChanged)
        
        let stackView = UIStackView(arrangedSubviews: [slider, amountLabel])
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.spacing = 10
        
        newView.addSubview(stackView)
        newView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(newView)
        NSLayoutConstraint.activate([
            newView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            newView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            newView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -50),
            newView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
  
            stackView.centerYAnchor.constraint(equalTo: newView.centerYAnchor),
            stackView.leadingAnchor.constraint(equalTo: newView.layoutMarginsGuide.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: newView.layoutMarginsGuide.trailingAnchor),
        ])
        
    }
    
    func makeKeyboardToolbar(textView: UITextView) -> UIToolbar {
        let toolbar = UIToolbar()
        let action = UIAction {
            textView.resignFirstResponder()
        }
        
        let doneButton = UIBarButtonItem(systemItem: .done, primaryAction: action)
        
        toolbar.setItems([.flexibleSpace(), doneButton], animated: true)
        toolbar.sizeToFit()
        return toolbar
    }
}
