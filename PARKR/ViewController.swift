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


class ViewController: UIViewController, MKMapViewDelegate {
  
  @IBOutlet weak var mapView: MKMapView!
  
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
    // Do any additional setup after loading the view, typically from a nib.
    
    locationManager.delegate = self
    locationManager.desiredAccuracy = kCLLocationAccuracyBest
    //Triggers the location permission dialog.
    locationManager.requestWhenInUseAuthorization()
    locationManager.requestLocation()
    
    mapView.delegate = self
    mapView.showsUserLocation = true
    mapView.userTrackingMode = .followWithHeading
    
    let headers = ["X-App-Token" : "ABbe1ilwKeO9XX4PVSSuSqqH6"]
    
    
    
    Alamofire.request("https://data.sfgov.org/resource/2ehv-6arf.json?%24select=days%2Chours_begin%2Chours_end%2Chour_limit%2Cgeom&%24where=within_circle(geom%2C%2037.791827%2C%20-122.408477%2C%20200)", headers: headers).validate().responseJSON() { response in
      debugPrint(response)
      
      switch response.result {
      case .success:
        if let value = response.result.value {
          let json = JSON(value)
          
          let allData = json.arrayValue
          
          let allTimedParking: [TimedParking] = allData.map({ (entry: JSON) -> TimedParking in
            return TimedParking(json: entry)
          })
          
          print(allTimedParking)
          
          
          
          
        }
      case .failure(let error):
        print(error)
      }
    }
    
    
    
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

