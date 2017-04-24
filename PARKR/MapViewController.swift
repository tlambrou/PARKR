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

// MARK: Extensions
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

// MARK: Enum Declarations
enum uniqueValuesType: Int { case daysOfWeek, hoursBegin, hoursEnd, timeLimit }
enum modeTypes { case automatic, manual }
enum ruleType { case timed, metered, towAway, streetCleaning, permit }
enum renderTypes { case active, inactive }

// Global variable for all timed parking data
var AllTimedParkingData = [TimedParking]()

class MapViewController: UIViewController, MKMapViewDelegate, CLLocationManagerDelegate {
  
  // MARK: - IBOutlet Declarations
  @IBOutlet weak var LoadingView: UIView!
  @IBOutlet weak var moveByTimingLabel: UILabel!
  // This label located down right corner
  @IBOutlet weak var moveOutLabel: UILabel!
  // This label located down left corner
  @IBOutlet weak var durationParkingLabel: UILabel!
  @IBOutlet weak var geocodingLabel: UILabel!
  @IBOutlet weak var mapView: MKMapView!
  @IBOutlet weak var TimedTimeLabel: UILabel!
  @IBOutlet weak var parkHereButton: UIButton!
  @IBAction func parkHereAction(_ sender: UIButton) {
    self.performSegue(withIdentifier: "moveTimerSegue", sender: nil)
  }
  
  // MARK: - Var Declarations
  var touchPoint: CGPoint!
  var touchPointCoordinate: CLLocationCoordinate2D!
  var annotation = MKPointAnnotation()
  var locationManager = CLLocationManager()
  let showAlert = UIAlertController()
  var renderer: renderTypes = .active
  var locationLastUpdated = Date(timeIntervalSinceNow: -20)
  var locationCurrentUpdated = Date(timeIntervalSinceNow: -20)
  var locationUpdateIndex = 0
  var loading: Bool = true
  var mode: modeTypes = .automatic
  
  // This variable represents the active parking displayed in the view at any point
  // MARK: Active Parking
  var activeParking: ParkingInfo? {
    didSet {
      
      print("didSet in activeParking called")
      
      // Update the labels
      self.moveByTimingLabel.text = activeParking?.moveByText
      self.durationParkingLabel.text = activeParking?.timedParkingRule
      self.moveOutLabel.text = activeParking?.timedParkingTimes
      
      if activeParking?.activeStreet == nil {
        
        // Park Here button becomes disabled
        parkHereButton.adjustsImageWhenDisabled = true
        parkHereButton.isUserInteractionEnabled = false
        
      } else {
        
        // Park Here button becomes enabled
        parkHereButton.isUserInteractionEnabled = true
        
      }
    }
  }
  
  
  // MARK: - Location Manager Function
  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    
  }
  
  func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
    
  }
  
  func mapView(_ mapView: MKMapView, didUpdate userLocation: MKUserLocation) {
    
    // Create a counter of how many updates have been done
    locationUpdateIndex += 1
    
    // Create time upon entering for comparison
    locationCurrentUpdated = Date()
    
    print("\n\nmapView did Update user location: \(locationUpdateIndex)\nMode: \(mode)\nLoading? - \(loading)\n\n")
    
    // If the data is done loading...
    if loading == false {
      
      // Call the main update function
      updateFromLocationChange()
      
    }
    
    // Grab the time upon leaving the last update call
    locationLastUpdated = Date()
  }
  
  // MARK: Update From Location Method
  func updateFromLocationChange() {
    
    print("updateFromLocationChange Called | Last called \(locationCurrentUpdated.timeIntervalSince(locationLastUpdated))")

    
    // Make sure location is not nil
    guard let location = locationManager.location else{
      print("\n\nNo location in the updateFromLocationChange function!!\n\n")
      return
    }
    
    // Check to see whether in manual or automatic mode
    switch mode {
      
    // If in automatic mode...
    case .automatic:
      
      // Check to see if the time since the last update was greater than threshold
      if locationCurrentUpdated.timeIntervalSince(locationLastUpdated) > TimeInterval(2.0) {
        
        print("Did update location called!")
        print("\n\n Location Manager updated!!!!!!!!! \(locationUpdateIndex)\n\n")
        
        // Create a variable for centering the map on the user's current location
        let center = CLLocationCoordinate2D(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
        
        // Set the mapView's center
        self.mapView.setCenter(center, animated: true)
        print("\n\nThe mapView Center Updated! \nLoading is \(loading)\nHere is the camera height: \(mapView.camera.altitude)\n\n")
        
        // Initialize the the subset
        let subset = findSubsetForMapView()
        
        print("\n\nSubset in didUpdateLocations: \(subset.count)")
        
        // Make sure to see if location is in SF and if not display a message
        guard subset.count > 0
          else {
            print("No Timed Parking Nearby")
            geocodingLabel.text = "No Data On This Street"
            return
        }
        
        // Find the nearest block among all of the nearest blocks...
        let currentBlock = findNearestBlock(data: subset, currentLocation: location)
        
        print(activeParking?.moveByText as Any, activeParking?.timedParkingRule as Any, activeParking?.timedParkingTimes as Any, activeParking?.activeStreet as Any, separator: " ______ ", terminator: " | ")
        
        // Detect if User is out of range
        // Create a circle around the current location to see if the closest data intersects with the circle
        let radius = CLLocationDistance(24)
        let circle = MKCircle(center: (location.coordinate), radius: radius)
        let intersecting = MKMapRectIntersectsRect(circle.boundingMapRect, currentBlock.mapRect!)
        
        // If the current block is within 24 meters of the user's locatio
        if intersecting {
          // Update the reverse geocoding...
          updateReverseGeoCoding(location: location)
          // Otherwise if street is not within the threshold of the 24 meters
        } else {
          print("No Parking Data for this street")
          geocodingLabel.text = "No Data On This Street"
        }
        
        // Paint all these polylines as disabled
        for line in subset {
          
          renderer = .inactive
          self.mapView.add(line.line!)
          
        }
        
        // Paint the active line as active
        renderer = .active
        self.mapView.add(currentBlock.line!, level: MKOverlayLevel.aboveLabels)
        renderer = .inactive
        
//        // Update all of the rules and times...
//        updateRules(location: currentBlock)
        
      }
      
    // If in manual mode...
    case .manual:
      
      break
      
    }
  }
  
  func updateCenter() {
    
    
    
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
    
    initializeMapView()
    //    longPress()
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
      //      touchPoint = gestureRecognizer.location(in: self.mapView)
      //      touchPointCoordinate = self.mapView.convert(touchPoint, toCoordinateFrom: self.mapView)
      //      let center = self.mapView.center
      // create an annotation
      //      annotation.coordinate = touchPointCoordinate
      //      self.mapView.addAnnotation(annotation)
      
      
    }
  }
  
  // MARK: - Find Parking func
  func initializeMapView() {
    
    print("\n\nInitialized MapView called\n\n")
    
    // Initialize the MapView
    mapView.delegate = self
    mapView.showsCompass = true
    mapView.showsPointsOfInterest = true
    mapView.isPitchEnabled = false
    mapView.showsUserLocation = true
    mapView.showsBuildings = true
    mapView.setUserTrackingMode(MKUserTrackingMode.follow, animated: true)

    // Set the delegate
    locationManager.delegate = self
    
    // Start updating the user's location
    locationManager.startUpdatingLocation()
    
    // Edit the my location annotation
    mapView.userLocation.title = "You are here"
    
    // Make sure there is a user location and if not center the map on SF
    guard let location = locationManager.location else {
      print("No location")
      let cityCenter = CLLocationCoordinate2DMake(CLLocationDegrees(37.756940), CLLocationDegrees(-122.444338))
      let region = MKCoordinateRegionMakeWithDistance(cityCenter, 1350, 1350)
      mapView.setRegion(region, animated: false)
      return
    }
    
    // Initialize the mapView's region with center at current location
    let center = CLLocationCoordinate2D(latitude: (location.coordinate.latitude), longitude: (location.coordinate.longitude))
    let region = MKCoordinateRegionMakeWithDistance(center, 160, 160)
    mapView.setRegion(region, animated: true)
    
  }
  
  // Method that updates the Reverse GeoCoding Text
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
      polylineRenderer.strokeColor = #colorLiteral(red: 0, green: 0.902623508, blue: 0.7324799925, alpha: 1)
      polylineRenderer.lineWidth = 5
    case .inactive:
      polylineRenderer.strokeColor = #colorLiteral(red: 0.1764705926, green: 0.01176470611, blue: 0.5607843399, alpha: 1)
      polylineRenderer.lineWidth = 3
    }
    
    return polylineRenderer
    
  }
  
  // MARK: - Make an API call
  func callAPI(parkingType: ruleType, mapRegion: MKCoordinateRegion){
    
    print("\n\nBegin loading parking data...\n\n")
    
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
          
        } else {
          print("\n\nSuccess but no data somehow!\n\n")
        }
      case .failure(let error):
        print("\n\nWe got an error in the API call! Uh oh!!\n\n", error)
        
      }
    }
  }
  
  // Function that forms API URL for call
  func formURL(parkingType: ruleType, mapRegion: MKCoordinateRegion) -> String {
    switch parkingType {
    // For Timed Parking...
    case .timed:
      
      let lat = mapRegion.center.latitude
      let long = mapRegion.center.longitude
      let spanConstant = CLLocationDegrees(0.001)
      
      // Return formed URL
      return "https://data.sfgov.org/resource/2ehv-6arf.json?$where=within_box(geom%2C%20" + String(lat) + "%2C%20" + String(long) + "%2C%20" + String(lat + spanConstant) + "%2C%20" + String(long + spanConstant) + ")"
      
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
    
    // Create a background thread
    DispatchQueue.global().async {
      
      // Get the filename and remove the extension
      let fileComponents = file.components(separatedBy: ".")
      
      // Get the path to the file
      let path = Bundle.main.path(forResource: fileComponents[0], ofType: fileComponents[1])
      
      // Read file as text
      let text = try! String(contentsOfFile: path!) // read as string
      
      // Serialization
      let json = try! JSONSerialization.jsonObject(with: text.data(using: .utf8)!, options: []) as? [String: Any]
      
      // Deserialize as JSON
      let json2 = JSON(json!)
      
      // Begin parsing JSON
      let allData = json2["features"].arrayValue
      
      // Map each JSON entry to a model objects
      AllTimedParkingData = allData.map({ (entry: JSON) -> TimedParking in
        return TimedParking(json: entry)
      })
      
      // Return from asyncrhonous data import
      DispatchQueue.main.async {
        print("\n\nDone loading parking data... \(AllTimedParkingData.count)\n\n")
        
        // Finished loading
        self.loading = false
        
        // Create time upon entering for comparison
        self.locationCurrentUpdated = Calendar.current.date(byAdding: .second, value: -20, to: Date())!
        
        // Call update on Parking from Location Update
        print("About to call updateFromLocationChange")
        self.updateFromLocationChange()
        
        // Make Park Here button interactable and enabled
        self.parkHereButton.isEnabled = true
        self.parkHereButton.isUserInteractionEnabled = true
        
        // Hide Loading View and progress bar
        self.LoadingView.isHidden = true
        progressBar.removeFromSuperview()
        
      }
    }
  }
  
  // MARK: - Nearest Line
  func findSubsetForMapView() -> [TimedParking] {
    
    var subset = [TimedParking]()
//    print(AllTimedParkingData[10].line?.coordinate as Any)
    for location in AllTimedParkingData {
      if (location.line?.intersects(mapView.visibleMapRect))! {
        subset.append(location)
      }
    }
    return subset
  }
  
  // Find Nearby lines to location
  func findSubset(currentLocation: CLLocation) -> [TimedParking] {
    
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
  
  // MARK: Find Nearest Block function
  func findNearestBlock(data: [TimedParking], currentLocation: CLLocation) -> TimedParking {
    
    print("\n\nFindNearestBlock Called")
    
    var closest: TimedParking?
    var closestDistance: CLLocationDistance = CLLocationDistance(99999999)
    
    // Iterate through all the data
    for location in data {
      
      // As long as there is more than one point in the line string...
      if location.geometry.count > 1 {
        
        // Create point coordinates for location in the data
        let x2 = location.geometry[1].longitude
        let x1 = location.geometry[0].longitude
        let y2 = location.geometry[1].latitude
        let y1 = location.geometry[0].latitude
        
        // Convert points to CLLocation
        let p1 = CLLocation(latitude: y1, longitude: x1)
        let p2 = CLLocation(latitude: y2, longitude: x2)
        
        // Distance of Current Location to Segment Call
        let distance = distanceCurrentLocToSegment(p: currentLocation, p1: p1, p2: p2)
        
        // Closest distance comparison
        if distance < closestDistance {
          closest = location
          closestDistance = distance
        }
      }
    }
    
    print("Hrs Begin \(String(describing: closest?.hoursBegin))")
    print("Hrs End \(String(describing: closest?.hoursEnd))")
    print("Hrs Limit \(String(describing: closest?.hourLimit))")
    
    // Update the Active Parking Variable - Should trigger didSet in activeParking
    guard ((activeParking = ParkingInfo(activeStreet: closest!)) != nil) else{
      print("Closest failed to set activeParking.activeStreet for some reason")
      return closest!
    }
    
    print(String(describing: activeParking?.activeStreet?.limit), String(describing: closest?.limit))
    
    return closest!
  }
  
  // Determine closest distance between a point and a line defined by 2 points
  func distanceCurrentLocToSegment(p: CLLocation, p1: CLLocation, p2: CLLocation) -> CLLocationDistance {
    
    // Create point coordinates for longitude & latitude
    let x1 = p1.coordinate.longitude
    let x2 = p2.coordinate.longitude
    let y1 = p1.coordinate.latitude
    let y2 = p2.coordinate.latitude
    var ix: Double = 0
    var iy: Double = 0
    
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
  
  // Function to find magnitude of line segment
  func lineMagnitude (x1: Double, y1: Double, x2: Double, y2: Double) -> Double {
    return CLLocationDistance(abs(sqrt(pow((x2-x1), 2) + pow((y2-y1), 2))))
  }
  
  
  // MARK: - Update rules
  func updateRules(location: TimedParking) {
    
    // Get the datetime of now
    let now = Date()
    
    let formatter1 = DateFormatter()
    print(formatter1.string(from: location.hoursBegin.fromNow))
    
    // Get the day of the week for the current date
    let nowDay = getDayOfWeek(date: now)
    
    // Is current day in the day range for current block's rules?
    if isDayInDayRange(day: nowDay, range: location.DoW!) == true {
    } else {
      
    }
    
    
    
    let hourLimit = TimeInterval(Double(location.hourLimit * 60 * 60))
    let date = Date(timeIntervalSinceNow: hourLimit)
    
    checkMoveByDatePassed(date: date, location: location)
    
    let formatter = DateFormatter()
    formatter.timeStyle = .short
    //    let hourBegin = Calendar.current.date(from: location.hoursBegin)
    //    let hourEnd = Calendar.current.date(from: location.hoursEnd)
    
    let text = String(location.hourLimit)
    
    durationParkingLabel.text = "\(text) hr parking"
    let start = String(describing: location.hoursBegin.hour!)
    let end = String(location.hoursEnd.hour!)
    let text2 = "\(start)am - \(hourNightPM(hour: Int(end)!))pm"
    
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
  
  func checkMoveByDatePassed(date: Date, location: TimedParking) {
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "hh:mm"
//    
//    let calendar = Calendar.current
//    let componentMinute = calendar.component(.minute, from: date)
//    let componentHour = calendar.component(.hour, from: date)
    
//    let minute = componentMinute.minute
//    let hour = componentHour.hour
    
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
