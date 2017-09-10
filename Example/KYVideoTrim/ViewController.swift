//
//  ViewController.swift
//  KYVideoTrim
//
//  Created by kyleYang on 09/05/2017.
//  Copyright (c) 2017 kyleYang. All rights reserved.
//

import UIKit
import KYVideoTrim
import AVFoundation

class ViewController: UIViewController {

    var slider : KYVideoRangeSlider!
    let keyfameManager : KYVideoKeyframeManager = KYVideoKeyframeManager()
    let videoPlayerVC : KYVideoPlayerViewController = KYVideoPlayerViewController(nibName: nil, bundle: nil)
    let timeLabel : UILabel = UILabel(frame: .zero)

    override func viewDidLoad() {
        super.viewDidLoad()

        self.slider = KYVideoRangeSlider(frame: .zero)
        self.slider.delegate = self
        self.slider.backgroundColor = .clear
        self.slider.translatesAutoresizingMaskIntoConstraints = false
        self.slider.leftThumbImage = UIImage(named:"thumb")
        self.slider.rightThumbImage = UIImage(named:"thumb")
        self.slider.thumbWidth = 10
        self.view.addSubview(self.slider)

        let playView = self.videoPlayerVC.view!
        playView.backgroundColor = .red
        playView.translatesAutoresizingMaskIntoConstraints = false;
        self.view.addSubview(playView)

        self.timeLabel.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(self.timeLabel)
        self.timeLabel.isUserInteractionEnabled = true

        let tapAction = UITapGestureRecognizer(target: self, action: #selector(ViewController.trimVideo(_:)))
        self.timeLabel.addGestureRecognizer(tapAction)

        var constraints : [NSLayoutConstraint] = []

        let views = ["slider":self.slider,"playview":playView] as [String:Any]

        constraints += NSLayoutConstraint.constraints(withVisualFormat: "H:|-50-[slider]-50-|", options: NSLayoutFormatOptions(), metrics: nil, views: views)
        constraints += NSLayoutConstraint.constraints(withVisualFormat: "H:|-10-[playview]-10-|", options: NSLayoutFormatOptions(), metrics: nil, views: views)
        constraints += NSLayoutConstraint.constraints(withVisualFormat: "V:|-10-[playview]-120-|", options: NSLayoutFormatOptions(), metrics: nil, views: views)
        constraints.append(NSLayoutConstraint(item: self.slider, attribute: .bottom, relatedBy: .equal, toItem: self.view, attribute: .bottom, multiplier: 1.0, constant: -40))
        constraints.append(NSLayoutConstraint(item: self.slider, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .height, multiplier: 0.0, constant: 60))

        constraints.append(NSLayoutConstraint(item: self.timeLabel, attribute: .bottom, relatedBy: .equal, toItem: self.view, attribute: .bottom, multiplier: 1.0, constant: -10))
        constraints.append(NSLayoutConstraint(item: self.timeLabel, attribute: .centerX, relatedBy: .equal, toItem: self.view, attribute: .centerX, multiplier: 1.0, constant: 0))


        self.view.addConstraints(constraints)

        let url = Bundle.main.url(forResource: "example2", withExtension: "mp4")
        let asset = AVAsset(url: url!)
        self.keyfameManager.generateDefaultSequenceOfImages(from: asset) { (frames) in
            self.slider.updateAsset(asset, keyframes: frames)
        }
        self.videoPlayerVC.asset = asset
        self.videoPlayerVC.playButtonImage = UIImage(named: "play_big")


    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @objc func trimVideo(_ sender : Any){
        self.slider.trimQuality = .low
        self.slider.trimVideo { (status, path) in

        }
    }

}


extension ViewController : KYVideoRangeSliderDelegate{

    func videoRangeSliderBeginDragging(_ slider: KYVideoRangeSlider) {
        self.videoPlayerVC.pause()
    }

    func videoRangeSlider(_ slider: KYVideoRangeSlider, lowerValue: Double, upperValue: Double) {

        self.videoPlayerVC.seek(to:slider.mapperToCMTime(lowerValue))
        self.videoPlayerVC.playEndTime = upperValue
        let lowString = String(format: "%.1f", slider.lowerValue)
        let upperString = String(format: "%.1f", slider.upperValue)
        let lengthString = String(format: "%.1f", slider.trackedDuration)
        self.timeLabel.text = "开始"+lowString+"----结束"+upperString+"-----总共"+lengthString
    }

}

