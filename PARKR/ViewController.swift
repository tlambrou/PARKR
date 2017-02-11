//
//  ViewController.swift
//  PARKR
//
//  Created by Tassos Lambrou on 11/17/16.
//  Copyright © 2016 SsosSoft. All rights reserved.
//

import Foundation
import UIKit
import MapKit
import CoreLocation
import Alamofire
import SwiftyJSON
import Darwin

// Convenience init for creating Polyline

private extension MKPolyline {
    convenience init(coordinates coords: Array<CLLocationCoordinate2D>) {
        let unsafeCoordinates = UnsafeMutablePointer<CLLocationCoordinate2D>.allocate(capacity: coords.count)
        unsafeCoordinates.initialize(from: coords)
        self.init(coordinates: unsafeCoordinates, count: coords.count)
        unsafeCoordinates.deallocate(capacity: coords.count)
    }
}


enum UniqueValuesType: Int {
    case daysOfWeek, hoursBegin, hoursEnd, timeLimit
}


// Global variable for all timed parking data
var AllTimedParkingData = [TimedParking]()

class ViewController: UIViewController, MKMapViewDelegate, CLLocationManagerDelegate {
    
    var touchPoint: CGPoint!
    var touchPointCoordinate: CLLocationCoordinate2D!
    
    var annotation = MKPointAnnotation()
    
    // MARK: - IBOutlets
    
    @IBOutlet weak var moveByTimingLabel: UILabel!
    
    // This label located down right corner
    @IBOutlet weak var moveOutLabel: UILabel!
    // This label located down left corner
    @IBOutlet weak var durationParkingLabel: UILabel!
    
    @IBOutlet weak var geocodingLabel: UILabel!
    
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var TimedTimeLabel: UILabel!
    
    var locationManager = CLLocationManager()
    
    let showAlert = UIAlertController()
    
    enum renderTypes { case active, inactive }
    
    var renderer: renderTypes = .active
    
    
    // Redraw all of the nearby lines...
    
    enum modeTypes { case automatic, manual }
    
    var mode: modeTypes = .automatic
    
    // MARK: - Location Manager Func
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        
        print("\n\n Location Manager updated!!!!!!!!! \n\n")
        
        // TODO: If automatic mode...
        //    mapView.setUserTrackingMode(MKUserTrackingMode.follow, animated: false)
        
        // Make sure location is not nil
        guard let location = locations.first else {
            print("No location!")
            return
        }
        
        
        
        // Find all of the nearest blocks within a threshhold...
        
        print("\n\nLocation: ", location.coordinate, "\n\n")
        
        let subset = findLinesInMapView()
        print("\n\nSubset in didUpdateLocations: \(subset.count)")
        
        // Make sure to see if location is in SF and if not display a message
        guard subset.count > 0
            else {
                print("No Timed Parking Nearby")
                geocodingLabel.text = "No SF Data Nearby"
                let newRect = MKMapRect(origin: MKMapPointForCoordinate(location.coordinate), size: (AllTimedParkingData[0].mapRect?.size)!)
                let edge = UIEdgeInsets(top: 100, left: 100, bottom: 100, right: 100)
                mapView.setVisibleMapRect(newRect, edgePadding: edge, animated: false)
                return
        }
        
        // MARK: - Find Nearest block
        // Find the nearest block among all of the nearest blocks...
        let currentBlock = findNearestBlock(data: subset, currentLocation: location)
        print("CURRENT DoW: \(currentBlock.DoW!)")
        print("DAYS: \(currentBlock.days)")
        print("Hrs Begin: \(currentBlock.hoursBegin.hour)")
        print("Hrs End: \(currentBlock.hoursEnd.hour)")
        print("Hrs Limit: \(currentBlock.hourLimit)")
        
        // Create a composite rect of both the new coordinates and the selected block...
        let coordRect = MKMapRect(origin: MKMapPointForCoordinate(location.coordinate), size: (currentBlock.mapRect?.size)!)
        let newRect = MKMapRectUnion(coordRect, currentBlock.mapRect!)
        let edge = UIEdgeInsets(top: 100, left: 100, bottom: 100, right: 100)
        mapView.setVisibleMapRect(newRect, edgePadding: edge, animated: false)
        
        // Redraw all of the nearby lines...
        
        
        // Paint all these polylines as disabled
        for line in subset {
            
            renderer = .inactive
            mapView.add(line.line!)
            
        }
        
        // Paint the active line as active
        renderer = .active
        mapView.add(currentBlock.line!, level: MKOverlayLevel.aboveLabels)
        renderer = .inactive
        
        // Update all of the rules and times...
        updateRules(location: currentBlock)
        
        // Update the reverse geocoding...
        
        updateReverseGeoCoding(location: location)
        
        // Stop updating location and start updating signficant changes to location
        locationManager.stopUpdatingLocation()
        locationManager.startMonitoringSignificantLocationChanges()
        
    }
    
    //  func mapView(_ mapView: MKMapView, regionWillChangeAnimated animated: Bool) {
    //    if animated == true && animating == false {
    //      animating = true
    
    //    locationManager.startUpdatingLocation()
    //
    //    // Set the delegate
    //    locationManager.delegate = self
    //
    //    // Initialize the MapView
    //    mapView.delegate = self
    //    mapView.showsCompass = true
    //    mapView.showsPointsOfInterest = true
    //    mapView.showsUserLocation = true
    //    mapView.showsBuildings = true
    ////    mapView.setUserTrackingMode(MKUserTrackingMode.follow, animated: false)
    //    //    let subset = findLinesInMapView()
    //    //
    //    //    print("\n\nSubset in FindParking: \(subset.count)")
    //    //
    //    //    guard subset.count > 0
    //    //      else {
    //    //        print("Not in San Francisco!")
    //    //        geocodingLabel.text = "Oops! Not in San Francisco!"
    //    //        let newRect = MKMapRect(origin: MKMapPointForCoordinate(location.coordinate), size: (AllTimedParkingData[0].mapRect?.size)!)
    //    //        let edge = UIEdgeInsets(top: 100, left: 100, bottom: 100, right: 100)
    //    //        mapView.setVisibleMapRect(newRect, edgePadding: edge, animated: true)
    //    //        return
    //    //    }
    //    //  }
    //    //
    //    //  func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
    //    //    if animated == true && animating == true {
    //    //      animating = false
    //    //    }
    //    //  }
    
    private func locationManager(manager: CLLocationManager, didChangeAuthorizationStatus status: CLAuthorizationStatus) {
        
        switch status {
        case .notDetermined:
            print("NotDetermined")
        case .restricted:
            print("Restricted")
        case .denied:
            print("Denied")
        case .authorizedAlways:
            print("AuthorizedAlways")
        case .authorizedWhenInUse:
            print("AuthorizedWhenInUse")
            locationManager.startUpdatingLocation()
            
        }
    }
    
    private func locationManager(manager: CLLocationManager, didFailWithError error: NSError) {
        print("Failed to initialize GPS: ", error.description)
    }
    
    // MARK: - Application View life Cycle
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(true)
        //When authorization status is not determined.
        if CLLocationManager.authorizationStatus() == .notDetermined {
            locationManager.requestAlwaysAuthorization()
        } else if CLLocationManager.authorizationStatus() == .denied {
            showAlert.message = "Location services were previously denied. Please enable location services for this app in settings."
        } else if CLLocationManager.authorizationStatus() == .authorizedAlways {
            locationManager.startUpdatingLocation()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        longPress()
        readJSON(from: "TimedParkingData.geojson")
        
    }
    
    func longPress() {
        let touch = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(gestureRecognizer:)))
        touch.minimumPressDuration = 0.1
        self.mapView.addGestureRecognizer(touch)
    }
    
    func handleLongPress(gestureRecognizer: UIGestureRecognizer) {
        // function to initialize the touch point, and drop the annotation pin into the mapview
        if gestureRecognizer.state != .began {
            return
        } else {
            touchPoint = gestureRecognizer.location(in: self.mapView)
            touchPointCoordinate = self.mapView.convert(touchPoint, toCoordinateFrom: self.mapView)
            // create an annotation
            annotation.coordinate = touchPointCoordinate
            self.mapView.addAnnotation(annotation)
            
            
        }
    }
    
    // MARK: - Find Parking func
    func findParking() {
    
        guard let location = locationManager.location else {
            print("No location!")
            return
        }
        
        locationManager.startUpdatingLocation()
        
        // Set the delegate
        locationManager.delegate = self
        
        // Initialize the MapView
        mapView.delegate = self
        mapView.showsCompass = true
        mapView.showsPointsOfInterest = true
        mapView.showsUserLocation = true
        mapView.showsBuildings = true
        mapView.setUserTrackingMode(MKUserTrackingMode.follow, animated: false)

    }
    
    func updateReverseGeoCoding(location: CLLocation) {
        // Update geocoding label with address based on location
        CLGeocoder().reverseGeocodeLocation(location) { (placemark, error) in
            if error != nil {
                print ("\n\nThere was an error geocoding\n\n")
            } else {
                if let place = placemark?[0] {
                    if place.subThoroughfare != nil {
                        self.geocodingLabel.text = "\(place.subThoroughfare!) \(place.thoroughfare!)\n\(place.locality!), \(place.administrativeArea!)"
                    }
                }
            }
        }
        
    }
    
    // MARK: - MapView Line Renderer
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        // if MKOverlayPathRenderer
        let polylineRenderer = MKPolylineRenderer(overlay: overlay)
        switch renderer {
        case .active:
            polylineRenderer.strokeColor = UIColor.green
            polylineRenderer.lineWidth = 6
        case .inactive:
            polylineRenderer.strokeColor = UIColor.purple
            polylineRenderer.lineWidth = 4
        }
        
        return polylineRenderer
        
    }
    
    // MARK: - Read JSON
    func readJSON(from file: String) {
        
        print("Begin loading parking data...")
        
        // Show progress bar
        let progressBar = UILabel()
        progressBar.text = "Loading..."
        progressBar.textColor = UIColor.darkGray
        progressBar.font = UIFont.boldSystemFont(ofSize: 18)
        progressBar.sizeToFit()
        self.mapView.addSubview(progressBar)
        
        DispatchQueue.global().async {
            
            let fileComponents = file.components(separatedBy: ".")
            
            let path = Bundle.main.path(forResource: fileComponents[0], ofType: fileComponents[1])
            
            let text = try! String(contentsOfFile: path!) // read as string
            
            let json = try! JSONSerialization.jsonObject(with: text.data(using: .utf8)!, options: []) as? [String: Any]
            
            let json2 = JSON(json!)
            
            let allData = json2["features"].arrayValue
            
            AllTimedParkingData = allData.map({ (entry: JSON) -> TimedParking in
                return TimedParking(json: entry)
            })
            
            DispatchQueue.main.async {
                print("Done loaing parking data...")
                
                // Hide progress
                progressBar.removeFromSuperview()
                
                self.findParking()
                
                //self.outputDataToFile()
                
            }
            
            //  print("\n\n\nUNIQUE VALUES FOR DOW\n\n\n", getUniqueValues(theData: AllTimedParkingData), "\n\n\n\n")
            
        }
        
        //  let json = try! JSONSerialization.jsonObject(with: text.data(using: .utf8)!, options: []) as? [String: Any]
        //  print(json)
        
    }
    
//    func outputDataToFile() {
//        
//        let fileName = "Output.swift"
//        
//        let filePath = "/Users/Tassos/Desktop/Academics/Make School/Product Academy/PD - Cities/PARKR/PARKR" + fileName
//        
//        let file = FileHandle(forWritingAtPath: filePath)
//        
//        print(file ?? "default for file")
//        
//        if file != nil {
//            // Set the data we want to write
//            
//            let data1 = AllTimedParkingData[0]
//            var test = [TimedParking]()
//            print(test)
//            test = [TimedParking(days: "M-F", hoursBegin: DateComponents(hour: 8, minute: 0), hoursEnd: DateComponents(hour: 17, minute: 0), hourLimit: 2, id: 4193, geometry: [CLLocationCoordinate2D(latitude: CLLocationDegrees(37.773406362670492), longitude: CLLocationDegrees(-122.4179728411779)), CLLocationCoordinate2D(latitude: CLLocationDegrees(37.773124891577787), longitude: CLLocationDegrees(-122.4174969850627))]), TimedParking(days: "M-F", hoursBegin: DateComponents(hour: 8, minute: 0), hoursEnd: DateComponents(hour: 17, minute: 0), hourLimit: 2, id: 4193, geometry: [CLLocationCoordinate2D(latitude: CLLocationDegrees(37.773406362670492), longitude: CLLocationDegrees(-122.4179728411779)), CLLocationCoordinate2D(latitude: CLLocationDegrees(37.773124891577787), longitude: CLLocationDegrees(-122.4174969850627))])]
//            
//            let data = ("[TimedParking(days: \"\(data1.days)\", hoursBegin: DateComponents(hour: \(data1.hoursBegin.hour), minute: \(data1.hoursBegin.minute)), hoursEnd: DateComponents(hour: \(data1.hoursEnd.hour), minute: \(data1.hoursEnd.minute)), hourLimit: \(data1.hourLimit), id: \(data1.id), geometry: [CLLocationCoordinate2D(latitude: CLLocationDegrees(\(data1.geometry[0].latitude)), longitude: CLLocationDegrees(\(data1.geometry[0].longitude))), CLLocationCoordinate2D(latitude: CLLocationDegrees(\(data1.geometry[1].latitude)), longitude: CLLocationDegrees(\(data1.geometry[1].longitude)))])]").data(using: String.Encoding(rawValue: String.Encoding.utf8.rawValue))
//            
//            print(data!)
//            
//            // Append to the end of the file
//            file?.seekToEndOfFile()
//            
//            // Write it to the file
//            file?.write(data!)
//            
//            // Close the file
//            file?.closeFile()
//        }
//        else {
//            print("Ooops! Something went wrong!")
//        }
//        
//        
//    }
    
    
    func findLinesInMapView() -> [TimedParking] {
        
        var subset = [TimedParking]()
        
        for location in AllTimedParkingData {
            if (location.line?.intersects(mapView.visibleMapRect))! {
                subset.append(location)
            }
        }
        return subset
    }
    
    
    func findNearbyLines(currentLocation: CLLocation) -> [TimedParking] {
        
        var subset = [TimedParking]()
        
        for location in AllTimedParkingData {
            
            //      if location.midPoint != nil {
            //        print("MidPoint: ", location.midPoint!, "\n", "Distance: ", location.midPoint!.distance(from: currentLocation), "\n", "CLLocationDistance(350): ", CLLocationDistance(350))
            //      } else if location.midPoint == nil {
            //        print("MidPoint: ", "nil", "\n", "Distance: ", "No Distance", "\n", "id: ", location.id)
            //      }
            
            let locationConvert = CLLocation.init(latitude: (location.line?.coordinate.latitude)!, longitude: (location.line?.coordinate.longitude)!)
            
            if location.line != nil && (locationConvert.distance(from: currentLocation) < CLLocationDistance(300)) {
                subset.append(location)
                
            }
            
        }
        
        return subset
        
        for location in AllTimedParkingData {
            if (location.line?.intersects(mapView.visibleMapRect))! {
                subset.append(location)
            }
        }
        return subset
    }
    
    //  func queryForCurrentBoundingMap (mapRect: MKMapRect) -> String {
    //
    //
    //
    //  }
    
    
    
    
    // MARK: Nearest Block function
    
    func findNearestBlock(data: [TimedParking], currentLocation: CLLocation) -> TimedParking {
        
        var closest: TimedParking?
        var closestDistance: CLLocationDistance = CLLocationDistance(99999999)
        
        for location in data {
            
            if location.geometry.count > 1 {
                
                // Create point coordinates for location in the data
                let x2 = location.geometry[1].longitude
                let x1 = location.geometry[0].longitude
                let y2 = location.geometry[1].latitude
                let y1 = location.geometry[0].latitude
                
                // Calculate the change in x and y
                let dx = x2 - x1
                let dy = y2 - y1
                
                // Calculate the slope
                let slope = dx / dy
                
                // Convert points to CLLocation
                let p1 = CLLocation(latitude: y1, longitude: x1)
                
                let p2 = CLLocation(latitude: y2, longitude: x2)
                
                // Distance between point locations
                let segDist = p1.distance(from: p2)
                
                // Determine closest distance between a point and a line defined by 2 points
                func distanceCurrentLocToSegment(p: CLLocation, p1: CLLocation, p2: CLLocation) -> CLLocationDistance {
                    
                    // Create point coordinates for longitude & latitude
                    let x1 = p1.coordinate.longitude
                    let x2 = p2.coordinate.longitude
                    let y1 = p1.coordinate.latitude
                    let y2 = p2.coordinate.latitude
                    
                    var ix: Double = 0
                    var iy: Double = 0
                    
                    // Function to find magnitude of line segment
                    func lineMagnitude (x1: Double, y1: Double, x2: Double, y2: Double) -> Double {
                        return CLLocationDistance(abs(sqrt(pow((x2-x1), 2) + pow((y2-y1), 2))))
                    }
                    
                    let lineMag = lineMagnitude(x1: x1, y1: y1, x2: x2, y2: y2)
                    
                    // Accounting for a line magnitude threshold that is neglibly zero
                    if lineMag < 0.00000001 {
                        print("short segment")
                        return CLLocationDistance(abs(9999))
                    }
                    
                    // Create point coordinates for non-line point for comparison
                    let px = p.coordinate.longitude
                    let py = p.coordinate.latitude
                    
                    // Find distance "u"
                    var u = (((px - x1) * (x2 - x1)) + ((py - y1) * (y2 - y1)))
                    u = u / (lineMag * lineMag)
                    
                    // Distance calculation
                    if ((u < 0.00001) || (u > 1)) {
                        ix = lineMagnitude(x1: px, y1: py, x2: x1, y2: y1)
                        iy = lineMagnitude(x1: px, y1: py, x2: x2, y2: y2)
                        if ix > iy {
                            return CLLocationDistance(abs(iy))
                        } else {
                            return CLLocationDistance(abs(ix))
                        }
                    } else {
                        ix = x1 + u * (x2 - x1)
                        iy = y1 + u * (y2 - y1)
                        return CLLocationDistance(abs(lineMagnitude(x1: px, y1: py, x2: ix, y2: iy)))
                    }
                    
                }
                
                let distance = distanceCurrentLocToSegment(p: currentLocation, p1: p1, p2: p2)
                
                // Closest distance comparison
                if distance < closestDistance {
                    closest = location
                    closestDistance = distance
                }
                
            }
            
        }
        
        return closest!
        
    }
    
    func updateRules(location: TimedParking) {
        
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        let hourBegin = Calendar.current.date(from: location.hoursBegin)
        let hourEnd = Calendar.current.date(from: location.hoursEnd)
        
        
        let text = String(location.hourLimit)
        durationParkingLabel.text = text
        let start = String(describing: location.hoursBegin.hour?.hours)
        let text2 = "8am - 6pm"
        print("\n\n\nlocation Hr LIMIT \(text)")
        print("\n\n\nlocation Hr BEGIN \(start)")
        print(text, text2)
        moveOutLabel.text = text2
        
        let hourLimit = TimeInterval(Double(location.hourLimit * 60 * 60))
        let date = Date(timeIntervalSinceNow: hourLimit)
        print(formatter.string(from: date))
        //    let component = Calendar.current.dateComponents(in: Calendar.current.timeZone, from: date)
        //    moveByTimingLabel.text = formatter.string(from: date)
        moveByTimingLabel.text = "10:00am"
        
    }
    
    
    
    //  func findNextTimedMove (nearestBlock: TimedParking) -> Date {
    //
    //    var solutionTime: DateComponents
    //    let userCalendar = Calendar.autoupdatingCurrent
    //    let date = Date()
    //    let calendar = Calendar.current
    //    let currentDateDC = userCalendar.dateComponents([.calendar, .day, .hour, .minute, .second, .weekday, .weekdayOrdinal], from: date)
    //    let todayHoursBegin = DateComponents(calendar: userCalendar, year: currentDateDC.year, month: currentDateDC.month, day: currentDateDC.day, hour: nearestBlock.hoursBegin.hour, minute: nearestBlock.hoursBegin.minute, weekday: currentDateDC.weekday, weekdayOrdinal: currentDateDC.weekdayOrdinal, quarter: currentDateDC.quarter, weekOfMonth: currentDateDC.weekOfMonth, weekOfYear: currentDateDC.weekOfYear, yearForWeekOfYear: currentDateDC.yearForWeekOfYear)
    //    let todayHoursEnd = DateComponents(calendar: userCalendar, year: currentDateDC.year, month: currentDateDC.month, day: currentDateDC.day, hour: nearestBlock.hoursEnd.hour, minute: nearestBlock.hoursEnd.minute, weekday: currentDateDC.weekday, weekdayOrdinal: currentDateDC.weekdayOrdinal, quarter: currentDateDC.quarter, weekOfMonth: currentDateDC.weekOfMonth, weekOfYear: currentDateDC.weekOfYear, yearForWeekOfYear: currentDateDC.yearForWeekOfYear)
    //
    //    let dateTodayHoursBegin = calendar.date(from: todayHoursBegin)
    //    let dateTodayHoursEnd = calendar.date(from: todayHoursEnd)
    //    var timeTillNextMove: DateComponents
    //
    //    switch nearestBlock.DoW {
    //    case .mondayThruFriday:
    //      switch currentDateDC.weekday! {
    //      case 1:
    //
    //      case 2, 3, 4, 5:
    //        if date < dateTodayHoursBegin! {
    //          timeTillNextMove = dateTodayHoursBegin! - date
    //          timeTillNextMove.hour = timeTillNextMove.hour! + nearestBlock.hourLimit
    //        } else if date > dateTodayHoursBegin! && date < dateTodayHoursEnd! {
    //          timeTillNextMove = calendar.dateComponents(in: userCalendar.timeZone, from: date)
    //          timeTillNextMove.hour = timeTillNextMove.hour! + nearestBlock.hourLimit
    //        } else if date > dateTodayHoursEnd! {
    //          timeTillNextMove = calendar.
    //        }
    //      case 6:
    //
    //      case 7:
    //
    //      default:
    //        print("Not valid gregorian calendar")
    //        break
    //      }
    //    case .mondayThruSaturday:
    //
    //    case .mondayThruSunday:
    //    }
    //
    //    return solutionTime
    //  }
    
    
} // View controller ends here!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!


func getUniqueValues (theData: [TimedParking]) -> [String] {
    
    // Find which type was requested
    
    //  switch type {
    //
    //  case .daysOfWeek:
    
    var uniqueValues = [theData[0].days]
    
    for block in theData {
        
        var test: Bool = false
        
        for value in uniqueValues {
            
            if block.days == value {
                
                test = true
                
            }
        }
        if test == false {
            uniqueValues.append(block.days)
        }
    }
    
    return uniqueValues
    
    //  case .hoursBegin:
    //
    //    var uniqueValues = [formatter.string(from: theData[0].hoursBegin)]
    //
    //    for block in theData {
    //
    //      var test: Bool = false
    //
    //      for value in uniqueValues {
    //
    //        if block.hoursBegin == value {
    //
    //          test = true
    //
    //        }
    //      }
    //      if test == false {
    //        uniqueValues.append()
    //      }
    //    }
    //
    //    return [uniqueValues]
    //
    //  case .hoursEnd:
    //    var uniqueValues = [theData[0].hoursEnd.date]
    //
    //  case .timeLimit:
    //    var uniqueValues = [theData[0].hours]
}
