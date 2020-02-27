//
//  CircularSlider.swift
//
//  Created by Christopher Olsen on 03/03/16.
//  Copyright © 2016 Christopher Olsen. All rights reserved.
//

/*
 Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
 
 The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */

import UIKit
import QuartzCore
import Foundation

enum CircularSliderHandleType {
    case semiTransparentWhiteSmallCircle,
    semiTransparentWhiteCircle,
    semiTransparentBlackCircle,
    bigCircle
}

extension UIView {
    func applyGradient(colours: [UIColor]) -> Void {
        self.applyGradient(colours: colours, locations: nil)
    }
    
    func applyGradient(colours: [UIColor], locations: [NSNumber]?) -> Void {
        let gradient: CAGradientLayer = CAGradientLayer()
        gradient.frame = self.bounds
        gradient.colors = colours.map { $0.cgColor }
        gradient.locations = locations
        self.layer.insertSublayer(gradient, at: 0)
    }
}

class CircularSlider: UIControl {
    
    var imgView : UIImageView?
    var rotationAnimation : CABasicAnimation?
    
    // MARK: Values
    // Value at North/midnight (start)
    var minimumValue: Float = 0.0 {
        didSet {
            setNeedsDisplay()
        }
    }
    
    // Value at North/midnight (end)
    var maximumValue: Float = 100.0 {
        didSet {
            setNeedsDisplay()
        }
    }
    
    // value for end of arc. This allows for incomplete circles to be created
    var maximumAngle: CGFloat = 360.0 {
        didSet {
            if maximumAngle > 360.0 {
                print("Warning: Maximum angle should be 360 or less.")
                maximumAngle = 360.0
            }
            setNeedsDisplay()
        }
    }
    
    // Current value between North/midnight (start) and North/midnight (end) - clockwise direction
    var currentValue: Float {
        set {
            assert(newValue <= maximumValue && newValue >= minimumValue, "current value \(newValue) must be between minimumValue \(minimumValue) and maximumValue \(maximumValue)")
            
            // Update the angleFromNorth to match this newly set value
            angleFromNorth = CGFloat((newValue * Float(maximumAngle)) / (maximumValue - minimumValue))
            //print("currentValue: \(newValue), oldAngle: \(angleFromNorth)")
            
            //angleFromNorth = Int(270.0 * (newValue * 100 / (maximumValue - minimumValue)) / (maximumValue - minimumValue))
            //print("currentValue: \(newValue), newAngle: \(angleFromNorth)")
            
            moveHandle(CGFloat(angleFromNorth))
            sendActions(for: UIControl.Event.valueChanged)
        } get {
            return (Float(angleFromNorth) * (maximumValue - minimumValue)) / Float(maximumAngle)
        }
    }
    
    // MARK: Handle
    let circularSliderHandle = CircularSliderHandle()
    
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
    var unfilledColor: UIColor = .black {
        didSet {
            setNeedsDisplay()
        }
    }
    
    // Font of the inner marking labels within the circle
    var labelFont: UIFont = .systemFont(ofSize: 10.0) {
        didSet {
            setNeedsDisplay()
        }
    }
    
    // Color of the inner marking labels within the circle
    var labelColor: UIColor = .red {
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
    
    var angleFromNorth: CGFloat = 0 {
        didSet {
            assert(angleFromNorth >= 0.0, "angleFromNorth \(angleFromNorth) must be greater than 0")
        }
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
        
        // Draw the circular lines that slider handle moves along
        drawLine(ctx!)
        
        // Draw the draggable 'handle'
        let handleCenter = pointOnCircleAtAngleFromNorth(angleFromNorth)
        circularSliderHandle.frame = drawHandle(ctx!, atPoint: handleCenter)
        
                
        
        // added image as handler - kartik
        if imgView == nil {
            imgView = UIImageView(frame: circularSliderHandle.frame)
            imgView?.image = self.imageRotatedByDegrees(oldImage: #imageLiteral(resourceName: "knob_50"), deg: CGFloat(angleFromNorth))
            self.addSubview(imgView!)
        } else  {
            imgView?.frame = circularSliderHandle.frame
            imgView?.image = self.imageRotatedByDegrees(oldImage: #imageLiteral(resourceName: "knob_50"), deg: CGFloat(angleFromNorth))
        }
        
        // Draw inner labels
        drawInnerLabels(ctx!, rect: rect)
    }
    
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        guard event != nil else { return false }
        
        if pointInsideHandle(point, withEvent: event!) {
            return true
        } else {
            return pointInsideCircle(point, withEvent: event!)
        }
    }
    
    fileprivate func pointInsideCircle(_ point: CGPoint, withEvent event: UIEvent) -> Bool {
        let p1 = centerPoint
        let p2 = point
        let xDist = p2.x - p1.x
        let yDist = p2.y - p1.y
        let distance = sqrt((xDist * xDist) + (yDist * yDist))
        return distance < computedRadius + CGFloat(lineWidth) * 0.5
    }
    
    fileprivate func pointInsideHandle(_ point: CGPoint, withEvent event: UIEvent) -> Bool {
        let handleCenter = pointOnCircleAtAngleFromNorth(angleFromNorth)
        // Adhere to apple's design guidelines - avoid making touch targets smaller than 44 points
        let handleRadius = max(handleWidth, 44.0) * 0.5
        
        // Treat handle as a box around it's center
        let pointInsideHorzontalHandleBounds = (point.x >= handleCenter.x - handleRadius && point.x <= handleCenter.x + handleRadius)
        let pointInsideVerticalHandleBounds  = (point.y >= handleCenter.y - handleRadius && point.y <= handleCenter.y + handleRadius)
        return pointInsideHorzontalHandleBounds && pointInsideVerticalHandleBounds
    }
    
    // MARK: - Drawing methods
    func drawLine(_ ctx: CGContext) {
        unfilledColor.set()
        // Draw an unfilled circle (this shows what can be filled)
        CircularTrig.drawUnfilledCircleInContext(ctx, center: centerPoint, radius: computedRadius, lineWidth: CGFloat(lineWidth), maximumAngle: maximumAngle, lineCap: unfilledArcLineCap)
        
        filledColor.set()
        // Draw an unfilled arc up to the currently filled point
        CircularTrig.drawUnfilledArcInContext(ctx, center: centerPoint, radius: computedRadius, lineWidth: CGFloat(lineWidth), fromAngleFromNorth: 0, toAngleFromNorth: CGFloat(angleFromNorth), lineCap: filledArcLineCap)
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
        let pointOnCircle = pointOnCircleAtAngleFromNorth(degreesFromNorthForLabel)
        
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
        
        moveHandle(lastAngle)
        sendActions(for: UIControl.Event.valueChanged)
        
        return true
    }
    
    fileprivate func moveHandle(_ newAngleFromNorth: CGFloat) {
        
        // prevent slider from moving past maximumAngle
        if newAngleFromNorth > maximumAngle {
            if angleFromNorth < maximumAngle / 2 {
                angleFromNorth = 0
                setNeedsDisplay()
            } else if angleFromNorth > maximumAngle / 2 {
                angleFromNorth = maximumAngle
                setNeedsDisplay()
            }
        } else {
            angleFromNorth = newAngleFromNorth
        }
        setNeedsDisplay()
    }
    
    // MARK: - Helper Functions
    func pointOnCircleAtAngleFromNorth(_ angleFromNorth: CGFloat) -> CGPoint {
        let offset = CircularTrig.pointOnRadius(computedRadius, atAngleFromNorth: angleFromNorth)
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
