//
//  ViewController.swift
//  KTMultiRangeCircularSlider
//
//  Created by Kartik Patel on 6/5/17.
//  Copyright © 2017 KTPatel. All rights reserved.
//

import UIKit

class RangeData {
    var startHour : Int = 0
    var startMinute : Int = 0
    var endHour : Int = 0
    var endMinute : Int = 0
    
    var rangeHandle : KTRangeCircularHandle?
}

class ViewController: UIViewController, KTMultiRangeCircularSliderDelegate {

    @IBOutlet weak var viewMultRangeSlider: UIView!
    
    @IBOutlet weak var btnClearAll: UIButton!
    @IBOutlet weak var btnAdd: UIButton!
    
    var circularSlider : KTMultiRangeCircularSlider!
    
    var arrRangeData = [RangeData]()
    
    var flagRemoveRange = false
    var flagAddRange = false
    var selectedRange : RangeData?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        let rangeOne = RangeData()
        rangeOne.startHour = 1
        rangeOne.startMinute = 0
        rangeOne.endHour = 6
        rangeOne.endMinute = 0
        arrRangeData.append(rangeOne)
        
        let rangeTwo = RangeData()
        rangeTwo.startHour = 7
        rangeTwo.startMinute = 0
        rangeTwo.endHour = 10
        rangeTwo.endMinute = 30
        arrRangeData.append(rangeTwo)
        
        let rangeThree = RangeData()
        rangeThree.startHour = 15
        rangeThree.startMinute = 45
        rangeThree.endHour = 22
        rangeThree.endMinute = 40
        arrRangeData.append(rangeThree)
        
        
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        setupMultiRangeSliderView()
        
        addMultipleRangeSlider()
    }
    
    func setupMultiRangeSliderView() {
        
        let frame = CGRect(x: 0, y: 0, width: viewMultRangeSlider.frame.width, height: viewMultRangeSlider.frame.height)
        circularSlider = KTMultiRangeCircularSlider(frame: frame)
        
        circularSlider.delegate = self
        
        // setup target to watch for value change
        circularSlider.addTarget(self, action: #selector(ViewController.multiRangeSliderViewValueChanged(_:)), for: UIControlEvents.valueChanged)
        
        // setup slider defaults
        // NOTE: sliderMaximumAngle must be set before currentValue and upperCurrentValue
        circularSlider.maximumAngle = 360.0
        circularSlider.unfilledArcLineCap = .round
        circularSlider.filledArcLineCap = .round
        circularSlider.lineWidth = UIScreen.main.nativeBounds.size.height > 1136 ? 40 : 25
        circularSlider.labelFont = UIFont.init(name: "Arial", size: UIScreen.main.nativeBounds.size.height > 1136 ? 16 : 10)!
        
        circularSlider.labelDisplacement = -5.0
        circularSlider.innerMarkingLabels = (1...24).map{"\($0)"}
        
        // add to view
        viewMultRangeSlider.addSubview(circularSlider)
        
        // create and set a transform to rotate the arc so the white space is centered at the bottom
        circularSlider.transform = circularSlider.getRotationalTransform()
    }
    
    func addMultipleRangeSlider() {
        // _ = circularSlider.addHandle(currentValue: 5, upperCurrentValue: 15)
        
        for objRange in  arrRangeData {
            let startValue = getPercentageFromTime(hour: objRange.startHour, minute: objRange.startMinute)
            let endValue = getPercentageFromTime(hour: objRange.endHour, minute: objRange.endMinute)
            objRange.rangeHandle = circularSlider.addHandle(currentValue: Float(startValue), upperCurrentValue: Float(endValue))
        }
    }
    
    func multiRangeSliderViewValueChanged(_ slider: KTMultiRangeCircularSlider) {
        //lowerValueLabel.text = "\(slider.handle1.currentValue)"
        //upperValueLabel.text = "\(slider.handle1.upperCurrentValue)"
        
        for handle in slider.arrHandle {
            print("rane2: start = \(handle.currentValue)")
            print("range2: end = \(handle.upperCurrentValue)")
        }
    }
    
    func clearRanges() {
        for objRangeData in arrRangeData {
            circularSlider.removeHandle(handle: objRangeData.rangeHandle!)
            arrRangeData.remove(object: objRangeData)
            flagRemoveRange = false
        }
    }
    
    @IBAction func btnAdd_TouchUpInside(_ sender: Any) {
        flagAddRange = true;
    }
    @IBAction func btnClearAll_TouchUpInside(_ sender: Any) {
        clearRanges()
    }
    
    // Mark: KTMultiRangeCircularSliderDelegate
    func rangeUpdated(startValue: Float, endValue: Float, handle: KTRangeCircularHandle) {
        let (startHour, startMinute) = getTimeFromPercentage(percentage: Double(startValue))
        let (endHour, endMinute) = getTimeFromPercentage(percentage: Double(endValue))
        
        if let selectedRangeData = arrRangeData.filter({$0.rangeHandle! == handle}).first as RangeData? {
            selectedRangeData.startHour = startHour
            selectedRangeData.startMinute = startMinute
            
            selectedRangeData.endHour = endHour
            selectedRangeData.endMinute = endMinute
        }
    }
    
    func percentageAtTouchByUser(percentage: Double) {
        
        var isTouchOnExistingRange = false;
        
        for objRangeData in arrRangeData {
            
            let startValue = self.getPercentageFromTime(hour: objRangeData.startHour, minute: objRangeData.startMinute)
            let endValue = self.getPercentageFromTime(hour: objRangeData.endHour, minute: objRangeData.endMinute)
            
            if percentage >= startValue && percentage <= endValue {
                // touch inside Range
                
                isTouchOnExistingRange = true
                
                if flagRemoveRange == true {
                    circularSlider.removeHandle(handle: objRangeData.rangeHandle!)
                    
                    arrRangeData.remove(object: objRangeData)
                    
                    flagRemoveRange = false
                    
                    break
                }
            }
        }
        
        if isTouchOnExistingRange == false && flagAddRange == true && percentage < 95 {
            
            let objRange = RangeData()
            (objRange.startHour, objRange.startMinute) = getTimeFromPercentage(percentage: percentage)
            (objRange.endHour, objRange.endMinute) = getTimeFromPercentage(percentage: percentage + 5.0)
            if let handle = circularSlider.addHandle(currentValue: Float(percentage), upperCurrentValue: Float(percentage + 5)){
                    objRange.rangeHandle = handle
                    arrRangeData.append(objRange)
            }
            
            flagAddRange = false
        }
    }
    
    
    // Mark: custom functions
    func getPercentageFromTime(hour: Int, minute:Int) -> Double {
        let totalMinutes = (hour * 60) + minute
        return Double(totalMinutes * 100) / 1440.0
    }
    
    func getTimeFromPercentage(percentage: Double) -> (hour: Int, minute: Int){
        let totalMinutes = (percentage * 1440) / 100
        let hour = Int(totalMinutes / 60)
        let minute = Int(totalMinutes) % 60
        
        return (hour: hour, minute: minute)
    }
}

