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


private extension MKPolyline {
  convenience init(coordinates coords: Array<CLLocationCoordinate2D>) {
    let unsafeCoordinates = UnsafeMutablePointer<CLLocationCoordinate2D>.allocate(capacity: coords.count)
    unsafeCoordinates.initialize(from: coords)
    self.init(coordinates: unsafeCoordinates, count: coords.count)
    unsafeCoordinates.deallocate(capacity: coords.count)
  }
}

var AllTimedParkingData = [TimedParking]()

class ViewController: UIViewController, MKMapViewDelegate {
  
  @IBOutlet weak var mapView: MKMapView!
  
  @IBOutlet weak var TimedTimeLabel: UILabel!
  
  
  var locationManager = CLLocationManager()
  let showAlert = UIAlertController()
  
  func locationManager(manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    let location = locations.first!
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
    
    
    
    let currentBlock = findNearestBlock(currentLocation: locationManager.location!)
    
    //    let renderer = MKPolylineRenderer(polyline: currentBlock.line!)
    
    //    renderer.fillColor = UIColor.green
    
    mapView.delegate = self
    
    mapView.showsCompass = true
    mapView.showsPointsOfInterest = true
    mapView.showsUserLocation = true
    mapView.showsBuildings = true
    
    mapView.add(AllTimedParkingData[0].line!, level: MKOverlayLevel.aboveLabels)
    
//    AllTimedParkingData.map { park in
//    
//      mapView.add(park.line!, level: MKOverlayLevel.aboveLabels)
//
//    }
  
    
    
    
    print(AllTimedParkingData[0].line ?? "\n\n no line value \n\n")
    
    print(AllTimedParkingData[0].mapRect ?? "\n\n no mapRect value \n\n")
    
    mapView.setVisibleMapRect(AllTimedParkingData[0].mapRect!, animated: true)
    
    
    
    
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
    
//    Based on actual line
    
    
    if location.midPoint != nil {
      let distance = currentLocation.distance(from: location.midPoint!)
      //      CLLocationDistance(sqrt((pow((Double(()), 2) - pow(Double(currentLocation.coordinate.latitude), 2))))
      
      if distance < closestDistance {
        closestDistance = distance
        closest = location
      }
    }
    
    
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
