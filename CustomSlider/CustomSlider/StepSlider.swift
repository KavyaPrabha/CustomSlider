//
//  StepSlider.swift
//  CustomSlider
//
//  Created by Kavya Prabha S on 10/02/23.
//
import UIKit

//  Interface builder hides the IBInspectable for UIControl
#if TARGET_INTERFACE_BUILDER
public class TGPSlider_INTERFACE_BUILDER:UIView {
}
#else // !TARGET_INTERFACE_BUILDER
public class TGPSlider_INTERFACE_BUILDER:UIControl {
}
#endif // TARGET_INTERFACE_BUILDER

@IBDesignable
public class StepSlider: TGPSlider_INTERFACE_BUILDER {

    @IBInspectable public var markerSize:CGSize = CGSize(width:4, height:4) {
        didSet {
            markerSize.width = max(0, markerSize.width)
            markerSize.height = max(0, markerSize.height)
            layoutTrack()
        }
    }

    @IBInspectable public var markerColor:UIColor? = nil {
        didSet {
            layoutTrack()
        }
    }

    @IBInspectable public var trackThickness:CGFloat = 8 {
        didSet {
            trackThickness = max(0, trackThickness)
            layoutTrack()
        }
    }

    @IBInspectable public var minimumTrackTintColor:UIColor? = nil {
        didSet {
            layoutTrack()
        }
    }

    @IBInspectable public var maximumTrackTintColor = UIColor(white: 0.71, alpha: 1) {
        didSet {
            layoutTrack()
        }
    }

    @IBInspectable public var thumbSize:CGSize = CGSize(width:30, height:30) {
        didSet {
            thumbSize.width = max(1, thumbSize.width)
            thumbSize.height = max(1, thumbSize.height)
            layoutTrack()
        }
    }

    @IBInspectable public var thumbTintColor:UIColor? = nil {
        didSet {
            layoutTrack()
        }
    }

    @IBInspectable public var thumbShadowRadius:CGFloat = 0 {
        didSet {
            layoutTrack()
        }
    }

    @IBInspectable public var thumbShadowOffset:CGSize = CGSize.zero {
        didSet {
            layoutTrack()
        }
    }

    @IBInspectable public var incrementValue:Int = 1 {
        didSet {
            if(0 == incrementValue) {
                incrementValue = 1;  // nonZeroIncrement
            }
            layoutTrack()
        }
    }

    // MARK: UISlider substitution
    // AKA: UISlider value (as CGFloat for compatibility with UISlider API, but expected to contain integers)
    
    @IBInspectable public var maximumValue:CGFloat {
        get {
            return CGFloat(intMaximumValue)
        }
        set {
            intMaximumValue = Int(newValue)
            layoutTrack()
        }
    }

    @IBInspectable public var minimumValue:CGFloat {
        get {
            return CGFloat(intMinimumValue)
        }
        set {
            intMinimumValue = Int(newValue)
            layoutTrack()
        }
    }

    @IBInspectable public var value:CGFloat {
        get {
            return CGFloat(intValue)
        }
        set {
            intValue = Int(newValue)
            layoutTrack()
        }
    }

    // MARK: Properties
    public override var tintColor: UIColor! {
        didSet {
            layoutTrack()
        }
    }

    public override var bounds: CGRect {
        didSet {
            layoutTrack()
        }
    }
    
    public var tickCount: Int {
        get {
            return Int(maximumValue)/Int(incrementValue)
        }
    }

    public var ticksDistance:CGFloat {
        get {
            assert(tickCount > 1, "2 ticks minimum \(tickCount)")
            let segments = CGFloat(max(1, tickCount - 1))
            return trackRectangle.width / segments
        }
    }
    
    public var markerLabels: [String]! {
        get {
            return labels
        }
        set {
            self.labels = newValue
        }
    }

    var intValue:Int = 0
    var intMinimumValue = -5
    var intMaximumValue = 240
    
    var labels = ["5 min","60","120","180","240"]

    var ticksAbscissae:[CGPoint] = []
    var markerAbscissae:[CGPoint] = []
    var thumbAbscissa:CGFloat = 0
    var thumbLayer = CALayer()

    var trackLayer = CALayer()
    var leftTrackLayer = CALayer()
    var rightTrackLayer = CALayer()
    var leadingTrackLayer: CALayer!
    var trailingTrackLayer: CALayer!

    var ticksLayer = CALayer()
    var leftTicksLayer = CALayer()
    var rightTicksLayer = CALayer()
    var leadingTicksLayer: CALayer!
    var trailingTicksLayer: CALayer!

    var trackRectangle = CGRect.zero
    var touchedInside = false
    var localeCharacterDirection = CFLocaleLanguageDirection.leftToRight

    var delegate: UpdateSliderProtocol!

    // MARK: UIControl

    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        initProperties()
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        initProperties()
    }

    public override func draw(_ rect: CGRect) {
        drawTrack()
        drawMarkers()
        drawThumb()
        drawMarkerLabels()
    }

    // MARK: StepSlider

    func initProperties() {
        if let systemLocale = CFLocaleCopyCurrent(),
            let localeIdentifier = CFLocaleGetIdentifier(systemLocale) {
            localeCharacterDirection = CFLocaleGetLanguageCharacterDirection(localeIdentifier.rawValue)
        }

        leadingTrackLayer = (.rightToLeft == localeCharacterDirection)
            ? rightTrackLayer
            : leftTrackLayer
        trailingTrackLayer = (.rightToLeft == localeCharacterDirection)
            ? leftTrackLayer
            : rightTrackLayer
        leadingTicksLayer = (.rightToLeft == localeCharacterDirection)
            ? rightTicksLayer
            : leftTicksLayer
        trailingTicksLayer = (.rightToLeft == localeCharacterDirection)
            ? leftTicksLayer
            : rightTicksLayer

        // Track and ticks are in a clear clipping layer, and left + right sublayers,
        // which brings in free animation
        trackLayer.masksToBounds = true
        trackLayer.backgroundColor = UIColor.clear.cgColor
        layer.addSublayer(trackLayer)
        trackLayer.addSublayer(leftTrackLayer)
        trackLayer.addSublayer(rightTrackLayer)

        // Ticks in between track and thumb
        ticksLayer.masksToBounds = true
        ticksLayer.backgroundColor = UIColor.clear.cgColor
        layer.addSublayer(ticksLayer)
        ticksLayer.addSublayer(rightTicksLayer) // reverse order, left covers right
        ticksLayer.addSublayer(leftTicksLayer)

        // The thumb is its own CALayer, which brings in free animation
        layer.addSublayer(thumbLayer)

        isMultipleTouchEnabled = false
        layoutTrack()
    }

    func drawTicks() {
        ticksLayer.frame = bounds
        let path = UIBezierPath()
        for originPoint in ticksAbscissae {
            let rectangle = CGRect(x: originPoint.x-(markerSize.width/2),
                                   y: originPoint.y-(markerSize.height/2),
                                   width: markerSize.width,
                                   height: markerSize.height)
            path.append(UIBezierPath(roundedRect: rectangle,
                                     cornerRadius: rectangle.height/2))

        }
        leftTicksLayer.frame = {
            var frame = ticksLayer.bounds
            let tickWidth = (.rightToLeft == localeCharacterDirection)
            ? -markerSize.width/2
            : markerSize.width/2
            frame.size.width = tickWidth + thumbAbscissa
            
            return frame
        }()
        
        leftTicksLayer.mask = {
            let maskLayer = CAShapeLayer()
            maskLayer.frame = ticksLayer.bounds
            maskLayer.path = path.cgPath
            return maskLayer
        }()
        
        rightTicksLayer.frame = ticksLayer.bounds
        
        rightTicksLayer.mask = {
            let maskLayer = CAShapeLayer()
            maskLayer.path = path.cgPath
            return maskLayer
        }()
        
        leadingTicksLayer.backgroundColor = UIColor.white.cgColor
        trailingTicksLayer.backgroundColor = UIColor.white.cgColor
    }
    
    func drawMarkerLabels() {
        for subview in self.subviews {
            subview.removeFromSuperview()
        }
        for i in 0..<markerLabels.count {
            let originPoint = markerAbscissae[i]
            let markerLabel = UILabel.init(frame: CGRect(x: 0, y: 0, width: 20, height: 20))
            markerLabel.text = labels[i]
            markerLabel.font = UIFont.systemFont(ofSize: 13)
            markerLabel.textColor = .gray
            markerLabel.center = CGPoint(x: originPoint.x, y: originPoint.y + 30)
            markerLabel.sizeToFit()
            addSubview(markerLabel)
        }
    }

    
    func drawMarkers() {
        ticksLayer.frame = bounds
        let path = UIBezierPath()
        for originPoint in markerAbscissae {
            let rectangle = CGRect(x: originPoint.x-(markerSize.width/2),
                                   y: originPoint.y-(markerSize.height/2),
                                   width: markerSize.width,
                                   height: markerSize.height)
            path.append(UIBezierPath(roundedRect: rectangle,
                                     cornerRadius: rectangle.height/2))
        }
        leftTicksLayer.frame = {
            var frame = ticksLayer.bounds
            let tickWidth = (.rightToLeft == localeCharacterDirection)
            ? -markerSize.width/2
            : markerSize.width/2
            frame.size.width = tickWidth + thumbAbscissa
            
            return frame
        }()
        
        leftTicksLayer.mask = {
            let maskLayer = CAShapeLayer()
            maskLayer.frame = ticksLayer.bounds
            maskLayer.path = path.cgPath
            return maskLayer
        }()
        
        rightTicksLayer.frame = ticksLayer.bounds
        rightTicksLayer.mask = {
            let maskLayer = CAShapeLayer()
            maskLayer.path = path.cgPath
            return maskLayer
        }()
        
        if let backgroundColor = markerColor?.cgColor ?? (minimumTrackTintColor?.cgColor) {
            leadingTicksLayer.backgroundColor = backgroundColor
        }
        trailingTicksLayer.backgroundColor = markerColor?.cgColor ?? maximumTrackTintColor.cgColor
    }

    func drawTrack() {
        trackLayer.frame = trackRectangle
        trackLayer.cornerRadius = trackRectangle.height/2
        leftTrackLayer.frame = {
            var frame = trackLayer.bounds
            frame.size.width = thumbAbscissa - trackRectangle.minX
            return frame
        }()
        rightTrackLayer.frame = {
            var frame = trackLayer.bounds
            frame.size.width = trackRectangle.width - leftTrackLayer.frame.width
            frame.origin.x = leftTrackLayer.frame.maxX
            return frame
        }()
        if let backgroundColor = minimumTrackTintColor ?? tintColor {
            leadingTrackLayer.backgroundColor = backgroundColor.cgColor
        }
        trailingTrackLayer.backgroundColor = maximumTrackTintColor.cgColor
    }

    func drawThumb() {
        if( value >= minimumValue) {  // Feature: hide the thumb when below range

            let thumbSizeForStyle = thumbSizeIncludingShadow()
            let thumbWidth = thumbSizeForStyle.width
            let thumbHeight = thumbSizeForStyle.height
            let rectangle = CGRect(x:thumbAbscissa - (thumbWidth / 2),
                                   y: (frame.height - thumbHeight)/2,
                                   width: thumbWidth,
                                   height: thumbHeight)

            let shadowRadius = thumbShadowRadius
            let shadowOffset = thumbShadowOffset

            thumbLayer.frame = ((shadowRadius != 0.0)  // Ignore offset if there is no shadow
                ? rectangle.insetBy(dx: shadowRadius + shadowOffset.width,
                                    dy: shadowRadius + shadowOffset.height)
                : rectangle.insetBy(dx: shadowRadius,
                                    dy: shadowRadius))

            
                // A rounded thumb is circular
                thumbLayer.backgroundColor = (thumbTintColor ?? UIColor.lightGray).cgColor
                thumbLayer.borderColor = UIColor.clear.cgColor
                thumbLayer.borderWidth = 0.0
                thumbLayer.cornerRadius = thumbLayer.frame.width/2
                thumbLayer.allowsEdgeAntialiasing = true


            // Shadow
            if(shadowRadius != 0.0) {
                #if TARGET_INTERFACE_BUILDER
                thumbLayer.shadowOffset = CGSize(width: shadowOffset.width,
                                                 height: -shadowOffset.height)
                #else // !TARGET_INTERFACE_BUILDER
                thumbLayer.shadowOffset = shadowOffset
                #endif // TARGET_INTERFACE_BUILDER

                thumbLayer.shadowRadius = shadowRadius
                thumbLayer.shadowColor = UIColor.black.cgColor
                thumbLayer.shadowOpacity = 0.15
            } else {
                thumbLayer.shadowRadius = 0.0
                thumbLayer.shadowOffset = CGSize.zero
                thumbLayer.shadowColor = UIColor.clear.cgColor
                thumbLayer.shadowOpacity = 0.0
            }
        }
    }

    func layoutTrack() {
        self.backgroundColor = .clear
        assert(tickCount > 1, "2 ticks minimum \(tickCount)")
        let segments = max(1, tickCount - 1)
        _ = thumbSizeIncludingShadow().width

        // Calculate the track ticks positions
        let trackHeight = trackThickness
        let trackSize = CGSize(width: frame.width,
                               height: trackHeight)
        trackRectangle = CGRect(x: (frame.width - trackSize.width)/2,
                                y: (frame.height - trackSize.height)/2,
                                width: trackSize.width,
                                height: trackSize.height)
        let trackY = frame.height / 2
        ticksAbscissae = []
        for iterate in 0 ... segments {
            let ratio = Double(iterate) / Double(segments)
            let originX = trackRectangle.origin.x + (CGFloat)(trackSize.width * CGFloat(ratio))
            if iterate == 0 {
                ticksAbscissae.append(CGPoint(x: originX + 5, y: trackY))
            } else if iterate == segments {
                ticksAbscissae.append(CGPoint(x: originX - 5, y: trackY))
            } else {
                ticksAbscissae.append(CGPoint(x: originX, y: trackY))
            }
        }
        layoutMarkers(trackRectangle: trackRectangle, trackSize: trackSize)
        layoutThumb()
        setNeedsDisplay()
    }
    
    func layoutMarkers(trackRectangle: CGRect, trackSize: CGSize) {
        let segments = max(1, 4)
        _ = thumbSizeIncludingShadow().width
        markerAbscissae = []
        let trackY = frame.height / 2
        for iterate in 0 ... segments {
            let ratio = Double(iterate) / Double(segments)
            let originX = trackRectangle.origin.x + (CGFloat)(trackSize.width * CGFloat(ratio))
            if iterate == 0 {
                markerAbscissae.append(CGPoint(x: originX + 5, y: trackY))
            } else if iterate == segments {
                markerAbscissae.append(CGPoint(x: originX - 5, y: trackY))
            } else {
                markerAbscissae.append(CGPoint(x: originX, y: trackY))
            }
        }
    }

    func layoutThumb() {
        assert(tickCount > 1, "2 ticks minimum \(tickCount)")
        let segments = max(1, tickCount - 1)

        // Calculate the thumb position
        let nonZeroIncrement = ((0 == incrementValue) ? 1 : incrementValue)
        var thumbRatio = Double(value - minimumValue) / Double(segments * nonZeroIncrement)
        thumbRatio = max(0.0, min(thumbRatio, 1.0)) // Normalized
        thumbRatio = (.rightToLeft == localeCharacterDirection)
            ? 1.0 - thumbRatio
            : thumbRatio
        thumbAbscissa = trackRectangle.origin.x + (CGFloat)(trackRectangle.width * CGFloat(thumbRatio))
    }

    func thumbSizeIncludingShadow() -> CGSize {
            return ((thumbShadowRadius != 0.0)
                ? CGSize(width:thumbSize.width
                    + (thumbShadowRadius * 2)
                    + (thumbShadowOffset.width * 2),
                         height: thumbSize.height
                            + (thumbShadowRadius * 2)
                            + (thumbShadowOffset.height * 2))
                : thumbSize)
    }

    // MARK: UIResponder
    public override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchedInside = true

        touchDown(touches, animationDuration: 0.1)
        sendActionForControlEvent(controlEvent: .valueChanged, with: event)
        sendActionForControlEvent(controlEvent: .touchDown, with:event)

        if let touch = touches.first {
            if touch.tapCount > 1 {
                sendActionForControlEvent(controlEvent: .touchDownRepeat, with: event)
            }
        }
    }

    public override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchDown(touches, animationDuration:0)

        let inside = touchesAreInside(touches)
        sendActionForControlEvent(controlEvent: .valueChanged, with: event)

        if inside != touchedInside { // Crossing boundary
            sendActionForControlEvent(controlEvent: (inside) ? .touchDragEnter : .touchDragExit,
                                      with: event)
            touchedInside = inside
        }
        // Drag
        sendActionForControlEvent(controlEvent: (inside) ? .touchDragInside : .touchDragOutside,
                                  with: event)
    }

    public override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchUp(touches)

        sendActionForControlEvent(controlEvent: .valueChanged, with: event)
        sendActionForControlEvent(controlEvent: (touchesAreInside(touches)) ? .touchUpInside : .touchUpOutside,
                                  with: event)
    }

    public override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchUp(touches)

        sendActionForControlEvent(controlEvent: .valueChanged, with:event)
        sendActionForControlEvent(controlEvent: .touchCancel, with:event)
    }


    // MARK: Touches

    func touchDown(_ touches: Set<UITouch>, animationDuration duration:TimeInterval) {
        if let touch = touches.first {
            let location = touch.location(in: touch.view)
            moveThumbTo(abscissa: location.x, animationDuration: duration)
            delegate.updateSliderValue(value: self.intValue)
            hapticFeedback()
        }
    }

    func touchUp(_ touches: Set<UITouch>) {
        if let touch = touches.first {
            let location = touch.location(in: touch.view)
            let tick = pickTickFromSliderPosition(abscissa: location.x)
            moveThumbToTick(tick: tick)
        }
    }

    func touchesAreInside(_ touches: Set<UITouch>) -> Bool {
        var inside = false
        if let touch = touches.first {
            let location = touch.location(in: touch.view)
            if let bounds = touch.view?.bounds {
                inside = bounds.contains(location)
            }
        }
        return inside
    }

    // MARK: Notifications

    func moveThumbToTick(tick: UInt) {
        let nonZeroIncrement = ((0 == incrementValue) ? 1 : incrementValue)
        let intValue = Int(minimumValue) + (Int(tick) * nonZeroIncrement)
        if intValue != self.intValue {
            self.intValue = intValue
        }
        delegate.updateSliderValue(value: self.intValue)
        layoutThumb()
        setNeedsDisplay()
    }

    func moveThumbTo(abscissa:CGFloat, animationDuration duration:TimeInterval) {
        let leftMost = trackRectangle.minX
        let rightMost = trackRectangle.maxX

        thumbAbscissa = max(leftMost, min(abscissa, rightMost))
        CATransaction.setAnimationDuration(duration)

        let tick = pickTickFromSliderPosition(abscissa: thumbAbscissa)
        let nonZeroIncrement = ((0 == incrementValue) ? 1 : incrementValue)
        let intValue = Int(minimumValue) + (Int(tick) * nonZeroIncrement)
        if intValue != self.intValue {
            self.intValue = intValue
        }

        setNeedsDisplay()
    }
    
    func pinThumbToValue(value: Int) {
        CATransaction.setAnimationDuration(0.1)
        self.intValue = value
        layoutThumb()
        setNeedsDisplay()
    }

    func pickTickFromSliderPosition(abscissa: CGFloat) -> UInt {
        let leftMost = trackRectangle.minX
        let rightMost = trackRectangle.maxX
        let clampedAbscissa = max(leftMost, min(abscissa, rightMost))
        var ratio = Double(clampedAbscissa - leftMost) / Double(rightMost - leftMost)
        ratio = (.rightToLeft == localeCharacterDirection)
            ? 1.0 - ratio
            : ratio
        let segments = max(1, tickCount - 1)
        return UInt(round( Double(segments) * ratio))
    }
    
    func hapticFeedback() {
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
    }

    func sendActionForControlEvent(controlEvent:UIControl.Event, with event:UIEvent?) {
        for target in allTargets {
            if let caActions = actions(forTarget: target, forControlEvent: controlEvent) {
                for actionName in caActions {
                    sendAction(NSSelectorFromString(actionName), to: target, for: event)
                }
            }
        }
    }

    #if TARGET_INTERFACE_BUILDER
    // MARK: TARGET_INTERFACE_BUILDER stub
    //       Interface builder hides the IBInspectable for UIControl

    let allTargets: Set<AnyHashable> = Set()
    func addTarget(_ target: Any?, action: Selector, for controlEvents: UIControl.Event) {}
    func actions(forTarget target: Any?, forControlEvent controlEvent: UIControl.Event) -> [String]? { return nil }
    func sendAction(_ action: Selector, to target: Any?, for event: UIEvent?) {}
    #endif // TARGET_INTERFACE_BUILDER
}

extension StepSlider: UpdateTextFieldValue {
    func setSliderValue(to value: Int) {
        pinThumbToValue(value: value)
    }
}



