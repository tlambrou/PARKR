//
//  TimeParking.swift
//  PARKR
//
//  Created by Tassos Lambrou on 11/28/16.
//  Copyright © 2016 SsosSoft. All rights reserved.
//

import Foundation

import SwiftyJSON

class TimedParking {
  let days: String
  let hoursBegin: DateComponents
  let hoursEnd: DateComponents
  let hours: Int
  var geom: [Coordinates]
  var midPoint: Coordinates? = nil
  
  init(json: JSON) {
    
    let number:Double? = Double(json["properties"]["hours_begin"].intValue) / 100
    let timeBegin = (number ?? 0)
    print(timeBegin)
    let hourBegin = floor(timeBegin)
    print(hourBegin)
    
    var minuteBegin: Int
    if hourBegin == 0 {
      minuteBegin = 0
    } else {
      minuteBegin = Int((timeBegin.truncatingRemainder(dividingBy: hourBegin))*100)
    }
    
//    let string:string = "cheese"
//    if string.length == 4{
//      var output
//      for
//    }
    
    
    print(minuteBegin)
    let number2: Double? = Double(json["properties"]["hours_end"].intValue) / 100
    let timeEnd = number2 ?? 0
    let hourEnd = floor(timeEnd)
    
    var minuteEnd: Int
    if hourEnd == 0 {
      minuteEnd = 0
    } else {
      minuteEnd = Int((timeEnd.truncatingRemainder(dividingBy: hourEnd))*100)
    }
    
    
    self.days = json["properties"]["days"].stringValue
    self.hoursBegin = DateComponents(hour: Int(hourBegin), minute: minuteBegin)
    self.hoursEnd = DateComponents(hour: Int(hourEnd), minute: minuteEnd)
    self.hours = Int(json["properties"]["hour_limit"].stringValue) ?? 0
    self.geom = json["geometry"]["coordinates"].arrayValue.map { json in
      let coord = Coordinates(json: json)
      return coord
    }
    
    self.midPoint?.latitude = (self.geom[1].latitude - self.geom[0].latitude)/2
    self.midPoint?.longitude = (self.geom[1].longitude - self.geom[0].longitude)/2
    
    //    print("COORDS")
    //    for i in self.geom {
    //      print(i.latitude)
    //      print(i.longitude)
    //      print("\n\n")
    //    }
    
    //    self.name = json["im:name"]["label"].stringValue
    //    self.rightsOwner = json["rights"]["label"].stringValue
    //    self.price = Double(json["im:price"]["attributes"]["amount"].stringValue) ?? 0
    //    self.link = json["link"][0]["attributes"]["href"].stringValue
    //    self.image = json["im:image"][2]["label"].stringValue
    //    self.releaseDate = json["im:releaseDate"]["attributes"]["label"].stringValue
  }
}
