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


// Global variable for all timed parking data
var AllTimedParkingData = [TimedParking]()

class ViewController: UIViewController, MKMapViewDelegate {
  
  @IBOutlet weak var mapView: MKMapView!
  
  @IBOutlet weak var TimedTimeLabel: UILabel!
  
  
  var locationManager = CLLocationManager()
  let showAlert = UIAlertController()
  
  func locationManager(manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    print("\n\n Location Manager updated \n\n")
    let location = locations.last!
    let coordinateRegion = MKCoordinateRegionMakeWithDistance(location.coordinate, 500, 500)
    mapView.setRegion(coordinateRegion, animated: true)
    locationManager.stopUpdatingLocation()
  }
  

  
  func locationManager(manager: CLLocationManager, didChangeAuthorizationStatus status: CLAuthorizationStatus) {
    
    
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
  
  func locationManager(manager: CLLocationManager, didFailWithError error: NSError) {
    print("Failed to initialize GPS: ", error.description)
  }
  
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
    
    
    // load JSON in background 
    // show progress thing
    // When backlground process is done 
    // hide progress thing
    // Show data...
    readJSON(from: "TimedParkingData.geojson")
    
    print("\n\n\n\n Total Number of Data Points in Timed Parking Data: \(AllTimedParkingData.count)\n\n\n\n\n")
    
    // Create all of the Lines
    
    //    var index = 0
    //    for i in AllTimedParkingData {
    //      index += 1
    //      if i.geometry.count > 2 {
    //        print("\n\nElement: \(index)\nData: \(i.geometry)\n\n")
    //      }
    //    }
    
    guard let location = locationManager.location else {
      print("No location Tassos?")
      return 
    }
    
    let currentBlock = findNearestBlock(currentLocation: location)
    
    
    //    let renderer = MKPolylineRenderer(polyline: currentBlock.line!)
    
    //    renderer.fillColor = UIColor.green
    
    mapView.delegate = self
    
    mapView.showsCompass = true
    mapView.showsPointsOfInterest = true
    mapView.showsUserLocation = true
    mapView.showsBuildings = true
    //    mapView.layer.cornerRadius = 20.0
    
    mapView.add(currentBlock.line!, level: MKOverlayLevel.aboveLabels)
    
    //    AllTimedParkingData.map { park in
    //
    //      mapView.add(park.line!, level: MKOverlayLevel.aboveLabels)
    //
    //    }
    
    print("\n\n\n", currentBlock.id, currentBlock.geometry, "\n\n\n")
    
    print(currentBlock.line ?? "\n\n no line value \n\n")
    
    print(currentBlock.mapRect ?? "\n\n no mapRect value \n\n")
    
    let edge = UIEdgeInsets(top: 100, left: 100, bottom: 100, right: 100)
    
    mapView.setVisibleMapRect(currentBlock.mapRect!, edgePadding: edge, animated: true)
    
    //    mapView.addOverlays(currentBlock.line! as MKOverlay, level: MKOverlayLevel.aboveRoads)
    
    //    print("\n\n All unique values for days of the week \(getUniqueValues(theData: AllTimedParkingData)).\n\n\n")
    
    //    print("\n\n\n\(AllTimedParkingData[0].geometry)\n\n\n")
    
   
    
  }
  
  
  
  
  func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
    
    let polylineRenderer = MKPolylineRenderer(overlay: overlay)
    polylineRenderer.strokeColor = UIColor.green
    polylineRenderer.lineWidth = 5
    return polylineRenderer
    
  }
  
  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    // Dispose of any resources that can be recreated.
  }
}

extension ViewController: CLLocationManagerDelegate {
  func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
    if status == .authorizedWhenInUse {
      locationManager.requestLocation()
    }
  }
  //This function calls back when the information of the location comes back.
  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    if let location = locations.first {
      let span = MKCoordinateSpanMake(0.05, 0.05)
      let region = MKCoordinateRegionMake(location.coordinate, span)
      mapView.setRegion(region, animated: true)
    }
  }
  //to check if there is an error
  func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    print(error.localizedDescription)
  }
}

func readJSON(from file: String) {
  
  let fileComponents = file.components(separatedBy: ".")
  
  let path = Bundle.main.path(forResource: fileComponents[0], ofType: fileComponents[1])
  
  let text = try! String(contentsOfFile: path!) // read as string
  
  let json = try! JSONSerialization.jsonObject(with: text.data(using: .utf8)!, options: []) as? [String: Any]
  //  print(json!)
  
  let json2 = JSON(json!)
  
  let allData = json2["features"].arrayValue
  
  AllTimedParkingData = allData.map({ (entry: JSON) -> TimedParking in
    return TimedParking(json: entry)
  })
  
  
  
  //  let json = try! JSONSerialization.jsonObject(with: text.data(using: .utf8)!, options: []) as? [String: Any]
  //  print(json)
  
}

func findNearestBlock(currentLocation: CLLocation) -> TimedParking {
  
  var closest: TimedParking?
  var closestDistance: CLLocationDistance = CLLocationDistance(99999999)
  
  
  for location in AllTimedParkingData {
    if location.geometry.count > 1 {
      //    Based on actual line
      
      let x2 = location.geometry[1].longitude
      let x1 = location.geometry[0].longitude
      let y2 = location.geometry[1].latitude
      let y1 = location.geometry[0].latitude
      
      let dx = x2 - x1
      let dy = y2 - y1
      
      let slope = dx / dy
      
      let p1 = CLLocation(latitude: y1, longitude: x1)
      
      let p2 = CLLocation(latitude: y2, longitude: x2)
      
      let segDist = p1.distance(from: p2)
      
      //    let yInt = y1 - (slope * x1)
      
      
      
      func distanceCurrentLocToSegment(p: CLLocation, p1: CLLocation, p2: CLLocation) -> CLLocationDistance {
        
        let x1 = p1.coordinate.longitude
        let x2 = p2.coordinate.longitude
        let y1 = p1.coordinate.latitude
        let y2 = p2.coordinate.latitude
        
        var ix: Double = 0
        var iy: Double = 0
        
        // Find magnitude of line segment
        func lineMagnitude (x1: Double, y1: Double, x2: Double, y2: Double) -> Double {
          return CLLocationDistance(abs(sqrt(pow((x2-x1), 2) + pow((y2-y1), 2))))
        }
        
        let lineMag = lineMagnitude(x1: x1, y1: y1, x2: x2, y2: y2)
        
        if lineMag < 0.00000001 {
          print("short segment")
          return CLLocationDistance(abs(9999))
        }
        
        let px = p.coordinate.longitude
        let py = p.coordinate.latitude
        
        // Find distance "u"
        var u = (((px - x1) * (x2 - x1)) + ((py - y1) * (y2 - y1)))
        u = u / (lineMag * lineMag)
        
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
      
      print("\n\n\n", "Current Distance: ", distance, "\n", "Closest Distance: ", closestDistance)
      
      if distance < closestDistance {
        closest = location
        closestDistance = distance
      }
      
      //    if location.midPoint != nil {
      //      let distance = currentLocation.distance(from: location.midPoint!)
      //      //      CLLocationDistance(sqrt((pow((Double(()), 2) - pow(Double(currentLocation.coordinate.latitude), 2))))
      //
      //      if distance < closestDistance {
      //        closestDistance = distance
      //        closest = location
      //      }
      //    }
      
      
      //    Based on midpoint
      
      //    if location.midPoint != nil {
      //      let distance = currentLocation.distance(from: location.midPoint!)
      //
      //      if distance < closestDistance {
      //        closestDistance = distance
      //        closest = location
      //      }
      //    }
    }
    
  }
  
  return closest!
  
}

func distance (pointA: CLLocation, pointB: CLLocation) -> CLLocationDistance {
  
  let distance: CLLocationDistance = pointB.distance(from: pointA)
  
  return distance
}

func findNextTimedMove (nearestBlock: TimedParking) -> Date {
  
  var solutionTime = Date()
  let date = Date()
  let calendar = Calendar.current
  
  if calendar.isDateInWeekend(date) {
    
    
    
  }
  
  return solutionTime
}

enum UniqueValuesType: Int {
  case daysOfWeek, hoursBegin, hoursEnd, timeLimit
}

//func getDOWUniqueValues (theData: [TimedParking], type: UniqueValuesType) -> [String] {
//
//  // Find which type was requested
//
//  switch type {
//
//  case .daysOfWeek:
//
//    var uniqueValues = [theData[0].days]
//
//    for block in theData {
//
//      var test: Bool = false
//
//      for value in uniqueValues {
//
//        if block.days == value {
//
//          test = true
//
//        }
//      }
//      if test == false {
//        uniqueValues.append(block.days)
//      }
//    }
//
//    return uniqueValues
//
//  case .hoursBegin:
//
//
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
//  }
//
//
////  let testLine: MKPolyline = MKPolyline.init(coordinates: AllTimedParkingData[0].geom, count: AllTimedParkingData[0].geom.count)
//
//
//
//
//
//}
