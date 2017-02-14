//
//  Coordinates.swift
//  PARKR
//
//  Created by Tassos Lambrou on 11/28/16.
//  Copyright © 2016 SsosSoft. All rights reserved.
//

import Foundation
import SwiftyJSON
import UIKit
import MapKit

class Coordinates {
  
  var latitude: CLLocationDegrees?
  var longitude: CLLocationDegrees?
  //  var coordinates: CLLocationCoordinate2D?
  
  init(json: JSON) {
    
    let coordArray = json.arrayValue
    
    self.latitude = CLLocationDegrees(String(describing: coordArray[1]))!
    self.longitude = CLLocationDegrees(String(describing: coordArray[0]))!
    //    self.coordinates?.latitude =
  }
}
