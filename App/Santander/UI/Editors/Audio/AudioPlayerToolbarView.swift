//
//  AudioPlayerToolbarView.swift
//  Santander
//
//  Created by Serena on 29/08/2022.
//

import UIKit

class AudioPlayerToolbarView: UIView {
    let audioPlayerController: AudioPlayerViewController
    let parentViewController: UIViewController
    var playOrStopButton: UIButton!
    
    weak var delegate: AudioPlayerToolbarDelegate?
    
    init(_ audioPlayerController: AudioPlayerViewController, parentViewController: UIViewController, frame: CGRect) {
        self.audioPlayerController = audioPlayerController
        self.parentViewController = parentViewController
        
        super.init(frame: frame)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setPlayOrStopButtonImage(symbolConfiguration: UIImage.SymbolConfiguration) {
        let playButtonImage = UIImage(systemName: audioPlayerController.playButtonSymbolName(), withConfiguration: symbolConfiguration)
        if playOrStopButton.image(for: .normal) != nil {
            playOrStopButton.setImage(nil, for: .normal)
        } else {
            playOrStopButton.setImage(playButtonImage, for: .normal)
        }
    }
    
    @objc
    func playOrStop() {
        audioPlayerController.play()
        setPlayOrStopButtonImage(symbolConfiguration: UIImage.SymbolConfiguration(pointSize: 20))
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        let titleLabel = UILabel()
        titleLabel.text = audioPlayerController.itemName
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let symbolConf = UIImage.SymbolConfiguration(pointSize: 20)
        
        playOrStopButton = UIButton()
        playOrStopButton.addTarget(self, action: #selector(playOrStop), for: .touchUpInside)
        setPlayOrStopButtonImage(symbolConfiguration: symbolConf)
        
        audioPlayerController.playbackCallback = {
            self.setPlayOrStopButtonImage(symbolConfiguration: symbolConf)
        }
        
        let cancelAction = UIAction(image: UIImage(systemName: "xmark", withConfiguration: symbolConf)) { _ in
            self.delegate?.audioToolbarDidClickCancelButton(self)
        }
        
        let cancelButton = UIButton(primaryAction: cancelAction)
        
        let buttonsStackView = UIStackView(arrangedSubviews: [playOrStopButton, cancelButton])
        buttonsStackView.spacing = 10
        buttonsStackView.translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(titleLabel)
        addSubview(buttonsStackView)
        NSLayoutConstraint.activate([
            titleLabel.leftAnchor.constraint(equalTo: layoutMarginsGuide.leftAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: layoutMarginsGuide.centerYAnchor),
            
            buttonsStackView.rightAnchor.constraint(equalTo: layoutMarginsGuide.rightAnchor, constant: -10),
            buttonsStackView.centerYAnchor.constraint(equalTo: layoutMarginsGuide.centerYAnchor),
        ])
    }
}

protocol AudioPlayerToolbarDelegate: AnyObject {
    func audioToolbarDidClickCancelButton(_ toolbar: AudioPlayerToolbarView)
}
