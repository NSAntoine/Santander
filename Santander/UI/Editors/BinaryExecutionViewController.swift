//
//  BinaryExecutionViewController.swift
//  Santander
//
//  Created by Serena on 06/09/2022
//
	

import UIKit
import NSTaskBridge

class BinaryExecutionViewController: UIViewController {
    let executableURL: URL
    var task: NSTask = NSTask()
    
    var outputTextView: UITextView!
    var executableTextView: UITextView!
    
    init(executableURL: URL) {
        self.executableURL = executableURL
        
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .secondarySystemBackground
        
        title = "Execution"
        let doneAction = UIAction {
            if self.task.isRunning {
                self.task.suspend()
            }
            self.dismiss(animated: true)
        }
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(systemItem: .done, primaryAction: doneAction)
        configureNavigationBarToNormal()
        
        executableTextView = UITextView()
        
        executableTextView.delegate = self
        executableTextView.autocorrectionType = .no
        executableTextView.returnKeyType = .go
        executableTextView.text = executableURL.path
        executableTextView.font = UIFont(name: "Menlo", size: UIFont.systemFontSize)
        executableTextView.translatesAutoresizingMaskIntoConstraints = false
        executableTextView.backgroundColor = .systemBackground
        executableTextView.inputAccessoryView = makeKeyboardToolbar(for: executableTextView)
        view.addSubview(executableTextView)
        
        let guide = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            executableTextView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            executableTextView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            executableTextView.topAnchor.constraint(equalTo: guide.topAnchor),
            executableTextView.heightAnchor.constraint(equalToConstant: 50),
        ])
        
        self.outputTextView = UITextView()
        outputTextView.text = ""
        outputTextView.font = .systemFont(ofSize: 20)
        outputTextView.isEditable = false
        outputTextView.translatesAutoresizingMaskIntoConstraints = false
        outputTextView.backgroundColor = view.backgroundColor
        view.addSubview(outputTextView)
        
        NSLayoutConstraint.activate([
            outputTextView.leadingAnchor.constraint(equalTo: guide.leadingAnchor),
            outputTextView.trailingAnchor.constraint(equalTo: guide.trailingAnchor),
            outputTextView.topAnchor.constraint(equalTo: executableTextView.bottomAnchor),
            outputTextView.heightAnchor.constraint(equalTo: view.safeAreaLayoutGuide.heightAnchor)
        ])
    }
    
    func makeKeyboardToolbar(for respondor: UIResponder) -> UIToolbar {
        let toolbar = UIToolbar()
        
        let dismissKeyboardAction = UIAction {
            respondor.resignFirstResponder()
        }
        
        let dismissButton = UIBarButtonItem(title: "Dismiss", primaryAction: dismissKeyboardAction)
        toolbar.setItems([.flexibleSpace(), dismissButton], animated: true)
        toolbar.sizeToFit()
        return toolbar
    }
    
    func spawnExecutable(pathAndArgs: String) {
        var components = pathAndArgs.components(separatedBy: " ")
        guard let executable = components.first, !executable.isEmpty else {
            self.errorAlert("Enter a valid executable and arguments.", title: "Input is empty")
            return
        }
        
        // make it just args
        components.removeFirst()
        self.task = NSTask()
        task.executableURL = URL(fileURLWithPath: executable)
        task.arguments = components
        
        let pipe = Pipe()
        pipe.fileHandleForReading.readabilityHandler = { outPipe in
            guard let output = String(data: outPipe.availableData, encoding: .utf8),
            !output.isEmpty else {
                return
            }
            
            DispatchQueue.main.async {
                self.outputTextView.text.append(output)
            }
        }
        
        task.standardError = pipe
        task.standardOutput = pipe
        do {
            outputTextView.text = ""
            try task.launchAndReturnError()
            task.waitUntilExit()
        } catch {
            self.errorAlert(error, title: "Unable to launch process")
        }
    }
}

extension BinaryExecutionViewController: UITextViewDelegate {
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        if text == "\n" {
            if self.task.isRunning {
                self.task.interrupt()
            }
            self.spawnExecutable(pathAndArgs: executableTextView.text!)
            return false
        }
        
        return true
    }
}
