//
//  KYVideoPlayerView.swift
//  Pods
//
//  Created by Kyle on 2017/9/5.
//
//

import UIKit
import AVFoundation


let KYVideoTrimPlayerInterfaceAnimationDuration = 0.15

public enum KYVideoTrimPlayerPlaybackState : Int {
    case unknown
    case prepared
    case playing
    case paused
    case stoped
    case failed
    case didPlayToEndTime
}

public enum KYVideoTrimFillMode: Int {
    case resizeAspect
    case resizeAspectFill
    case resize

    public var description: String {
        switch self {
        case .resizeAspect:
            return AVLayerVideoGravityResizeAspect
        case .resizeAspectFill:
            return AVLayerVideoGravityResizeAspectFill
        case .resize: return AVLayerVideoGravityResize

        }
    }
}


public typealias KYVideoTrimPlayerProgressHandler = (CMTime) -> Void
public typealias KYVideoTrimPlayerPlaybackStateChangedHandler = (KYVideoTrimPlayerPlaybackState) -> Void

open class KYVideoPlayerViewController: UIViewController {

    //MARK: - Public Properties
    public var asset: AVAsset?{
        didSet{
            self.videoView.player = self.player
            self.timeUnObserver()
            self.configTimeObserver()
            NotificationCenter.default.removeObserver(self)
            self.configNotifications()
        }
    }
    public var progressHandler: KYVideoTrimPlayerProgressHandler?
    public var playbackStateChangedHandler: KYVideoTrimPlayerPlaybackStateChangedHandler?
    public var playEndTime : Double?

    public var playButtonWidth : CGFloat = 40 {
        didSet{
            self.playButtonWidthConstraint.constant = self.playButtonWidth
        }
    }
    public var playButtonHeight :CGFloat = 40{
        didSet{
            self.playButtonHeightConstraint.constant = self.playButtonHeight
        }
    }

    public var playButtonImage : UIImage? {
        didSet{
            self.playButton.setImage(self.playButtonImage, for: .normal)
        }
    }

    public var playButtonBackgroundImage : UIImage?{
        didSet{
            self.playButton.setBackgroundImage(self.playButtonBackgroundImage, for: .normal)
        }
    }


    //MARK: - Private Properties
    private lazy var videoView: KYVideoPlayerView = {
        let videoView = KYVideoPlayerView(frame: CGRect.zero)
        videoView.videoFillMode = .resizeAspect
        return videoView
    }()

    private lazy var player: AVPlayer = {
        return AVPlayer(playerItem: self.playerItem)
    }()

    private lazy var playerItem: AVPlayerItem? = {
        if let asset = self.asset {
            return AVPlayerItem(asset: asset)
        }
        return nil
    }()

    private let playButton = UIButton(frame: .zero)
    private var playButtonWidthConstraint : NSLayoutConstraint!
    private var playButtonHeightConstraint : NSLayoutConstraint!


    /// playback progress observer
    private var timeObserver: Any?
    private var timeScale: CMTimeScale {
        return asset?.duration.timescale ?? 600
    }

    /// playback state
    public private(set) var playbackState: KYVideoTrimPlayerPlaybackState = .unknown {
        didSet {

            if playbackState == .unknown{
                playButton.isHidden = true
            }else if playbackState == .prepared {
                playButton.isHidden = false
            }else if playbackState == .playing {
                playButton.isHidden = true
            }else if playbackState == .paused {
                playButton.isHidden = false
            } else if playbackState == .stoped {
                playButton.isHidden = false
            } else if playbackState == .failed {
                playButton.isHidden = false
            } else if playbackState == .didPlayToEndTime {
                playButton.isHidden = false
            }
            playbackStateChangedHandler?(playbackState)
        }
    }

    //MARK: - Life Cycle
    deinit {
        // Remove Observers
        self.timeUnObserver()
        NotificationCenter.default.removeObserver(self)
    }

    override open func loadView() {
        self.view = self.videoView

        self.playButton.translatesAutoresizingMaskIntoConstraints = false
        self.playButton.addTarget(self, action: #selector(KYVideoPlayerViewController.onPlay(_:)), for: .touchUpInside)
        self.view.addSubview(self.playButton)

        var constraints : [NSLayoutConstraint] = []



        self.playButtonWidthConstraint = NSLayoutConstraint(item: self.playButton, attribute: .width, relatedBy: .equal, toItem: nil, attribute: .width, multiplier: 0.0, constant: self.playButtonWidth)
        self.playButtonHeightConstraint =  NSLayoutConstraint(item: self.playButton, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .height, multiplier: 0.0, constant: self.playButtonHeight)

        constraints.append(NSLayoutConstraint(item: self.playButton, attribute: .centerX, relatedBy: .equal, toItem: self.view, attribute: .centerX, multiplier: 1.0, constant: 0))
        constraints.append(NSLayoutConstraint(item: self.playButton, attribute: .centerY, relatedBy: .equal, toItem: self.view, attribute: .centerY, multiplier: 1.0, constant: 0))
        constraints.append(self.playButtonWidthConstraint)
        constraints.append(self.playButtonHeightConstraint)
        self.view.addConstraints(constraints)

    }

    override open func viewDidLoad() {
        super.viewDidLoad()

    }

    open override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        if playbackState == .unknown { playbackState = .prepared }
    }

    override open func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


    public func playFromBeginning() {
        seek(to: kCMTimeZero)
        playFromCurrentTime()
    }

    public func playFromCurrentTime() {
        guard playbackState != .unknown else {
            return
        }
        playbackState = .playing
        self.player.play()
    }


    /// pause if playing
    public func pause() {
        guard playbackState == .playing else {
            return
        }
        self.player.pause()
        playbackState = .paused
    }

    /// pause and seek to kCMTimeZero
    public func stop() {
        guard playbackState != .stoped else {
            return
        }
        self.player.pause()
        seek(to: kCMTimeZero)
        playbackState = .stoped
    }

    /// seek to time
    ///
    /// - parameter time
    public func seek(to time: CMTime) {
        self.player.seek(to: time, toleranceBefore: CMTimeMake(0, self.timeScale), toleranceAfter: CMTimeMake(0, self.timeScale)) {_ in

        }
    }

    //MARK: - Private Methods

    /// observe playback progress
    private func configTimeObserver() {
        self.timeObserver = self.player.addPeriodicTimeObserver(forInterval: CMTimeMake(1, self.timeScale), queue: DispatchQueue.main, using: {  [weak self] time in
            if let strongSelf = self {
                if let progressHandler = strongSelf.progressHandler {
                    progressHandler(time)
                }

                if let endTime = strongSelf.playEndTime {
                    let timeSecond = time.seconds
                    if timeSecond >= endTime {
                        strongSelf.stop()
                    }
                }
            }
        })
    }

    private func timeUnObserver(){
        if let timeObserver = self.timeObserver {
            self.player.removeTimeObserver(timeObserver)
        }
    }

    /// add playback notifications and application status notifications
    private func configNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(KYVideoPlayerViewController.didPlayToEndTime), name: Notification.Name.AVPlayerItemDidPlayToEndTime, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(KYVideoPlayerViewController.failedToPlayToEndTime), name: Notification.Name.AVPlayerItemFailedToPlayToEndTime, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(KYVideoPlayerViewController.applicationWillResignActive), name: NSNotification.Name.UIApplicationWillResignActive, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(KYVideoPlayerViewController.applicationDidEnterBackground), name: NSNotification.Name.UIApplicationDidEnterBackground, object: nil)
    }

    //MARK: - Notification Methods
    @objc private func didPlayToEndTime() {
        playbackState = .didPlayToEndTime
    }

    @objc private func failedToPlayToEndTime() {
        playbackState = .failed
    }

    @objc private func applicationWillResignActive() {
        pause()
    }

    @objc private func applicationDidEnterBackground() {
        pause()
    }


    @objc private func onPlay(_ sender: AnyObject) {
        if playbackState == .didPlayToEndTime {
            self.playFromBeginning()
        } else {
            self.playFromCurrentTime()
        }
    }


}


open class KYVideoPlayerView: UIView {

    override open class var layerClass: Swift.AnyClass {
        return AVPlayerLayer.self
    }

    //MARK: - Public Properties
    public var player: AVPlayer? {
        didSet {
            self.playerLayer.player = player
        }
    }

    public var playerLayer: AVPlayerLayer {
        return self.layer as! AVPlayerLayer
    }

    public var videoFillMode: KYVideoTrimFillMode = .resizeAspect {
        didSet {
            self.playerLayer.videoGravity = videoFillMode.description
        }
    }

    public var playerLayerBackgroundColor = UIColor.white.cgColor {
        didSet {
            self.playerLayer.backgroundColor = playerLayerBackgroundColor
        }
    }


    //MARK: - Init Related
    override init(frame: CGRect) {
        super.init(frame: frame)

        self.playerLayer.backgroundColor = playerLayerBackgroundColor
    }

    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

}
