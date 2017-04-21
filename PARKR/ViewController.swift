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

extension MKMapView {
  func topLeftCoordinate() -> CLLocationCoordinate2D {
    return convert(CGPoint.zero, toCoordinateFrom: self)
  }
  
  func bottomRightCoordinate() -> CLLocationCoordinate2D {
    return convert(CGPoint(x: frame.width, y: frame.height), toCoordinateFrom: self)
  }
}


enum UniqueValuesType: Int {
  case daysOfWeek, hoursBegin, hoursEnd, timeLimit
}


// Global variable for all timed parking data
var AllTimedParkingData = [TimedParking]()

class ViewController: UIViewController, MKMapViewDelegate, CLLocationManagerDelegate {
  
  var limit: Int = 0
  
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
  
  @IBAction func parkHereAction(_ sender: UIButton) {
    
    self.performSegue(withIdentifier: "moveTimerSegue", sender: nil)
    
  }
  
  
  var locationManager = CLLocationManager()
  
  let showAlert = UIAlertController()
  
  enum ruleType { case timed, metered, towAway, streetCleaning, permit }
  
  enum renderTypes { case active, inactive }
  
  var renderer: renderTypes = .active
  
  
  // Redraw all of the nearby lines...
  
  enum modeTypes { case automatic, manual }
  
  var mode: modeTypes = .automatic
  
  var lastUpdated = Date(timeIntervalSinceNow: -20)
  var currentUpdated = Date(timeIntervalSinceNow: -20)
  var updateIndex = 0
  
  // MARK: - Location Manager Function
  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    

    currentUpdated = Date()
    
    if currentUpdated.timeIntervalSince(lastUpdated) > 10 {
      
      updateIndex += 1
      
      print("\n\n Location Manager updated!!!!!!!!! \n\n")
      
      // TODO: If automatic mode...
      //    mapView.setUserTrackingMode(MKUserTrackingMode.follow, animated: false)
      
      // Make sure location is not nil
      guard let location = locations.first else {
        print("No location!")
        return
      }
      
      
      // Find all of the nearest blocks within a threshhold...
      
//      print("\n\nLocation: ", location.coordinate, "\n\n")
      
      //    let subset = findLinesInMapView() // Old method (loading all the data)
      
      let newRegion = MKCoordinateRegionMakeWithDistance(location.coordinate, 70, 70)
      
//      print("\n\nHere is the region: ", newRegion)
      
      mapView.setRegion(newRegion, animated: true)
      
      lastUpdated = Date()
      
    }
    
  }
  
  func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
    
    print("\n\nThe mapView Updated!\n\n")
    
    let location = locationManager.location
    
    let newRegion = MKCoordinateRegionForMapRect(mapView.visibleMapRect)
    
    callAPI(parkingType: .timed, mapRegion: newRegion)
    
    let subset = AllTimedParkingData
    
//    print("\n\nSubset in didUpdateLocations: \(subset.count)")
    
    // Make sure to see if location is in SF and if not display a message --NEEDS TESTING
    guard subset.count > 0
      else {
        print("No Timed Parking Nearby")
        geocodingLabel.text = "No SF Data Nearby"
        //        let newRect = MKMapRect(origin: MKMapPointForCoordinate(location.coordinate), size: (AllTimedParkingData[0].mapRect?.size)!)
        //        let edge = UIEdgeInsets(top: 100, left: 100, bottom: 100, right: 100)
        //        mapView.setVisibleMapRect(newRect, edgePadding: edge, animated: false)
        return
    }
    
    // MARK: - Find Nearest block
    // Find the nearest block among all of the nearest blocks...
    
    let currentBlock = findNearestBlock(data: subset, currentLocation: location!)  // This is with the old method (all the data being loaded)
    
    print("CURRENT DoW: \(currentBlock.DoW!)")
    print("DAYS: \(currentBlock.days)")
    print("Hrs Begin: \(currentBlock.hoursBegin.hour)")
    print("Hrs End: \(currentBlock.hoursEnd.hour)")
    print("Hrs Limit: \(currentBlock.hourLimit)")
    
    // Create a composite rect of both the new coordinates and the selected block...
    let coordRect = MKMapRect(origin: MKMapPointForCoordinate((location?.coordinate)!), size: (currentBlock.mapRect?.size)!)
    let newRect = MKMapRectUnion(coordRect, currentBlock.mapRect!)
    let edge = UIEdgeInsets(top: 100, left: 100, bottom: 100, right: 100)
    mapView.setVisibleMapRect(newRect, edgePadding: edge, animated: false)
    
    
    
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
    
    updateReverseGeoCoding(location: location!)
    
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
      print("\n\nLocation services have been set to be always authorized\n\n")
      locationManager.startUpdatingLocation()
    }
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    findParking()
    let sfCenter = CLLocationCoordinate2D(latitude: 37.756940, longitude: -122.444338)
    
    let sfRegion = MKCoordinateRegionMakeWithDistance(sfCenter, 13800, 13800)
    
    mapView.setRegion(sfRegion, animated: false)
    
    
    //    longPress()
    //    readJSON(from: "TimedParkingData.geojson")
    
    
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
    
    guard locationManager.location != nil else {
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
  
  // MARK: - Make an API call
  func callAPI(parkingType: ruleType, mapRegion: MKCoordinateRegion){
    
    print("\n\nBegin loading parking data...\n\n")
    
    // Show progress bar
    //    let progressBar = UILabel()
    //    progressBar.text = "Loading..."
    //    progressBar.textColor = UIColor.darkGray
    //    progressBar.font = UIFont.boldSystemFont(ofSize: 18)
    //    progressBar.sizeToFit()
    //    self.mapView.addSubview(progressBar)
    
    //    DispatchQueue.global().async {
    
    let url = self.formURL(parkingType: parkingType, mapRegion: mapRegion)
    
    //    print(url)
    
    let headers = ["X-App-Token" : "ABbe1ilwKeO9XX4PVSSuSqqH6"]
    
    Alamofire.request(url, headers: headers).validate(contentType: ["application/json"]).responseJSON() { response in
//      debugPrint(response)
//      print(response.request)  // original URL request
//      print(response.response) // HTTP URL response
//      print(response.data)     // server data
//      print(response.result)   // result of response serialization
      
      
      switch response.result {
      case .success:
        if let value = response.result.value {
          
//          print("\nHere is value: ", value)
          let json = JSON(value)
//          print("\nHere is json: \n\n", json)
          
          let allData = json.arrayValue
          
//          print("\nWe got a response!\n\n", allData, "\n\n")
          
          let allTimedParking = allData.map({ (entry: JSON) -> TimedParking in
//            print("\n\nEntry: ", entry)
            return TimedParking(json: entry)
          })
          
          AllTimedParkingData.append(contentsOf: allTimedParking)
          
//          print("\n\nResponse: ", response.data)
          
//          print("\n\nHere is suppose to be the data: ", allTimedParking)
          
          
        } else {
          print("\n\nSuccess but no data somehow!\n\n")
        }
      case .failure(let error):
        print("\n\nWe got an error in the API call! Uh oh!!\n\n", error)
        
      }
    }
    
    //      DispatchQueue.main.async {
    print("\n\nDone loading parking data...\n\n")
    
    // Hide progress
    //    progressBar.removeFromSuperview()
    
    //Continue after the background thread to findParking()
//    self.findParking()
    
    //      }
    //
    //    }
    
    
  }
  
  func formURL(parkingType: ruleType, mapRegion: MKCoordinateRegion) -> String {
    switch parkingType {
    case .timed:
      
//      let regionCoord  = MKCoordinateRegionForMapRect(mapRect)
      let lat = mapRegion.center.latitude
      let long = mapRegion.center.longitude
      let spanLat = mapRegion.span.latitudeDelta
      let spanLong = mapRegion.span.longitudeDelta
      let spanConstant = CLLocationDegrees(0.005)
      
      
      return "https://data.sfgov.org/resource/2ehv-6arf.json?$where=within_box(geom%2C%20" + String(lat) + "%2C%20" + String(long) + "%2C%20" + String(lat + spanConstant) + "%2C%20" + String(long + spanConstant) + ")"
      
      //      return "https://data.sfgov.org/resource/2ehv-6arf.json?$where=within_box(geom%2C%2037.774479%2C%20-122.420319%2C%2037.771975%2C%20-122.415174)"
      
    default:
      return ""
    }
    
  }
  
  // MARK: - Read JSON
  func readJSON(from file: String) {
    
    print("\n\nBegin loading parking data...\n\n")
    
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
        print("\n\nDone loading parking data...\n\n")
        
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
  
  func outputDataToFile() {
    
    let fileName = "Output.swift"
    
    let filePath = "/Users/Tassos/Desktop/Academics/Make School/Product Academy/PD - Cities/PARKR/PARKR" + fileName
    
    let file = FileHandle(forWritingAtPath: filePath)
    
//    print(file ?? "default for file")
    
    if file != nil {
      // Set the data we want to write
      
      let data1 = AllTimedParkingData[0]
      var test = [TimedParking]()
//      print(test)
      test = [TimedParking(days: "M-F", hoursBegin: DateComponents(hour: 8, minute: 0), hoursEnd: DateComponents(hour: 17, minute: 0), hourLimit: 2, id: 4193, geometry: [CLLocationCoordinate2D(latitude: CLLocationDegrees(37.773406362670492), longitude: CLLocationDegrees(-122.4179728411779)), CLLocationCoordinate2D(latitude: CLLocationDegrees(37.773124891577787), longitude: CLLocationDegrees(-122.4174969850627))]), TimedParking(days: "M-F", hoursBegin: DateComponents(hour: 8, minute: 0), hoursEnd: DateComponents(hour: 17, minute: 0), hourLimit: 2, id: 4193, geometry: [CLLocationCoordinate2D(latitude: CLLocationDegrees(37.773406362670492), longitude: CLLocationDegrees(-122.4179728411779)), CLLocationCoordinate2D(latitude: CLLocationDegrees(37.773124891577787), longitude: CLLocationDegrees(-122.4174969850627))])]
      
      let data = ("[TimedParking(days: \"\(data1.days)\", hoursBegin: DateComponents(hour: \(data1.hoursBegin.hour), minute: \(data1.hoursBegin.minute)), hoursEnd: DateComponents(hour: \(data1.hoursEnd.hour), minute: \(data1.hoursEnd.minute)), hourLimit: \(data1.hourLimit), id: \(data1.id), geometry: [CLLocationCoordinate2D(latitude: CLLocationDegrees(\(data1.geometry[0].latitude)), longitude: CLLocationDegrees(\(data1.geometry[0].longitude))), CLLocationCoordinate2D(latitude: CLLocationDegrees(\(data1.geometry[1].latitude)), longitude: CLLocationDegrees(\(data1.geometry[1].longitude)))])]").data(using: String.Encoding(rawValue: String.Encoding.utf8.rawValue))
      
//      print(data!)
      
      // Append to the end of the file
      file?.seekToEndOfFile()
      
      // Write it to the file
      file?.write(data!)
      
      // Close the file
      file?.closeFile()
    }
    else {
      print("Ooops! Something went wrong!")
    }
    
    
  }
  
  // MARK: - Nearest Line
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
  
  
  
  // MARK: - Update rules
  func updateRules(location: TimedParking) {
    
    
    let hourLimit = TimeInterval(Double(location.hourLimit * 60 * 60))
    let date = Date(timeIntervalSinceNow: hourLimit)
    
    checkMoveByDatePassed(date: date, location: location)
    
    let formatter = DateFormatter()
    formatter.timeStyle = .short
    let hourBegin = Calendar.current.date(from: location.hoursBegin)
    let hourEnd = Calendar.current.date(from: location.hoursEnd)
    
    let text = String(location.hourLimit)
    
    durationParkingLabel.text = "\(text) hr parking"
    let start = String(describing: location.hoursBegin.hour!)
    let end = String(location.hoursEnd.hour!)
    let text2 = "\(start)am - \(hourNightPM(hour: Int(end)!))pm"
    limit = location.hourLimit
    
    moveOutLabel.text = text2
    
    checkMoveByDatePassed(date: date, location: location)
    //    let component = Calendar.current.dateComponents(in: Calendar.current.timeZone, from: date)
    //    moveByTimingLabel.text = formatter.string(from: date)
    moveByTimingLabel.text = "\(formatter.string(from: date))"
    
    
  }
  
  //// MARK: - Update rules
  //func updateRules(location: TimedParking) {
  //
  //  let formatter = DateFormatter()
  //  formatter.timeStyle = .short
  //  print("\n\nHours Begin: ", location.hoursBegin, "\n\n")
  //
  //
  //  let hourBegin = Calendar.current.date(from: location.hoursBegin)
  //  let hourEnd = Calendar.current.date(from: location.hoursEnd)
  //
  //
  //  let text = String(location.hourLimit)
  //  durationParkingLabel.text = "\(text) hr parking"
  //  let start = String(describing: location.hoursBegin.hour!)
  //  let end = String(location.hoursEnd.hour!)
  //  let text2 = "\(start)am - \(hourNightPM(hour: Int(end)!))pm"
  //  limit = location.hourLimit
  //  print("LIMIT: \(limit)")
  //  moveOutLabel.text = text2
  //
  //  let hourLimit = TimeInterval(Double(location.hourLimit * 60 * 60))
  //  let date = Date(timeIntervalSinceNow: hourLimit)
  //  print("FORMATTER : \(formatter.string(from: date))")
  //  //    let component = Calendar.current.dateComponents(in: Calendar.current.timeZone, from: date)
  //  //    moveByTimingLabel.text = formatter.string(from: date)
  //  moveByTimingLabel.text = "\(formatter.string(from: date))"
  //
  //}
  
  func hourNightPM(hour: Int) -> String {
    if hour > 12 {
      return String(hour - 12)
    } else {
      return String(hour)
    }
  }
  
  func checkMoveByDatePassed(date: Date, location: TimedParking) {
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "hh:mm"
    
    let calendar = Calendar.current
    let componentMinute = calendar.component(.minute, from: date)
    let componentHour = calendar.component(.hour, from: date)
    
    let minute = componentMinute.minute
    let hour = componentHour.hour
    
//    print("****** HOUR: \(minute.minute!)")
  }
  
  //    // MARK: - Update rules
  //    func updateRules(location: TimedParking) {
  //
  //
  //        let hourLimit = TimeInterval(Double(location.hourLimit * 60 * 60))
  //        let date = Date(timeIntervalSinceNow: hourLimit)
  //
  //        let checkLocation = checkMoveByDatePassed(date: date, location: location)
  //
  //        let formatter = DateFormatter()
  //        formatter.timeStyle = .short
  ////        let hourBegin = Calendar.current.date(from: location.hoursBegin)
  ////        let hourEnd = Calendar.current.date(from: location.hoursEnd)
  //
  //        let text = String(checkLocation.hourLimit)
  //
  //        durationParkingLabel.text = "\(text) hr parking"
  //        let start = String(describing: checkLocation.hoursBegin.hour!)
  //        let end = String(checkLocation.hoursEnd.hour!)
  //        let text2 = "\(start)am - \(hourNightPM(hour: Int(end)!))pm"
  //        limit = checkLocation.hourLimit
  //
  //        moveOutLabel.text = text2
  //
  //        let calendar = Calendar.current
  //        let components = calendar.dateComponents([.hour, .minute], from: date)
  //        print("DATE*******: \(date)")
  //
  //        //    let component = Calendar.current.dateComponents(in: Calendar.current.timeZone, from: date)
  //        //    moveByTimingLabel.text = formatter.string(from: date)
  //        moveByTimingLabel.text = "\(components.hour!): \(components.minute!)"
  //
  //    }
  //
  //    // if moveby hour > endlimit.hour && moveby minute > endlimit.minute: hour begin am else return regular
  //
  //    if hour.hour! > location.hoursEnd.hour! && hour.minute! > location.hoursEnd.minute! {
  //      location.hourLimit = location.hoursEnd.hour! - location.hoursBegin.hour!
  //
  //      func checkMoveByDatePassed(date: Date, location: TimedParking) -> TimedParking {
  //        let dateFormatter = DateFormatter()
  //        dateFormatter.dateFormat = "hh:mm"
  //
  //        let calendar = Calendar.current
  //        let componentMinute = calendar.component(.minute, from: date)
  //        let componentHour = calendar.component(.hour, from: date)
  //
  //        let minute = componentMinute.minute
  //        let hour = componentHour.hour
  //
  //
  //        // if moveby hour > endlimit.hour && moveby minute > endlimit.minute: hour begin am else return regular
  //        print("HOUR: \(hour.hour!)")
  //        print("LOCATION Hrs end \(location.hoursEnd.hour!)")
  //
  //        print("MINUTE: \(minute.minute!)")
  //        print("LOCATION min end \(location.hoursEnd.minute!)")
  //
  //        if hour.hour! >= location.hoursEnd.hour! && minute.minute! > location.hoursEnd.minute! {
  //            location.hourLimit = hour.hour! - location.hoursBegin.hour!
  //            return location
  //        } else {
  //            return location
  //        }
  //
  //    }
  //
  //  }
  
  override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
    if segue.identifier == "moveTimerSegue" {
      let timerView: TimerViewController = segue.destination as! TimerViewController
      timerView.viewControllerInstance = self
    }
  }
}


//// MARK: - Unique Values
//func getUniqueValues (theData: [TimedParking]) -> [String] {
//
//    // Find which type was requested
//
//    //  switch type {
//    //
//    //  case .daysOfWeek:
//
//    var uniqueValues = [theData[0].days]
//
//    for block in theData {
//
//        var test: Bool = false
//
//        for value in uniqueValues {
//
//            if block.days == value {
//
//                test = true
//
//            }
//        }
//        if test == false {
//            uniqueValues.append(block.days)
//        }
//    }
//
//    return uniqueValues
//
//}
