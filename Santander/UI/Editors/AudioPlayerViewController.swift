//
//  AudioPlayerViewController.swift
//  Santander
//
//  Created by Serena on 06/07/2022
//
	

import UIKit
import MediaPlayer
import AVFoundation

class AudioPlayerViewController: UIViewController {
    let fileURL: URL
    var playButton: UIButton!
    var loopButton: UIButton!
    var playbackSlider: UISlider!
    var durationLabel: UILabel!
    var currentProgressLabel: UILabel!
    var forwardButton: UIButton!
    var backwardButton: UIButton!
    
    var player: AVAudioPlayer
    var asset: AVAsset
    lazy var displayLink: CADisplayLink = CADisplayLink(target: self, selector: #selector(sychronizeSliderProgress))

    /// Whether or not to loop, once the item is finished playing
    var doLoop: Bool = false
    
    var playbackSpeedRate: Float = UserPreferences.audioVCSpeed {
        didSet {
            UserPreferences.audioVCSpeed = playbackSpeedRate
            
            player.rate = playbackSpeedRate
        }
    }
    
    /// Name of the item currently being played
    var itemName: String {
        let nameFromMetadata = asset.metadata.first { $0.commonKey?.rawValue == "title" }?.stringValue
        return nameFromMetadata ?? fileURL.lastPathComponent // if we can't get the title from the metadata, return the filename
    }
    
    /// The name of the artist from the Metadata, if available
    var artistName: String? {
        return asset.metadata.first { $0.commonKey?.rawValue == "artist" }?.stringValue
    }
    
    /// The duration on the go backward / forward buttons
    /// 15 seconds by default, if not set in UserDefaults.
    var skipDuration: Int = UserPreferences.skipDuration {
        didSet {
            UserPreferences.skipDuration = skipDuration
        }
    }
    
    let availableSkipDurations: [Int] = [5, 10, 15, 30, 45, 60, 90]
    let availableSpeedRates: [Float] = [0.5, 1.0, 1.5, 2.0]
    
    /// The UIImage of the track's artwork, if available
    var artworkImage: UIImage? {
        guard let data = asset.metadata.first(where: { $0.commonKey?.rawValue == "artwork" })?.dataValue, let image = UIImage(data: data) else {
            return nil
        }
        
        return image
    }
    
    /// The image to display for the Play / Pause button
    var playButtonImage: UIImage? {
        let conf = UIImage.SymbolConfiguration(pointSize: 45, weight: .medium, scale: .medium)
        return UIImage(systemName: player.isPlaying ? "pause.fill" : "play.fill", withConfiguration: conf)?
            .withTintColor(.systemGray, renderingMode: .alwaysOriginal)
    }
    
    init(fileURL: URL, player: AVAudioPlayer) {
        self.fileURL = fileURL
        self.asset = AVAsset(url: fileURL)
        self.player = player
        
        self.player.enableRate = true
        self.player.rate = playbackSpeedRate
        
        super.init(nibName: nil, bundle: nil)
    }
    
    /// Initializes a new AudioPlayerViewController with the given audio file URL
    convenience init(fileURL: URL) throws {
        self.init(fileURL: fileURL, player: try AVAudioPlayer(contentsOf: fileURL))
    }
    
    /// Initializes a new AudioPlayerViewController with the given file URL and data
    convenience init(fileURL: URL, data: Data) throws {
        self.init(fileURL: fileURL, player: try AVAudioPlayer(data: data))
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.backgroundColor = .secondarySystemBackground
        setupBarButtons()
        
        displayLink.add(to: .main, forMode: .default)
        
        addItemToSystemMediaPlayer()
        
        player.delegate = self
        let playAction = UIAction(image: playButtonImage) { _ in
            self.play()
        }
        
        self.playButton = UIButton(primaryAction: playAction)
        
        self.playbackSlider = UISlider()
        
        playbackSlider.minimumValue = 0
        playbackSlider.maximumValue = Float(player.duration)
        playbackSlider.isContinuous = false
        
        playbackSlider.setThumbImage(UIImage(systemName: "circle.fill"), for: .normal)
        playbackSlider.tintColor = .lightGray
        playbackSlider.addTarget(self, action: #selector(sliderDidChange(_:)), for: .valueChanged)
        playbackSlider.addTarget(self, action: #selector(didBeginDraggingSlider), for: .touchDown)
        
        let titleLabel = UILabel()
        titleLabel.text = itemName
        titleLabel.font = .preferredFont(forTextStyle: .title2)
        titleLabel.textAlignment = .left
        
        let artistLabel = UILabel()
        artistLabel.text = artistName ?? "Unknown Artist"
        artistLabel.textAlignment = .left
        artistLabel.textColor = .systemGray
        
        self.durationLabel = UILabel()
        durationLabel.text = format(timeInterval: player.duration)
        durationLabel.textColor = .systemGray
        
        self.currentProgressLabel = UILabel()
        currentProgressLabel.text = format(timeInterval: player.duration)
        currentProgressLabel.textColor = .systemGray
        
        let loopAction = UIAction(image: loopButtonImage()) { action in
            self.doLoop.toggle()
            self.loopButton.setImage(self.loopButtonImage(), for: .normal)
        }
        self.loopButton = UIButton(primaryAction: loopAction)
        
        self.forwardButton = UIButton(
            primaryAction: UIAction(
                image: UIImage(systemName: "goforward")?.withTintColor(.systemGray, renderingMode: .alwaysOriginal)
            ) { _ in
                self.player.currentTime += Double(self.skipDuration)
            }
        )
        
        self.backwardButton = UIButton(
            primaryAction: UIAction(
                image: UIImage(systemName: "gobackward")?.withTintColor(.systemGray, renderingMode: .alwaysOriginal)
            ) { _ in
                self.player.currentTime -= Double(self.skipDuration)
            }
        )
        
        let buttonsStackView = UIStackView(arrangedSubviews: [backwardButton, playButton, forwardButton])
        buttonsStackView.spacing = 40
        
        let labelsStackView = UIStackView(arrangedSubviews: [titleLabel, artistLabel])
        labelsStackView.axis = .vertical
        
        durationLabel.translatesAutoresizingMaskIntoConstraints = false
        playbackSlider.translatesAutoresizingMaskIntoConstraints = false
        buttonsStackView.translatesAutoresizingMaskIntoConstraints = false
        labelsStackView.translatesAutoresizingMaskIntoConstraints = false
        loopButton.translatesAutoresizingMaskIntoConstraints = false
        currentProgressLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Mark: adding the subviews
        view.addSubview(buttonsStackView)
        view.addSubview(labelsStackView)
        view.addSubview(durationLabel)
        view.addSubview(playbackSlider)
        view.addSubview(currentProgressLabel)
        view.addSubview(loopButton)
        
        NSLayoutConstraint.activate([
            playbackSlider.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: 120),
            playbackSlider.rightAnchor.constraint(equalTo: view.layoutMarginsGuide.rightAnchor),
            playbackSlider.leftAnchor.constraint(equalTo: view.layoutMarginsGuide.leftAnchor),
            
            buttonsStackView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            buttonsStackView.centerYAnchor.constraint(equalTo: playbackSlider.centerYAnchor, constant: 80),
  
            labelsStackView.rightAnchor.constraint(equalTo: playbackSlider.rightAnchor),
            labelsStackView.leftAnchor.constraint(equalTo: playbackSlider.leftAnchor),
            labelsStackView.bottomAnchor.constraint(equalTo: playbackSlider.topAnchor, constant: -10),
            
            durationLabel.rightAnchor.constraint(equalTo: titleLabel.rightAnchor),
            durationLabel.topAnchor.constraint(equalTo: playbackSlider.bottomAnchor),
            
            currentProgressLabel.leftAnchor.constraint(equalTo: titleLabel.leftAnchor),
            currentProgressLabel.topAnchor.constraint(equalTo: playbackSlider.bottomAnchor),
            
            loopButton.rightAnchor.constraint(equalTo: artistLabel.rightAnchor),
            loopButton.topAnchor.constraint(equalTo: artistLabel.topAnchor)
        ])
        
    }
    
    func play() {
        if player.isPlaying {
            player.pause()
        } else {
            try? AVAudioSession.sharedInstance().setCategory(.playback) // So that we can play in the background
            try? AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)
            
            player.play()
        }
        
        setPlayButtonImage()
    }
    
    func setPlayButtonImage() {
        playButton.setImage(playButtonImage, for: .normal)
    }
    
    @objc
    func sliderDidChange(_ sender: UISlider) {
        player.currentTime = Double(sender.value)
        displayLink.isPaused = false
    }
    
    @objc
    func sychronizeSliderProgress() {
        if !playbackSlider.isTracking {
            MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPMediaItemPropertyPlaybackDuration] = player.duration
            MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPNowPlayingInfoPropertyElapsedPlaybackTime] = player.currentTime
        }
        
        let synchronized = player.currentTime
        playbackSlider.setValue(Float(synchronized), animated: true)
        currentProgressLabel.text = format(timeInterval: synchronized)
        // show the current time left in the duration label
        if let currentTimeLeft = format(timeInterval: player.duration - player.currentTime) {
            self.durationLabel.text = "-\(currentTimeLeft)"
        }
        
        displayLink.isPaused = false
    }
    
    @objc func didBeginDraggingSlider() {
        displayLink.isPaused = true
    }
    
    /// Formats a time interval
    func format(timeInterval: TimeInterval) -> String? {
        let formatter = DateComponentsFormatter()
        
        // show all units that we'll allow
        formatter.zeroFormattingBehavior = []
        
        formatter.allowedUnits = [.second, .minute]
        // if longer than an hour or long as an hour, allow hours
        if timeInterval >= 3600 {
            formatter.allowedUnits.insert(.hour)
        }
        
        return formatter.string(from: timeInterval)
    }
    
    func loopButtonImage() -> UIImage? {
        let image = UIImage(systemName: "repeat")
        if !self.doLoop {
            return image?.withTintColor(.systemGray, renderingMode: .alwaysOriginal)
        }
        
        return image
    }
    
    func setupBarButtons() {
        let durationActions = availableSkipDurations.map { duration in
            UIAction(title: duration.description, state: self.skipDuration == duration ? .on : .off) { _ in
                self.skipDuration = duration
                self.setupBarButtons() // Update the menu
            }
        }
        
        let skipDurationSubMenu = UIMenu(title: "Backward / Forward duration", children: durationActions)
        
        let adjustSpeedActions = availableSpeedRates.map { rate in
            UIAction(title: rate.description, state: self.playbackSpeedRate == rate ? .on : .off) { _ in
                self.playbackSpeedRate = rate
                self.setupBarButtons() // Update the menu
            }
        }
        
        let adjustSpeedMenu = UIMenu(title: "Speed", image: UIImage(systemName: "speedometer"), children: adjustSpeedActions)
        let menu = UIMenu(children: [adjustSpeedMenu, skipDurationSubMenu])
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(image: UIImage(systemName: "ellipsis.circle"), menu: menu)
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Dismiss", primaryAction: UIAction { _ in
            self.dismiss(animated: true)
        })
    }
    
    func addItemToSystemMediaPlayer() {
        let center = MPNowPlayingInfoCenter.default()
        
        UIApplication.shared.beginReceivingRemoteControlEvents()
        MPRemoteCommandCenter.shared().playCommand.addTarget { event in
            self.player.play()
            self.setPlayButtonImage()
            return .success
        }
        
        MPRemoteCommandCenter.shared().pauseCommand.addTarget  {event in
            self.player.pause()
            self.setPlayButtonImage()
            return .success
        }
        
        MPRemoteCommandCenter.shared().nextTrackCommand.addTarget {event in
            self.player.currentTime += Double(self.skipDuration)
            return .success
        }
        
        MPRemoteCommandCenter.shared().previousTrackCommand.addTarget {event in
            self.player.currentTime -= Double(self.skipDuration)
            return .success
        }
        
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: self.itemName,
            MPNowPlayingInfoPropertyMediaType: MPNowPlayingInfoMediaType.audio.rawValue,
            MPNowPlayingInfoPropertyAssetURL: self.fileURL,
            MPNowPlayingInfoPropertyIsLiveStream: false
        ]
        
        if let album = asset.metadata.first(where: { $0.commonKey?.rawValue == "album" })?.stringValue {
            info[MPMediaItemPropertyAlbumTitle] = album
        }
        
        if let artist = self.artistName {
            info[MPMediaItemPropertyArtist] = artist
        }
        
        if let artworkImage = artworkImage {
            let mpArtwork = MPMediaItemArtwork(boundsSize: artworkImage.size) { _ in
                return artworkImage
            }
            
            info[MPMediaItemPropertyArtwork] = mpArtwork
        }
        
        center.nowPlayingInfo = info
    }
    
    override func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) {
        player.stop()
        super.dismiss(animated: flag, completion: completion)
    }
}

extension AudioPlayerViewController: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        if self.doLoop {
            player.play()
        }
        
        setPlayButtonImage()
    }
}
