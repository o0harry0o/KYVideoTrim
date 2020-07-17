//
//  KYVideoRangeSlider.swift
//  Pods
//
//  Created by Kyle on 2017/9/5.
//
//

import UIKit
import Foundation
import AVFoundation


public enum KYVideoTrimQuality: Int {
    case low = 0
    case medium = 1
    case highest = 2

    public var description: String {
        switch self {
        case .low:
            return AVAssetExportPresetLowQuality
        case .medium:
            return AVAssetExportPresetMediumQuality
        case .highest: return AVAssetExportPresetHighestQuality

        }
    }
}


public enum KYAssetExportSessionStatus : Int{
    case unknown

    case waiting

    case exporting

    case completed

    case failed

    case cancelled
}



internal class KYVideoRangeSliderThumbView : UIImageView{
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.isUserInteractionEnabled = true
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}


internal class KYVideoRangeSliderTrackLayer: CAShapeLayer {

    weak var rangeSlider : KYVideoRangeSlider?

    override func draw(in ctx: CGContext) {
        if let slider = rangeSlider {
            let lowerValuePosition = slider.leftThumbPositionX+slider.thumbWidth
            let upperValuePosition = slider.frame.width + slider.rightThumbPositionX - slider.thumbWidth
            let rect = CGRect(x: lowerValuePosition, y: 0.0, width: upperValuePosition - lowerValuePosition, height: bounds.height)
            ctx.setFillColor(slider.trackColor.cgColor)
            ctx.fill(rect)
        }
    }

}

internal class KYVideoRangeSliderUnTrackLayer: CAShapeLayer {

    weak var rangeSlider : KYVideoRangeSlider?

    var isLeftSide : Bool = true

    override func draw(in ctx: CGContext) {
        if let slider = rangeSlider {
            let leftPosition : CGFloat
            let width : CGFloat
            if isLeftSide {
                leftPosition = slider.thumbWidth
                width =  max((slider.leftThumbPositionX - slider.thumbWidth),0)
            }else{
                leftPosition = slider.frame.width + slider.rightThumbPositionX
                width =  max(abs(slider.rightThumbPositionX)-slider.thumbWidth,0)
            }

            let rect = CGRect(x: leftPosition, y: 1.0, width: width, height: bounds.height-2)
            ctx.setFillColor(slider.unTrackColor.cgColor)
            ctx.fill(rect)
        }
    }
    
}


public typealias KYVideoTrimCompleteHandler = (KYAssetExportSessionStatus,String) -> Void

@objc public protocol KYVideoRangeSliderDelegate : NSObjectProtocol{

    @objc optional func videoRangeSliderBeginDragging(_ slider:KYVideoRangeSlider)
    @objc optional func videoRangeSlider(_ slider:KYVideoRangeSlider, lowerValue : Float64,upperValue:Float64)
}



open class KYVideoRangeSlider: UIView {


    public weak var delegate :KYVideoRangeSliderDelegate?

    //MARK: property

    public var maxTrackTime : Float64 = 10.0{
        didSet{
            if self.maxTrackTime < self.minTrackTime {
                fatalError("error maxTrackTime < minTrackTime")
            }
        }
    }
    public var minTrackTime : Float64 = 3.0{
        didSet{
            if self.maxTrackTime < self.minTrackTime {
                fatalError("error maxTrackTime < minTrackTime")
            }
        }
    }
    public var trackedDuration : Float64{
        get{
            return self.upperValue - self.lowerValue
        }
    }
    public var lowerValue: Float64{
        get{
            return self.mapperLeftPositonToTime(self.leftThumbPositionX)
        }
    }
    public var upperValue: Float64{
        get{
            return self.mapperRightPositonToTime(self.rightThumbPositionX)
        }
    }

    public var leftThumbPositionX : CGFloat = 0{
        didSet{
            self.leftThumbViewLeadingContraint.constant = leftThumbPositionX
            self.updateLayerFrames()
        }
    }
    public var rightThumbPositionX : CGFloat = 0{
        didSet{
            self.rightThumbViewTrailingContraint.constant = rightThumbPositionX
            self.updateLayerFrames()
        }
    }

    public var selecteTimeLength : CGFloat  {
       return self.sliderWidth - self.leftThumbPositionX + self.rightThumbPositionX
    }

    public fileprivate(set) var rangeStartTime : Float64 = 0
    public fileprivate(set) var rangeEndTime : Float64 = 1
    fileprivate var keyframeWidth : CGFloat = 40
    fileprivate var videoTrackLength : CGFloat {
        let trackLength = self.keyframeWidth * CGFloat(self.videoKeyframes.count)
        if trackLength == 0 {
            return 1
        }
        return trackLength
    }

    public fileprivate(set) var trimVideoPath : String!
    public var trimQuality : KYVideoTrimQuality = .medium
    fileprivate var trimExportSession : AVAssetExportSession!

    public var displayDuration : Float64{
        get{
            return Float64(self.sliderWidth/self.videoTrackLength)*self.duration
        }
    }
    public private(set) var duration : Float64 = 0{
        didSet{
            if (self.duration < self.minTrackTime){
                self.minTrackTime = self.duration
                self.maxTrackTime = self.duration
                self.rangeStartTime = 0
                self.rangeEndTime = duration
            }else if (self.duration < self.maxTrackTime){
                self.maxTrackTime = self.duration
                self.rangeStartTime = 0
                self.rangeEndTime = duration
            }else if (duration > maxTrackTime){
                self.rangeStartTime = 0
                self.rangeEndTime = maxTrackTime
            }
            self.updateInitState()

        }
    }

    public private(set) var videoAsset : AVAsset?{
        didSet{
            if let asset = videoAsset {
                duration = Float64(CMTimeGetSeconds(asset.duration))
            }
        }
    }
    public private(set) var videoKeyframes : [KYVideoKeyframe] = []{
        didSet{

            var count = 0
            if (self.duration > self.maxTrackTime){
                let percent = self.maxTrackTime/self.duration
                let percentCount = Float64(self.videoKeyframes.count) * percent
                self.keyframeWidth = self.sliderWidth / CGFloat(percentCount)
            }else if(duration <= 3.0){
                count = videoKeyframes.count
                self.keyframeWidth = 40
                var contraintsValue =  CGFloat(count) * self.keyframeWidth - (self.sliderWidth)
                if contraintsValue > 0 {
                    contraintsValue = 0
                    self.keyframeWidth = self.sliderWidth/CGFloat(count)
                }
                self.collectionViewTraingContraint.constant = self.collectionViewTraingContraint.constant + contraintsValue
                self.rightThumbPositionX = self.collectionViewTraingContraint.constant+self.thumbWidth

            }else{
                count = videoKeyframes.count
                self.keyframeWidth = self.sliderWidth / CGFloat(count)
            }
            self.collectionView.reloadData()
            self.delegate?.videoRangeSlider?(self, lowerValue: self.lowerValue, upperValue: self.upperValue)
        }
    }

    open var trackColor : UIColor = UIColor.red {
        didSet{
            self.updateLayerFrames()
        }
    }

    open var unTrackColor : UIColor = UIColor(red: 0, green: 0, blue: 0, alpha: 0.5){
        didSet{
            self.updateLayerFrames()
        }
    }

    open var thumbWidth : CGFloat = 10{
        didSet{
            self.leftThumbViewWidthContraint.constant = self.thumbWidth
            self.rightThumbViewWidthContraint.constant = self.thumbWidth
            self.collectionViewLeadingContraint.constant = self.thumbWidth
            self.collectionViewTraingContraint.constant = -self.thumbWidth
        }
    }

    fileprivate var sliderWidth : CGFloat{
        get{
            return self.frame.width - self.collectionViewLeadingContraint.constant + self.collectionViewTraingContraint.constant
        }
    }

    open var leftThumbImage : UIImage?{
        didSet{
            self.leftThumbView.image = self.leftThumbImage
        }
    }

    open var rightThumbImage : UIImage? {
        didSet{
            self.rightThumbView.image = self.rightThumbImage
        }
    }

    //MARK: subviews
    internal var collectionView : UICollectionView!
    internal lazy var collectionFlowLayout : UICollectionViewFlowLayout = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = 0
        return layout
    }()

    internal let leftThumbView : KYVideoRangeSliderThumbView = KYVideoRangeSliderThumbView(frame: .zero)
    internal let rightThumbView : KYVideoRangeSliderThumbView = KYVideoRangeSliderThumbView(frame: .zero)
    internal var leftThumbViewLeadingContraint : NSLayoutConstraint!
    internal var leftThumbViewWidthContraint : NSLayoutConstraint!
    internal var rightThumbViewTrailingContraint : NSLayoutConstraint!
    internal var rightThumbViewWidthContraint : NSLayoutConstraint!
    internal var collectionViewLeadingContraint : NSLayoutConstraint!
    internal var collectionViewTraingContraint : NSLayoutConstraint!
    internal var trackLayer = KYVideoRangeSliderTrackLayer()
    internal var leftUntrackLayer = KYVideoRangeSliderUnTrackLayer()
    internal var rightUnTrackLayer = KYVideoRangeSliderUnTrackLayer()

    public override init(frame: CGRect) {
        super.init(frame: frame)
        self.setup()

    }

    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func updateAsset(_ asset : AVAsset?,keyframes : [KYVideoKeyframe]){
        guard let _ = asset , keyframes.count != 0 else{
            fatalError("update the video asset can not be nil")
        }
        self.videoAsset = asset
        self.videoKeyframes = keyframes
    }

    //MARK: private method
    private func setup(){

        let tempDir : NSString = NSTemporaryDirectory() as NSString
        self.trimVideoPath = tempDir.appendingPathComponent("trimvideo.mp4")

        self.trackLayer.rangeSlider = self
        self.layer.addSublayer(self.trackLayer)
        self.trackLayer.contentsScale = UIScreen.main.scale

        self.collectionView = UICollectionView(frame: .zero, collectionViewLayout: self.collectionFlowLayout)
        self.collectionView.translatesAutoresizingMaskIntoConstraints = false
        self.collectionView.delegate = self
        self.collectionView.dataSource = self
        self.collectionView.clipsToBounds = true
        self.addSubview(self.collectionView)
        self.collectionView.register(KYVideoRangeCollectionCell.self, forCellWithReuseIdentifier: "rangecell")

        self.leftThumbView.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(self.leftThumbView)

        self.rightThumbView.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(self.rightThumbView)


        self.leftUntrackLayer.rangeSlider = self
        self.leftUntrackLayer.isLeftSide = true
        self.layer.addSublayer(self.leftUntrackLayer)
        self.leftUntrackLayer.contentsScale = UIScreen.main.scale

        self.rightUnTrackLayer.rangeSlider = self
        self.rightUnTrackLayer.isLeftSide = false
        self.layer.addSublayer(self.rightUnTrackLayer)
        self.rightUnTrackLayer.contentsScale = UIScreen.main.scale


        var constraints : [NSLayoutConstraint] = []

        let views = ["leftThumbView":self.leftThumbView,"rightThumbView":self.rightThumbView,"collectionView":self.collectionView] as [String:Any]

        constraints += NSLayoutConstraint.constraints(withVisualFormat: "V:|[leftThumbView]|", options: NSLayoutFormatOptions(), metrics: nil, views: views)
        constraints += NSLayoutConstraint.constraints(withVisualFormat: "V:|[rightThumbView]|", options: NSLayoutFormatOptions(), metrics: nil, views: views)

        self.leftThumbViewLeadingContraint = NSLayoutConstraint(item: self.leftThumbView, attribute: .leading, relatedBy: .equal, toItem: self, attribute: .leading, multiplier: 1.0, constant: 0)
        self.leftThumbViewWidthContraint =  NSLayoutConstraint(item: self.leftThumbView, attribute: .width, relatedBy: .equal, toItem: nil, attribute: .width, multiplier: 0.0, constant: self.thumbWidth)
        self.rightThumbViewTrailingContraint = NSLayoutConstraint(item: self.rightThumbView, attribute: .trailing, relatedBy: .equal, toItem: self, attribute: .trailing, multiplier: 1.0, constant: 0)
        self.rightThumbViewWidthContraint =  NSLayoutConstraint(item: self.rightThumbView, attribute: .width, relatedBy: .equal, toItem: nil, attribute: .width, multiplier: 0.0, constant: self.thumbWidth)

        constraints += NSLayoutConstraint.constraints(withVisualFormat: "V:|-1-[collectionView]-1-|", options: NSLayoutFormatOptions(), metrics: nil, views: views)
        self.collectionViewLeadingContraint = NSLayoutConstraint(item: self.collectionView, attribute: .leading, relatedBy: .equal, toItem: self, attribute: .leading, multiplier: 1.0, constant: self.thumbWidth)
        self.collectionViewTraingContraint =  NSLayoutConstraint(item: self.collectionView, attribute: .trailing, relatedBy: .equal, toItem: self, attribute: .trailing, multiplier: 1.0, constant: -self.thumbWidth)

        constraints.append(self.collectionViewLeadingContraint)
        constraints.append(self.collectionViewTraingContraint)
        constraints.append(self.leftThumbViewLeadingContraint)
        constraints.append(self.leftThumbViewWidthContraint)
        constraints.append(self.rightThumbViewTrailingContraint)
        constraints.append(self.rightThumbViewWidthContraint)

        self.addConstraints(constraints)


        let leftThumbPan : UIPanGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(KYVideoRangeSlider.leftPanAction(_:)))
        self.leftThumbView.addGestureRecognizer(leftThumbPan)

        let rightThumbPan : UIPanGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(KYVideoRangeSlider.rightPanAction(_:)))
        self.rightThumbView.addGestureRecognizer(rightThumbPan)

    }

    private func updateInitState(){
        self.leftThumbPositionX = 0
        self.rightThumbPositionX = 0
    }

    open override func layoutSubviews() {
        self.updateLayerFrames()
    }

    fileprivate func updateLayerFrames(){
        self.trackLayer.frame = self.bounds
        self.leftUntrackLayer.frame = self.bounds
        self.rightUnTrackLayer.frame = self.bounds
        self.trackLayer.setNeedsDisplay()
        self.leftUntrackLayer.setNeedsDisplay()
        self.rightUnTrackLayer.setNeedsDisplay()
    }

    //mapper the position to time
    fileprivate func mapperLeftPositonToTime(_ postionX : CGFloat) -> Float64{
        return Float64(postionX/self.sliderWidth)*self.displayDuration + self.rangeStartTime
    }

    fileprivate func mapperRightPositonToTime(_ postionX : CGFloat) -> Float64{
        return Float64((self.frame.width - 2*self.thumbWidth + postionX)/self.sliderWidth)*self.displayDuration + self.rangeStartTime
    }
    //mapper the time to position
    fileprivate func mapperTimeToLeftPosition(_ time : Float64) -> CGFloat{
        return CGFloat((time - rangeStartTime)/self.displayDuration) * self.sliderWidth
    }
    fileprivate func mapperTimeToRightPosition(_ time : Float64) -> CGFloat{
        return  CGFloat((time - self.rangeStartTime)/self.displayDuration) * self.sliderWidth - self.frame.width + 2*self.thumbWidth
    }

    private func calucateLeftThumbPostion(_ postionX : CGFloat) -> CGFloat{
        var postion = postionX
        if postion < 0 {
            postion = 0
        }else if postion > self.sliderWidth{
            postion = self.sliderWidth
        }

        var positionTime = self.mapperLeftPositonToTime(postion)
        let selecteDuration = self.upperValue - positionTime
        if selecteDuration > self.maxTrackTime {
            positionTime = self.upperValue - self.maxTrackTime
        }else if selecteDuration < self.minTrackTime {
            positionTime = self.upperValue - self.minTrackTime
        }
        return self.mapperTimeToLeftPosition(positionTime)
    }

    private func calucateRightThumbPostion(_ postionX : CGFloat) -> CGFloat{
        var postion = postionX
        if postion < -(self.frame.width - self.thumbWidth) {
            postion = -(self.frame.width - self.thumbWidth)
        }else if postion > 0 {
            postion = 0
        }

        var positionTime = self.mapperRightPositonToTime(postion)
        let selecteDuration = positionTime - self.lowerValue
        if selecteDuration > self.maxTrackTime {
            positionTime = self.lowerValue + self.maxTrackTime
        }else if selecteDuration < minTrackTime {
            positionTime = self.lowerValue + self.minTrackTime
        }
        return self.mapperTimeToRightPosition(positionTime)
    }

    private func deleteTrimVideoFile(){
          let fm = FileManager.default
          let exist = fm.fileExists(atPath: self.trimVideoPath)
        if (exist){
            do{
                try fm.removeItem(atPath: self.trimVideoPath)
            }catch{
                print("remove file error %@",error)
            }

        }
    }


    //MARK: action
    @objc func leftPanAction(_ gesture : UIPanGestureRecognizer){
       if gesture.state == .began||gesture.state == .changed{
            let translation = gesture.translation(in: self)
            let postionMoved = self.leftThumbPositionX + translation.x
            self.leftThumbPositionX = self.calucateLeftThumbPostion(postionMoved)
            gesture.setTranslation(.zero, in: self)
            self.delegate?.videoRangeSlider?(self, lowerValue: self.lowerValue, upperValue: self.upperValue)
        }else if gesture.state == .ended{
            self.delegate?.videoRangeSlider?(self, lowerValue: self.lowerValue, upperValue: self.upperValue)
        }
    }

    @objc func rightPanAction(_ gesture : UIPanGestureRecognizer){
         if gesture.state == .began||gesture.state == .changed {
            let translation = gesture.translation(in: self)
            let postionMoved = self.rightThumbPositionX + translation.x
            self.rightThumbPositionX = self.calucateRightThumbPostion(postionMoved)
            gesture.setTranslation(.zero, in: self)
            self.delegate?.videoRangeSlider?(self, lowerValue: self.lowerValue, upperValue: self.upperValue)
        }else if gesture.state == .ended{
            self.delegate?.videoRangeSlider?(self, lowerValue: self.lowerValue, upperValue: self.upperValue)
        }
    }


    private func videoNextQuality(_ quality : KYVideoTrimQuality) -> KYVideoTrimQuality{
        var qualityValue = quality.rawValue
        qualityValue -= 1
        let nextQuality = KYVideoTrimQuality(rawValue: qualityValue)

        if let value = nextQuality {
            return value
        }
        return KYVideoTrimQuality.highest

    }

    private func findVideoQuality(_ exportPresets : [String],quality : KYVideoTrimQuality) ->KYVideoTrimQuality?{

        if exportPresets.contains(quality.description){
            return quality
        }
        var nextQuality = self.videoNextQuality(quality)
        var qualityArray : [KYVideoTrimQuality] = []
        while nextQuality != quality {
            qualityArray.append(nextQuality)
            nextQuality = self.videoNextQuality(nextQuality)
        }

        for quality in qualityArray {
            if exportPresets.contains(quality.description){
                return quality
            }
        }
        return nil

    }


    public func trimVideo(_ complete : @escaping KYVideoTrimCompleteHandler){

        if let _ = self.videoAsset {

        }else{
            complete(.unknown, self.trimVideoPath)
        }

        self.deleteTrimVideoFile()

        let compatiblePresets = AVAssetExportSession.exportPresets(compatibleWith: self.videoAsset!)

        let videoQuality = self.findVideoQuality(compatiblePresets, quality: trimQuality)

        if let _ = videoQuality {

        }else{
            complete(.unknown, self.trimVideoPath)
        }

        self.trimExportSession = AVAssetExportSession(asset: self.videoAsset!, presetName: videoQuality!.description)
        let trimVideoURL = NSURL(fileURLWithPath: self.trimVideoPath) as URL
        self.trimExportSession.outputURL = trimVideoURL
        self.trimExportSession.outputFileType = AVFileType.mp4

        let starCMTime = CMTimeMakeWithSeconds(self.lowerValue, self.videoAsset!.duration.timescale)
        let durationCMTime = CMTimeMakeWithSeconds(self.upperValue-self.lowerValue, self.videoAsset!.duration.timescale);
        let rangeCMTime = CMTimeRangeMake(starCMTime, durationCMTime);

        self.trimExportSession.timeRange = rangeCMTime

        self.trimExportSession.exportAsynchronously {
            DispatchQueue.main.async {
                var test:KYVideoRangeSlider? = self
                if let strongSelf = test {
                    let value = strongSelf.trimExportSession.status.rawValue
                    if let exportSessionStatus = KYAssetExportSessionStatus(rawValue: value){
                        complete(exportSessionStatus,strongSelf.trimVideoPath)
                    }else{
                        complete(KYAssetExportSessionStatus.unknown,strongSelf.trimVideoPath)
                    }
                }
                complete(KYAssetExportSessionStatus.unknown,"")
            }
        }
    
    }


}



extension KYVideoRangeSlider :  UICollectionViewDataSource,UICollectionViewDelegate,UICollectionViewDelegateFlowLayout {

    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return self.videoKeyframes.count
    }

    public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "rangecell", for: indexPath) as! KYVideoRangeCollectionCell
        cell.keyframe = self.videoKeyframes[indexPath.row]
        return cell
    }

    public func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: self.keyframeWidth, height: self.frame.height-2)
    }


    public func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
    }

    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        //_asset is nil or videoPlayer not readyForDisplay
        guard  let _ = videoAsset else {
            return
        }

        let videoTrackLength = self.keyframeWidth * CGFloat(self.videoKeyframes.count)
        //current position
        var position = scrollView.contentOffset.x
        position = max(position, 0)
        position = min(position,videoTrackLength)
        let percent = position / CGFloat(videoTrackLength)

        var currentSecond = self.duration * Float64(percent)
        currentSecond = max(currentSecond, 0)
        currentSecond = min(currentSecond, self.duration)
        self.rangeStartTime = currentSecond

        let selecteTime = Float64(self.selecteTimeLength/CGFloat(videoTrackLength))*self.duration

        self.rangeEndTime = self.rangeStartTime+selecteTime

        self.delegate?.videoRangeSlider?(self, lowerValue: self.lowerValue, upperValue: self.upperValue)
    }
    public func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        self.delegate?.videoRangeSliderBeginDragging?(self)
    }
    public func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {

    }


}



internal class KYVideoRangeCollectionCell : UICollectionViewCell{

    internal var imageView: UIImageView!
    internal var keyframe: KYVideoKeyframe?{
        didSet{
            self.imageView.image = keyframe?.image
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.imageView = UIImageView(frame: .zero)
        self.imageView.translatesAutoresizingMaskIntoConstraints = false
        self.contentView.addSubview(self.imageView)

        var constraints : [NSLayoutConstraint] = []

        let views = ["imageView":self.imageView] as [String:Any]

        constraints += NSLayoutConstraint.constraints(withVisualFormat: "V:|[imageView]|", options: NSLayoutFormatOptions(), metrics: nil, views: views)
        constraints += NSLayoutConstraint.constraints(withVisualFormat: "H:|[imageView]|", options: NSLayoutFormatOptions(), metrics: nil, views: views)
        self.contentView.addConstraints(constraints)

    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
