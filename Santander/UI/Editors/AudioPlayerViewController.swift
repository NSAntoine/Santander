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
    var artworkImageView: UIImageView!
    
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
    
    /// Initializes a new AudioPlayerViewController with the given audio file URL
    init(fileURL: URL) throws {
        self.fileURL = fileURL
        self.asset = AVAsset(url: fileURL)
        self.player = try AVAudioPlayer(contentsOf: fileURL)
        
        self.player.enableRate = true
        self.player.rate = playbackSpeedRate
        
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.backgroundColor = .secondarySystemBackground
        setupBarButtons()
        
        displayLink.add(to: .main, forMode: .default)
        
        addItemToControlCenter()
        
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
        
        
        durationLabel.translatesAutoresizingMaskIntoConstraints = false
        playbackSlider.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        artistLabel.translatesAutoresizingMaskIntoConstraints = false
        playButton.translatesAutoresizingMaskIntoConstraints = false
        loopButton.translatesAutoresizingMaskIntoConstraints = false
        currentProgressLabel.translatesAutoresizingMaskIntoConstraints = false
        forwardButton.translatesAutoresizingMaskIntoConstraints = false
        backwardButton.translatesAutoresizingMaskIntoConstraints = false
        
        // Mark: adding the subviews
        self.view.addSubview(playButton)
        self.view.addSubview(titleLabel)
        self.view.addSubview(artistLabel)
        self.view.addSubview(playbackSlider)
        self.view.addSubview(durationLabel)
        self.view.addSubview(currentProgressLabel)
        self.view.addSubview(loopButton)
        self.view.addSubview(forwardButton)
        self.view.addSubview(backwardButton)
        
        NSLayoutConstraint.activate([
            playButton.centerXAnchor.constraint(equalTo: self.view.centerXAnchor),
            playButton.centerYAnchor.constraint(equalTo: self.view.centerYAnchor, constant: 210),
            
            forwardButton.centerXAnchor.constraint(equalTo: self.playButton.centerXAnchor, constant: 70),
            forwardButton.centerYAnchor.constraint(equalTo: playButton.centerYAnchor),
            
            backwardButton.centerXAnchor.constraint(equalTo: self.playButton.centerXAnchor, constant: -70),
            backwardButton.centerYAnchor.constraint(equalTo: playButton.centerYAnchor),
            
            playbackSlider.centerYAnchor.constraint(equalTo: self.view.centerYAnchor, constant: 120),
            playbackSlider.rightAnchor.constraint(equalTo: self.view.rightAnchor, constant: -20),
            playbackSlider.leftAnchor.constraint(equalTo: self.view.leftAnchor, constant: 20),
            
            artistLabel.rightAnchor.constraint(equalTo: playbackSlider.rightAnchor),
            artistLabel.leftAnchor.constraint(equalTo: playbackSlider.leftAnchor),
            artistLabel.bottomAnchor.constraint(equalTo: playbackSlider.topAnchor, constant: -20),
            
            titleLabel.rightAnchor.constraint(equalTo: playbackSlider.rightAnchor),
            titleLabel.leftAnchor.constraint(equalTo: playbackSlider.leftAnchor),
            titleLabel.bottomAnchor.constraint(equalTo: artistLabel.topAnchor), // Put title label above artist label
            
            durationLabel.rightAnchor.constraint(equalTo: titleLabel.rightAnchor),
            durationLabel.topAnchor.constraint(equalTo: playbackSlider.bottomAnchor),
            
            currentProgressLabel.leftAnchor.constraint(equalTo: titleLabel.leftAnchor),
            currentProgressLabel.topAnchor.constraint(equalTo: playbackSlider.bottomAnchor),
            
            loopButton.rightAnchor.constraint(equalTo: artistLabel.rightAnchor),
            loopButton.topAnchor.constraint(equalTo: artistLabel.topAnchor)
        ])
        
        if let artworkImage = artworkImage {
            print(self.view.bounds.height)
            self.artworkImageView = UIImageView(image: resizeImage(image: artworkImage, newHeight: 320))
            artworkImageView.translatesAutoresizingMaskIntoConstraints = false
            artworkImageView.contentMode = .scaleAspectFit
            
            self.view.addSubview(artworkImageView)
            
            NSLayoutConstraint.activate([
                artworkImageView.centerYAnchor.constraint(equalTo: self.view.centerYAnchor, constant: -150),
                artworkImageView.rightAnchor.constraint(equalTo: playbackSlider.rightAnchor),
                artworkImageView.leftAnchor.constraint(equalTo: playbackSlider.leftAnchor),
            ])
        }
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
    
    @objc func sychronizeSliderProgress() {
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
        
        // show all units if 0
        if timeInterval != 0 {
            formatter.zeroFormattingBehavior = .dropTrailing
        } else {
            formatter.zeroFormattingBehavior = .pad
        }
        
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
    
    func addItemToControlCenter() {
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
    
    func resizeImage(image: UIImage, newHeight: CGFloat) -> UIImage? {
        let scale = newHeight / image.size.height
        let newWidth = image.size.width * scale
        UIGraphicsBeginImageContext(CGSize(width: newWidth, height: newHeight))
        image.draw(in: CGRect(x: 0, y: 0, width: newWidth, height: newHeight))
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return newImage
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
