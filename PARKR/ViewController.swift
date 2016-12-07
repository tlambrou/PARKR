//
//  ViewController.swift
//  PARKR
//
//  Created by Tassos Lambrou on 11/17/16.
//  Copyright © 2016 SsosSoft. All rights reserved.
//

import UIKit
import MapKit
import CoreLocation
import Alamofire
import SwiftyJSON
import Darwin



var AllTimedParkingData = [TimedParking]()

class ViewController: UIViewController, MKMapViewDelegate {
  
  @IBOutlet weak var mapView: MKMapView!
  
  @IBOutlet weak var TimedTimeLabel: UILabel!
  
  
  var locationManager = CLLocationManager()
  let showAlert = UIAlertController()
  
  
  
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
    
    
    let currentBlock = findNearestBlock(currentLocation: locationManager.location!)
    
    
       
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
    
    let distance = sqrt((pow((location.midPoint?.latitude)!, 2) - pow(currentLocation.coordinate.latitude, 2)))
    
    if distance < closestDistance {
      closestDistance = distance
      closest = location
    }
    
  }
  
  return closest!

}

func findNextTimedMove (nearestBlock: TimedParking) -> Date {
  
  var solutionTime = Date()
  let date = Date()
  let calendar = Calendar.current
  
  if calendar.isDateInWeekend(date) {
    
    
    
  }
  
  return solutionTime
}


func getAllUniqueValues (theData: [TimedParking]) -> [String] {
  
  var uniqueValues: [String] = [theData[0].days]
  
  for block in theData {
    
    var counter: Int = 0
    
    for value in uniqueValues {
  
      if block.days != value {
        
      }
    }
    
    
    
  }
  
  return uniqueValues
}
