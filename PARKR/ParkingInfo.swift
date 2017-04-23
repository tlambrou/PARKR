//
//  ParkingInfo.swift
//  PARKR
//
//  Created by Tassos Lambrou on 4/22/17.
//  Copyright © 2017 SsosSoft. All rights reserved.
//

import Foundation
import MapKit

class ParkingInfo {
  
  var activeStreet: TimedParking? {
    didSet {
      
    }
  }
  var moveByTime: DateComponents?
  var moveByDate: Day?
  var moveByText: String?
  var timedParkingRule: String?
  var timedParkingTimes: String?
  
  init(activeStreet: TimedParking) {
    self.activeStreet = activeStreet
  }
  
}
