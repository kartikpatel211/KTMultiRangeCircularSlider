//
//  KTMultiRangeCircularSlider.swift
//  KTMultiRangeCircularSlider
//
//  Created by Kartik Patel on 6/5/17.
//  Copyright © 2017 KTPatel. All rights reserved.
//

import UIKit
import QuartzCore
import Foundation

extension Array where Element: AnyObject {
    mutating func remove(object: Element) {
        if let index = index(where: { $0 === object }) {
            remove(at: index)
        }
    }
}

extension CircularTrig {
    /**
     *  Macro for converting radian degrees from 'compass style' reference (0 radians is along Y axis (ie North on a compass))
     *   to cartesian reference (0 radians is along X axis).
     *
     *  @param rad Radian degrees to convert from 'Compass' reference
     *
     *  @return Radian Degrees in Cartesian reference
     */
    fileprivate class func toRad(_ degrees: Double) -> Double {
        return ((.pi * degrees) / 180.0)
    }
    
    fileprivate class func toDeg(_ radians: Double) -> Double {
        return ((180.0 * radians) / .pi)
    }
    
    fileprivate class func square(_ value: Double) -> Double {
        return value * value
    }
    
    /**
     *  Macro for converting radian degrees from cartesian reference (0 radians is along X axis)
     *   to 'compass style' reference (0 radians is along Y axis (ie North on a compass)).
     *
     *  @param rad Radian degrees to convert from Cartesian reference
     *
     *  @return Radian Degrees in 'Compass' reference
     */
    fileprivate class func cartesianToCompass(_ radians: Double) -> Double {
        return radians + (.pi/2)
    }
    
    fileprivate class func compassToCartesian(_ radians: Double) -> Double {
        return radians - (.pi/2)
    }
    
    open class func drawfilledGradientArcInContext(_ ctx: CGContext, center: CGPoint, radius: CGFloat, lineWidth: CGFloat, fromAngleFromNorth: CGFloat, toAngleFromNorth: CGFloat, colors: [UIColor], lineCap: CGLineCap) {
        // ensure two colors exist to create a gradient between
        guard colors.count == 2 else {
            return
        }
        
        let cartesianFromAngle = compassToCartesian(toRad(Double(fromAngleFromNorth)))
        let cartesianToAngle = compassToCartesian(toRad(Double(toAngleFromNorth)))
        
        ctx.saveGState()
        
        let path = UIBezierPath(arcCenter: center, radius: radius, startAngle: CGFloat(cartesianFromAngle), endAngle: CGFloat(cartesianToAngle), clockwise: true)
        let containerPath = CGPath(__byStroking: path.cgPath, transform: nil, lineWidth: CGFloat(lineWidth), lineCap: lineCap, lineJoin: CGLineJoin.round, miterLimit: lineWidth)
        ctx.addPath(containerPath!)
        ctx.clip()
        
        let baseSpace = CGColorSpaceCreateDeviceRGB()
        let gradient = CGGradient(colorsSpace: baseSpace, colors: [colors[1].cgColor, colors[0].cgColor] as CFArray, locations: nil)
        
        let startPoint = CGPoint(x: center.x - radius, y: center.y + radius)
        let endPoint = CGPoint(x: center.x + radius, y: center.y - radius)
        
        ctx.drawLinearGradient(gradient!, start: startPoint, end: endPoint, options: .drawsBeforeStartLocation)
        
        ctx.restoreGState()
    }
}

protocol KTRangeCircularHandleDelegate {
    func setCurrentValue(handle: KTRangeCircularHandle, currentValue: Float);
    func setUpperCurrentValue();
}

class KTRangeCircularHandle : NSObject {
    
    
    let firstCircularSliderHandle = CircularSliderHandle()
    let secondCircularSliderHandle = CircularSliderHandle()
    
    var firstImgView : UIImageView?
    var secondImgView : UIImageView?
    
    var firstHandleCenter : CGPoint = CGPoint.init(x: 0, y: 0)
    var secondHandleCenter : CGPoint = CGPoint.init(x: 0, y: 0)
    
    var delegate : KTRangeCircularHandleDelegate?
    
    // MARK: Values
    // Value at North/midnight (start)
    var minimumValue: Float = 0.0
    
    // Value at North/midnight (end)
    var maximumValue: Float = 100.0
    
    // value for end of arc. This allows for incomplete circles to be created
    var maximumAngle: CGFloat = 360.0
    
    // Current value between North/midnight (start) and North/midnight (end) - clockwise direction
    var currentValue: Float {
        set {
            delegate?.setCurrentValue(handle: self, currentValue: newValue)
            
        } get {
            return (Float(angleFromNorth) * (maximumValue - minimumValue)) / Float(maximumAngle)
        }
    }
    
    // the current value of the upper handle of the slider
    var upperCurrentValue: Float {
        set {
            assert(newValue <= maximumValue && newValue >= minimumValue, "current value \(newValue) must be between minimumValue \(minimumValue) and maximumValue \(maximumValue)")
            // Update the upperAngleFromNorth to match this newly set value
            self.upperAngleFromNorth = Int((newValue * Float(maximumAngle)) / (maximumValue - minimumValue))
            delegate?.setUpperCurrentValue()
        } get {
            return (Float(self.upperAngleFromNorth) * (maximumValue - minimumValue)) / Float(maximumAngle)
        }
    }
    
    var angleFromNorth: Int = 0 {
        didSet {
            assert(angleFromNorth >= 0, "angleFromNorth \(angleFromNorth) must be greater than 0")
        }
    }
    
    fileprivate var upperAngleFromNorth: Int = 30 {
        didSet {
            assert(upperAngleFromNorth >= 0, "upperAngleFromNorth \(upperAngleFromNorth) must be greater than 0")
        }
    }
}


protocol KTMultiRangeCircularSliderDelegate {
    func rangeUpdated(startValue: Float, endValue: Float, handle: KTRangeCircularHandle)
    func percentageAtTouchByUser(percentage: Double)
}


class KTMultiRangeCircularSlider: UIControl, KTRangeCircularHandleDelegate {

    var delegate : KTMultiRangeCircularSliderDelegate?
    
    let orangeColorData = UIColor(red: 255.0/255.0, green: 0.0/255.0, blue: 0.0/255.0, alpha: 1.0)
    let yellowColorData = UIColor(red: 255.0/255.0, green: 255.0/255.0, blue: 0.0/255.0, alpha: 1.0)
    
    // MARK: Handle
    var arrHandle = [KTRangeCircularHandle]()
    
    var rotationAnimation : CABasicAnimation?
    
    // MARK: Values
    // Value at North/midnight (start)
    var minimumValue: Float = 0.0 {
        didSet {
            arrHandle.forEach({$0.minimumValue = minimumValue})
            setNeedsDisplay()
        }
    }
    
    // Value at North/midnight (end)
    var maximumValue: Float = 100.0 {
        didSet {
            arrHandle.forEach({$0.maximumValue = maximumValue})
            setNeedsDisplay()
        }
    }
    
    // value for end of arc. This allows for incomplete circles to be created
    var maximumAngle: CGFloat = 360.0 {
        didSet {
            arrHandle.forEach({$0.maximumAngle = maximumAngle})
            if maximumAngle > 360.0 {
                print("Warning: Maximum angle should be 360 or less.")
                maximumAngle = 360.0
            }
            setNeedsDisplay()
        }
    }
    
    func setCurrentValue(handle: KTRangeCircularHandle, currentValue: Float) {
        assert(currentValue <= maximumValue && currentValue >= minimumValue, "current value \(currentValue) must be between minimumValue \(minimumValue) and maximumValue \(maximumValue)")
        // Update the angleFromNorth to match this newly set value
        handle.angleFromNorth = Int((currentValue * Float(maximumAngle)) / (maximumValue - minimumValue))
        moveHandle(CGFloat(handle.angleFromNorth), handle: handle)
        
        sendActions(for: UIControl.Event.valueChanged)
    }
    
    func setUpperCurrentValue() {
        sendActions(for: UIControl.Event.valueChanged)
    }
    
    /**
     *  Note: If this property is not set, filledColor will be used.
     *        If handleType is semiTransparent*, specified color will override this property.
     *
     *  Color of the handle
     */
    var handleColor: UIColor? {
        didSet {
            setNeedsDisplay()
        }
    }
    
    // Type of the handle to display to represent draggable current value
    var handleType: CircularSliderHandleType = .semiTransparentWhiteSmallCircle {
        didSet {
            setNeedsUpdateConstraints()
            setNeedsDisplay()
        }
    }
    
    // the minimum distance, in degrees, allowed between handles
    var minimumHandleDistance: CGFloat = 10
    
    
    // MARK: Labels
    // BOOL indicating whether values snap to nearest label
    var snapToLabels: Bool = false
    
    /**
     *  Note: The LAST label will appear at North/midnight
     *        The FIRST label will appear at the first interval after North/midnight
     *
     *  NSArray of strings used to render labels at regular intervals within the circle
     */
    var innerMarkingLabels: [String]? {
        didSet {
            setNeedsUpdateConstraints()
            setNeedsDisplay()
        }
    }
    
    
    // MARK: Visual Customisation
    // property Width of the line to draw for slider
    var lineWidth: Int = 5 {
        didSet {
            setNeedsUpdateConstraints() // This could affect intrinsic content size
            invalidateIntrinsicContentSize() // Need to update intrinsice content size
            setNeedsDisplay() // Need to redraw with new line width
        }
    }
    
    // Color of filled portion of line (from North/midnight start to currentValue)
    var filledColor: UIColor = .red {
        didSet {
            setNeedsDisplay()
        }
    }
    
    // Color of unfilled portion of line (from currentValue to North/midnight end)
    var unfilledColor: UIColor = UIColor.init(white: 230.0/255.0, alpha: 1.0) {
        didSet {
            setNeedsDisplay()
        }
    }
    
    // Font of the inner marking labels within the circle
    var labelFont: UIFont = .systemFont(ofSize: 15.0) {
        didSet {
            setNeedsDisplay()
        }
    }
    
    // Color of the inner marking labels within the circle
    var labelColor: UIColor = .darkGray {
        didSet {
            setNeedsDisplay()
        }
    }
    
    /**
     *  Note: A negative value will move the label closer to the center. A positive value will move the label closer to the circumference
     *  Value with which to displace all labels along radial line from center to slider circumference.
     */
    var labelDisplacement: CGFloat = 0
    
    // type of LineCap to use for the unfilled arc
    // NOTE: user CGLineCap.Butt for full circles
    var unfilledArcLineCap: CGLineCap = .butt
    
    // type of CGLineCap to use for the arc that is filled in as the handle moves
    var filledArcLineCap: CGLineCap = .butt
    
    // MARK: Computed Public Properties
    var computedRadius: CGFloat {
        if (radius == -1.0) {
            // Slider is being used in frames - calculate the max radius based on the frame
            //  (constrained by smallest dimension so it fits within view)
            let minimumDimension = min(bounds.size.height, bounds.size.width)
            let halfLineWidth = ceilf(Float(lineWidth) / 2.0)
            let halfHandleWidth = ceilf(Float(handleWidth) / 2.0)
            return minimumDimension * 0.5 - CGFloat(max(halfHandleWidth, halfLineWidth))
        }
        return radius
    }
    
    var centerPoint: CGPoint {
        return CGPoint(x: bounds.size.width * 0.5, y: bounds.size.height * 0.5)
    }
    
    
    var handleWidth: CGFloat {
        switch handleType {
        case .semiTransparentWhiteSmallCircle:
            return CGFloat(lineWidth) //CGFloat(lineWidth / 2)
        case .semiTransparentWhiteCircle, .semiTransparentBlackCircle:
            return CGFloat(lineWidth)
        case .bigCircle:
            return CGFloat(lineWidth + 5) // 5 points bigger than standard handles
        }
    }
    
    // MARK: Private Variables
    fileprivate var radius: CGFloat = -1.0 {
        didSet {
            setNeedsUpdateConstraints()
            setNeedsDisplay()
        }
    }
    
    fileprivate var computedHandleColor: UIColor? {
        var newHandleColor = handleColor
        
        switch (handleType) {
        case .semiTransparentWhiteSmallCircle, .semiTransparentWhiteCircle:
            newHandleColor = UIColor(white: 250.0/255.0, alpha: 1.0) //UIColor(white: 1.0, alpha: 0.5)
        case .semiTransparentBlackCircle:
            newHandleColor = UIColor(white: 0.0, alpha: 0.7)
        case .bigCircle:
            newHandleColor = filledColor
        }
        
        return newHandleColor
    }
    
    fileprivate var innerLabelRadialDistanceFromCircumference: CGFloat {
        // Labels should be moved far enough to clear the line itself plus a fixed offset (relative to radius).
        var distanceToMoveInwards = 0.1 * -(radius) - 0.5 * CGFloat(lineWidth)
        distanceToMoveInwards -= 0.5 * labelFont.pointSize // Also account for variable font size.
        return distanceToMoveInwards
    }
    
    // MARK: - Initialization
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        backgroundColor = .clear
    }
    
    
    func addHandle(currentValue: Float, upperCurrentValue: Float) -> KTRangeCircularHandle? {
        
        let handle = KTRangeCircularHandle()
        handle.delegate = self
        handle.currentValue = currentValue
        handle.upperCurrentValue = upperCurrentValue
        
        if isCurrentRangeCollideWithOther(currentHandle: handle) == true {
            return nil
        }
        
        arrHandle.append(handle)
        
        return handle
    }
    
    func removeHandle(handle: KTRangeCircularHandle){
        if arrHandle.contains(handle) {
            arrHandle.remove(object: handle)
            handle.firstImgView!.removeFromSuperview()
            handle.secondImgView!.removeFromSuperview()
            
            setNeedsDisplay()
        }
    }
    
    // TODO: initializer for autolayout
    /**
     *  Initialise the class with a desired radius
     *  This initialiser should be used for autolayout - use initWithFrame otherwise
     *  Note: Intrinsic content size will be based on this parameter, lineWidth and handleType
     *
     *  radiusToSet Desired radius of circular slider
     */
    //  convenience init(radiusToSet: CGFloat) {
    //
    //  }
    
    // MARK: - Function Overrides
    override var intrinsicContentSize : CGSize {
        // Total width is: diameter + (2 * MAX(halfLineWidth, halfHandleWidth))
        let diameter = radius * 2
        let halfLineWidth = ceilf(Float(lineWidth) / 2.0)
        let halfHandleWidth = ceilf(Float(handleWidth) / 2.0)
        
        let widthWithHandle = diameter + CGFloat(2 *  max(halfHandleWidth, halfLineWidth))
        
        return CGSize(width: widthWithHandle, height: widthWithHandle)
    }
    
    override func draw(_ rect: CGRect) {
        super.draw(rect)
        
        let ctx = UIGraphicsGetCurrentContext()
        
        unfilledColor.set()
        // Draw an unfilled circle (this shows what can be filled)
        CircularTrig.drawUnfilledCircleInContext(ctx!, center: centerPoint, radius: computedRadius, lineWidth: CGFloat(lineWidth), maximumAngle: maximumAngle, lineCap: unfilledArcLineCap)
        
        for handle in arrHandle {
            
            // Draw the circular lines that slider handle moves along
            drawLine(ctx!, handle: handle)
            
            // Draw the draggable 'handle'
            handle.firstHandleCenter = pointOnCircleAtAngleFromNorth(handle.angleFromNorth)
            handle.firstCircularSliderHandle.frame = drawHandle(ctx!, atPoint: handle.firstHandleCenter)
            
            // added image as handler - kartik
            if handle.firstImgView == nil {
                handle.firstImgView = UIImageView(frame: handle.firstCircularSliderHandle.frame)
                handle.firstImgView?.image = self.imageRotatedByDegrees(oldImage: #imageLiteral(resourceName: "Start_100"), deg: CGFloat(handle.angleFromNorth))
                self.addSubview(handle.firstImgView!)
            } else  {
                handle.firstImgView?.frame = handle.firstCircularSliderHandle.frame
                handle.firstImgView?.image = self.imageRotatedByDegrees(oldImage: #imageLiteral(resourceName: "Start_100"), deg: CGFloat(handle.angleFromNorth))
            }
            
            // Draw the second draggable 'handle'
            handle.secondHandleCenter = pointOnCircleAtAngleFromNorth(handle.upperAngleFromNorth)
            handle.secondCircularSliderHandle.frame = drawHandle(ctx!, atPoint: handle.secondHandleCenter)
            
            // added image as handler - kartik
            if handle.secondImgView == nil {
                handle.secondImgView = UIImageView(frame: handle.secondCircularSliderHandle.frame)
                handle.secondImgView?.image = self.imageRotatedByDegrees(oldImage: #imageLiteral(resourceName: "Stop_100"), deg: CGFloat(handle.upperAngleFromNorth))
                self.addSubview(handle.secondImgView!)
            } else  {
                handle.secondImgView?.frame = handle.secondCircularSliderHandle.frame
                handle.secondImgView?.image = self.imageRotatedByDegrees(oldImage: #imageLiteral(resourceName: "Stop_100"), deg: CGFloat(handle.upperAngleFromNorth))
            }
        }
        
        // Draw inner labels
        drawInnerLabels(ctx!, rect: rect)
    }
    
    
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        guard event != nil else { return false }
        
        for handle in arrHandle {
            if pointInsideHandle(point, withEvent: event!, handle:handle) {
                return true
            }
        }
        
        return pointInsideCircle(point, withEvent: event!)
    }
    
    fileprivate func pointInsideCircle(_ point: CGPoint, withEvent event: UIEvent) -> Bool {
        let p1 = centerPoint
        let p2 = point
        let xDist = p2.x - p1.x
        let yDist = p2.y - p1.y
        let distance = sqrt((xDist * xDist) + (yDist * yDist))
        if distance < computedRadius + CGFloat(lineWidth) * 0.5 {
            
            let lastAngle = floor(CircularTrig.angleRelativeToNorthFromPoint(centerPoint, toPoint: point))
            //print("touch percentage: \(lastAngle)")
            
            let percentage = (Float(lastAngle) * (maximumValue - minimumValue)) / Float(maximumAngle)
            delegate?.percentageAtTouchByUser(percentage: Double(percentage))
            
            print ("touch percentage: \(percentage)")
            
            return true
        } else {
            return false
        }
    }
    
    fileprivate func pointInsideHandle(_ point: CGPoint, withEvent event: UIEvent, handle: KTRangeCircularHandle) -> Bool {
        handle.firstHandleCenter = pointOnCircleAtAngleFromNorth(handle.angleFromNorth)
        // Adhere to apple's design guidelines - avoid making touch targets smaller than 44 points
        let handleRadius = max(handleWidth, 44.0) * 0.5
        
        // Treat handle as a box around it's center
        let pointInsideHorzontalHandleBounds = (point.x >= handle.firstHandleCenter.x - handleRadius   &&   point.x <= handle.firstHandleCenter.x + handleRadius)
        let pointInsideVerticalHandleBounds  = (point.y >= handle.firstHandleCenter.y - handleRadius   &&   point.y <= handle.firstHandleCenter.y + handleRadius)
        if pointInsideHorzontalHandleBounds && pointInsideVerticalHandleBounds {
            return true
        } else {
            return false
        }
    }
    
    // MARK: - Drawing methods
    func drawLine(_ ctx: CGContext, handle: KTRangeCircularHandle) {
        
        filledColor.set()
        // Draw an unfilled arc up to the currently filled point
        //CircularTrig.drawUnfilledArcInContext(ctx, center: centerPoint, radius: computedRadius, lineWidth: CGFloat(lineWidth), fromAngleFromNorth: CGFloat(handle.angleFromNorth), toAngleFromNorth: CGFloat(handle.upperAngleFromNorth), lineCap: filledArcLineCap)
        
        CircularTrig.drawfilledGradientArcInContext(ctx, center: centerPoint, radius: computedRadius, lineWidth: CGFloat(lineWidth), fromAngleFromNorth: CGFloat(handle.angleFromNorth), toAngleFromNorth: CGFloat(handle.upperAngleFromNorth), colors: [orangeColorData, yellowColorData], lineCap: filledArcLineCap)
    }
    
    func drawHandle(_ ctx: CGContext, atPoint handleCenter: CGPoint) -> CGRect {
        ctx.saveGState()
        var frame: CGRect!
        
        // Ensure that handle is drawn in the correct color
        handleColor = computedHandleColor
        handleColor!.set()
        
        frame = CircularTrig.drawFilledCircleInContext(ctx, center: handleCenter, radius: 0.5 * handleWidth)
        
        ctx.saveGState()
        return frame
    }
    
    func drawInnerLabels(_ ctx: CGContext, rect: CGRect) {
        if let labels = innerMarkingLabels, labels.count > 0 {
            let attributes = [convertFromNSAttributedStringKey(NSAttributedString.Key.font): labelFont, convertFromNSAttributedStringKey(NSAttributedString.Key.foregroundColor): labelColor] as [String : Any]
            
            // Enumerate through labels clockwise
            for i in 0 ..< labels.count {
                let label = labels[i] as NSString
                let labelFrame = contextCoordinatesForLabelAtIndex(i)
                
                ctx.saveGState()
                
                // invert transformation used on arc
                ctx.concatenate(CGAffineTransform(translationX: labelFrame.origin.x + (labelFrame.width / 2), y: labelFrame.origin.y + (labelFrame.height / 2)))
                ctx.concatenate(getRotationalTransform().inverted())
                ctx.concatenate(CGAffineTransform(translationX: -(labelFrame.origin.x + (labelFrame.width / 2)), y: -(labelFrame.origin.y + (labelFrame.height / 2))))
                
                // draw label
                label.draw(in: labelFrame, withAttributes: convertToOptionalNSAttributedStringKeyDictionary(attributes))
                
                
                /*let line = "-"
                 let lineFrame = contextCoordinatesForLabelAtIndex(i)
                 
                 ctx.saveGState()
                 
                 // invert transformation used on arc
                 ctx.concatenate(CGAffineTransform(translationX: lineFrame.origin.x + (lineFrame.width / 2), y: lineFrame.origin.y + (lineFrame.height / 2)))
                 ctx.concatenate(getRotationalTransform().inverted())
                 ctx.concatenate(CGAffineTransform(translationX: -(lineFrame.origin.x + (lineFrame.width / 2)), y: -(lineFrame.origin.y + (lineFrame.height / 2))))
                 
                 // draw line
                 line.draw(in: lineFrame, withAttributes: attributes)*/
                
                ctx.restoreGState()
            }
        }
    }
    
    func contextCoordinatesForLabelAtIndex(_ index: Int) -> CGRect {
        let label = innerMarkingLabels![index]
        var percentageAlongCircle: CGFloat!
        
        // Determine how many degrees around the full circle this label should go
        if maximumAngle == 360.0 {
            percentageAlongCircle = ((100.0 / CGFloat(innerMarkingLabels!.count)) * CGFloat(index + 1)) / 100.0
        } else {
            percentageAlongCircle = ((100.0 / CGFloat(innerMarkingLabels!.count - 1)) * CGFloat(index)) / 100.0
        }
        
        let degreesFromNorthForLabel = percentageAlongCircle * maximumAngle
        let pointOnCircle = pointOnCircleAtAngleFromNorth(Int(degreesFromNorthForLabel))
        
        let labelSize = sizeOfString(label, withFont: labelFont)
        let offsetFromCircle = offsetFromCircleForLabelAtIndex(index, withSize: labelSize)
        
        return CGRect(x: pointOnCircle.x + offsetFromCircle.x, y: pointOnCircle.y + offsetFromCircle.y, width: labelSize.width, height: labelSize.height)
    }
    
    func offsetFromCircleForLabelAtIndex(_ index: Int, withSize labelSize: CGSize) -> CGPoint {
        // Determine how many degrees around the full circle this label should go
        let percentageAlongCircle = ((100.0 / CGFloat(innerMarkingLabels!.count - 1)) * CGFloat(index)) / 100.0
        let degreesFromNorthForLabel = percentageAlongCircle * maximumAngle
        
        let radialDistance = innerLabelRadialDistanceFromCircumference + labelDisplacement
        let inwardOffset = CircularTrig.pointOnRadius(radialDistance, atAngleFromNorth: CGFloat(degreesFromNorthForLabel))
        
        return CGPoint(x: -labelSize.width * 0.5 + inwardOffset.x, y: -labelSize.height * 0.5 + inwardOffset.y)
    }
    
    // MARK: - UIControl Functions
    override func continueTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        let lastPoint = touch.location(in: self)
        let lastAngle = floor(CircularTrig.angleRelativeToNorthFromPoint(centerPoint, toPoint: lastPoint))
        
        for handle in arrHandle {
            if handle.firstCircularSliderHandle.highlighted {
                moveLowerHandle(lastAngle, currentHandle: handle, arrHandle: arrHandle)
                
                delegate?.rangeUpdated(startValue: handle.currentValue, endValue: handle.upperCurrentValue, handle: handle)
            } else if handle.secondCircularSliderHandle.highlighted {
                moveUpperHandle(lastAngle, currentHandle: handle, arrHandle: arrHandle)
                
                delegate?.rangeUpdated(startValue: handle.currentValue, endValue: handle.upperCurrentValue, handle: handle)
            }
        }
        
        sendActions(for: UIControl.Event.valueChanged)
        return true
    }
    
    fileprivate func moveHandle(_ newAngleFromNorth: CGFloat, handle : KTRangeCircularHandle) {
        
        // prevent slider from moving past maximumAngle
        if newAngleFromNorth > maximumAngle {
            if handle.angleFromNorth < Int(maximumAngle / 2) {
                handle.angleFromNorth = 0
                setNeedsDisplay()
            } else if handle.angleFromNorth > Int(maximumAngle / 2) {
                handle.angleFromNorth = Int(maximumAngle)
                setNeedsDisplay()
            }
        } else {
            handle.angleFromNorth = Int(newAngleFromNorth)
        }
        setNeedsDisplay()
        
        /*let imgView = UIImageView(frame: CGRect(x: center.x - computedRadius, y: center.y - computedRadius, width: 2 * computedRadius, height: 2 * computedRadius))
         imgView.image = #imageLiteral(resourceName: "handle")
         self.addSubview(imgView)*/
    }
    
    // MARK: - Helper Functions
    func pointOnCircleAtAngleFromNorth(_ angleFromNorth: Int) -> CGPoint {
        let offset = CircularTrig.pointOnRadius(computedRadius, atAngleFromNorth: CGFloat(angleFromNorth))
        return CGPoint(x: centerPoint.x + offset.x, y: centerPoint.y + offset.y)
    }
    
    func sizeOfString(_ string: String, withFont font: UIFont) -> CGSize {
        let attributes = [convertFromNSAttributedStringKey(NSAttributedString.Key.font): font]
        return NSAttributedString(string: string, attributes: convertToOptionalNSAttributedStringKeyDictionary(attributes)).size()
    }
    
    func getRotationalTransform() -> CGAffineTransform {
        if maximumAngle == 360 {
            // do not perform a rotation if using a full circle slider
            let transform = CGAffineTransform.identity.rotated(by: CGFloat(0))
            return transform
        } else {
            // rotate slider view so "north" is at the start
            let radians = Double(-(maximumAngle / 2)) / 180.0 * .pi
            let transform = CGAffineTransform.identity.rotated(by: CGFloat(radians))
            return transform
        }
    }
    
    func imageRotatedByDegrees(oldImage: UIImage, deg degrees: CGFloat) -> UIImage {
        
        //Calculate the size of the rotated view's containing box for our drawing space
        let rotatedViewBox: UIView = UIView(frame: CGRect(x: 0, y: 0, width: oldImage.size.width, height: oldImage.size.height))
        let t: CGAffineTransform = CGAffineTransform(rotationAngle: degrees * CGFloat.pi / 180)
        rotatedViewBox.transform = t
        let rotatedSize: CGSize = rotatedViewBox.frame.size
        
        //Create the bitmap context
        UIGraphicsBeginImageContext(rotatedSize)
        let bitmap: CGContext = UIGraphicsGetCurrentContext()!
        
        //Move the origin to the middle of the image so we will rotate and scale around the center.
        bitmap.translateBy(x: rotatedSize.width / 2, y: rotatedSize.height / 2)
        
        //Rotate the image context
        bitmap.rotate(by: (degrees * CGFloat.pi / 180))
        
        //Now, draw the rotated/scaled image into the context
        bitmap.scaleBy(x: 1.0, y: -1.0)
        
        bitmap.draw(oldImage.cgImage!, in: CGRect(x: -oldImage.size.width / 2, y: -oldImage.size.height / 2, width: oldImage.size.width, height: oldImage.size.height))
        
        let newImage: UIImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return newImage
    }
    
    
    
    
    
    // MARK: - UIControl Functions
    override func beginTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        let location = touch.location(in: self)
        
        for handle in arrHandle {
            if pointInsideHandle(pointOnCircleAtAngleFromNorth(handle.angleFromNorth), point: location, withEvent: event!) {
                handle.firstCircularSliderHandle.highlighted = true
            } else if pointInsideHandle(pointOnCircleAtAngleFromNorth(handle.upperAngleFromNorth), point: location, withEvent: event!) {
                handle.secondCircularSliderHandle.highlighted = true
            }
        }
        
        var returnStatus = false
        for handle in arrHandle {
            returnStatus = returnStatus || handle.firstCircularSliderHandle.highlighted || handle.secondCircularSliderHandle.highlighted
        }
        
        return returnStatus
    }
    
    
    override func endTracking(_ touch: UITouch?, with event: UIEvent?) {
        for handle in arrHandle {
            handle.firstCircularSliderHandle.highlighted = false
            handle.secondCircularSliderHandle.highlighted = false
        }
    }
    
    fileprivate func moveLowerHandle(_ newAngleFromNorth: CGFloat, currentHandle: KTRangeCircularHandle, arrHandle: [KTRangeCircularHandle]) {
        let conditionOne = newAngleFromNorth > maximumAngle
        if conditionOne {
            currentHandle.angleFromNorth = 0
            setNeedsDisplay()
            return
        }
        
        for handle in arrHandle {
            
            if handle == currentHandle {
                let condition = newAngleFromNorth > (CGFloat(handle.upperAngleFromNorth) - minimumHandleDistance)
                if condition {
                    currentHandle.angleFromNorth = Int(handle.upperAngleFromNorth) - Int(minimumHandleDistance)
                    setNeedsDisplay()
                    return
                }
            } else {
                if handle.upperAngleFromNorth < currentHandle.angleFromNorth && handle.upperAngleFromNorth >= 0 {
                    let condition = newAngleFromNorth < (CGFloat(handle.upperAngleFromNorth) + minimumHandleDistance)
                    if condition {
                        currentHandle.angleFromNorth = Int(handle.upperAngleFromNorth) + Int(minimumHandleDistance)
                        setNeedsDisplay()
                        return
                    }
                } else {
                    // do nothing as this this situation never araise
                }
            }
        }
        
        currentHandle.angleFromNorth = Int(newAngleFromNorth)
        setNeedsDisplay()
    }
    
    fileprivate func moveUpperHandle(_ newAngleFromNorth: CGFloat, currentHandle: KTRangeCircularHandle, arrHandle: [KTRangeCircularHandle]) {
        let conditionOne = newAngleFromNorth > maximumAngle
        if conditionOne {
            currentHandle.upperAngleFromNorth = Int(maximumAngle)
            setNeedsDisplay()
            return
        }
        
        for handle in arrHandle {
            if handle == currentHandle {
                let condition = newAngleFromNorth < (CGFloat(handle.angleFromNorth) + minimumHandleDistance)
                if condition {
                    currentHandle.upperAngleFromNorth = Int(handle.angleFromNorth) + Int(minimumHandleDistance)
                    setNeedsDisplay()
                    return
                }
            } else {
                if handle.angleFromNorth > currentHandle.upperAngleFromNorth && handle.angleFromNorth <= Int(maximumAngle) {
                    let condition = newAngleFromNorth > (CGFloat(handle.angleFromNorth) - minimumHandleDistance)
                    if condition {
                        currentHandle.upperAngleFromNorth = Int(handle.angleFromNorth) - Int(minimumHandleDistance)
                        setNeedsDisplay()
                        return
                    }
                } else {
                    // do nothing as this situation never araise
                }
            }
        }
        
        currentHandle.upperAngleFromNorth = Int(newAngleFromNorth)
        setNeedsDisplay()
    }
    
    func isCurrentRangeCollideWithOther(currentHandle: KTRangeCircularHandle) -> Bool {
        
        for handle in arrHandle {
            
            if (handle.angleFromNorth <= currentHandle.upperAngleFromNorth && handle.upperAngleFromNorth >= currentHandle.upperAngleFromNorth ) || (handle.angleFromNorth <= currentHandle.angleFromNorth && handle.upperAngleFromNorth >= currentHandle.angleFromNorth ) {
                setNeedsDisplay()
                return true
            }
        }
        return false
    }
    
    // MARK: - Helper Methods
    fileprivate func pointInsideHandle(_ handleCenter: CGPoint, point: CGPoint, withEvent event: UIEvent) -> Bool {
        // Adhere to apple's design guidelines - avoid making touch targets smaller than 44 points
        let handleRadius = max(handleWidth, 44.0) * 0.5
        
        // Treat handle as a box around it's center
        let pointInsideHorzontalHandleBounds = (point.x >= handleCenter.x - handleRadius && point.x <= handleCenter.x + handleRadius)
        let pointInsideVerticalHandleBounds  = (point.y >= handleCenter.y - handleRadius && point.y <= handleCenter.y + handleRadius)
        return pointInsideHorzontalHandleBounds && pointInsideVerticalHandleBounds
    }
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertFromNSAttributedStringKey(_ input: NSAttributedString.Key) -> String {
	return input.rawValue
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertToOptionalNSAttributedStringKeyDictionary(_ input: [String: Any]?) -> [NSAttributedString.Key: Any]? {
	guard let input = input else { return nil }
	return Dictionary(uniqueKeysWithValues: input.map { key, value in (NSAttributedString.Key(rawValue: key), value)})
}
