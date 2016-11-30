//
//  Coordinates.swift
//  PARKR
//
//  Created by Tassos Lambrou on 11/28/16.
//  Copyright © 2016 SsosSoft. All rights reserved.
//

import Foundation
import SwiftyJSON

class Coordinates {
  let latitude: Float
  let longitude: Float
  
  init(json: JSON) {
    
    let coordArray = json.arrayValue
    
    self.latitude = coordArray[0].floatValue
    self.longitude = coordArray[1].floatValue
  }
}
