//
//  AudioPlayerToolbarView.swift
//  Santander
//
//  Created by Serena on 29/08/2022.
//

import UIKit

class AudioPlayerToolbarView: UIView {
    let audioPlayerController: AudioPlayerViewController
    weak var delegate: AudioPlayerToolbarDelegate?
    var playButton: UIButton!
    
    init(_ audioPlayerController: AudioPlayerViewController, frame: CGRect) {
        self.audioPlayerController = audioPlayerController
        
        super.init(frame: frame)
        
        let titleLabel = UILabel()
        titleLabel.text = audioPlayerController.itemName
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel)
        
        let cancelAction = UIAction(image: UIImage(systemName: "xmark.circle")) { _ in
            self.delegate?.audioToolbarDidClickCancelButton(self)
        }
        
        self.playButton = UIButton()
        setPlayButtonImage()
        let playOrStopAction = UIAction { _ in
            self.playOrStop()
        }
        
        playButton.addAction(playOrStopAction, for: .touchUpInside)
        
        audioPlayerController.playbackCallback = {
            self.setPlayButtonImage()
        }
        
        let cancelButton = UIButton(primaryAction: cancelAction)
        let buttonsStackView = UIStackView(arrangedSubviews: [playButton, cancelButton])
        buttonsStackView.spacing = 10
        buttonsStackView.translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(buttonsStackView)
        
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: layoutMarginsGuide.leadingAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            
            buttonsStackView.centerYAnchor.constraint(equalTo: centerYAnchor),
            buttonsStackView.trailingAnchor.constraint(equalTo: layoutMarginsGuide.trailingAnchor)
        ])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    func playOrStop() {
        audioPlayerController.play()
        setPlayButtonImage()
    }
    
    func setPlayButtonImage() {
        playButton.setImage(audioPlayerController.playButtonImage(withSize: 20, imageTintColor: nil), for: .normal)
    }
}

protocol AudioPlayerToolbarDelegate: AnyObject {
    func audioToolbarDidClickCancelButton(_ toolbar: AudioPlayerToolbarView)
}
