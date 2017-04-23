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
      print("didSet in Active Street called")
      guard (activeStreet != nil) else {
        // TODO: Remove any active timer
        // Update all the string values
        moveByText = "_ _:_ _ _ _"
        timedParkingRule = "   "
        timedParkingTimes = "   "
        return
      }
      
      // Update the moveByTime
      self.updateMoveBy()
      
      // Update the timedParkingRule Text
      let formatter = DateFormatter()
      formatter.dateStyle = .short
      formatter.timeStyle = .short
      formatter.dateFormat = "h a"
      self.timedParkingRule = String(describing: self.activeStreet?.limit) + "hr parking"
      
      // Update the timedParkingTimes
      let start = String(describing: self.activeStreet?.hoursBegin.hour!)
      let end = String(describing: self.activeStreet?.hoursEnd.hour!)
      self.timedParkingTimes = "\(start)am - \(hourNightPM(hour: Int(end)!))pm"
    
    }
  }
  
  var moveByComponent: DateComponents?
  var moveByTime: Date?
  var moveByDate: Day?
  var moveByText: String? = "   "
  var timedParkingRule: String? = "   "
  var timedParkingTimes: String? = "   "
  var timer: Timer?
  
  init(activeStreet: TimedParking) {
    self.activeStreet = activeStreet
    // Update the moveByTime
    self.updateMoveBy()
    
    // Update the timedParkingRule Text
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .short
    formatter.dateFormat = "h"
    self.timedParkingRule = String(activeStreet.limit) + "hr parking " + activeStreet.days
    
    // Update the timedParkingTimes
    let startDate = Calendar.current.date(bySetting: .hour, value: activeStreet.hoursBegin.hour!, of: Date())
    let endDate = Calendar.current.date(bySetting: .hour, value: activeStreet.hoursEnd.hour!, of: Date())
    let start = formatter.string(for: startDate!)
    let end = formatter.string(for: endDate!)
    self.timedParkingTimes = "\(start!)am - \(end!)pm"

  }
  
  @objc func updateMoveBy() {
    
    // Get the user's calendar
    let calendar = Calendar.current
    
    // Get today
    let today = Date()
    
    // Create today component
    var todayComp = calendar.dateComponents(in: calendar.timeZone, from: today)
    
    // Update component for next minute update time for timer
    todayComp.minute? += 1
    todayComp.second = 0
    
    // Start the timer for future updating
    self.timer = Timer(fireAt: calendar.date(from: todayComp)!, interval: TimeInterval(60), target: self, selector: #selector(updateMoveBy), userInfo: nil, repeats: true)
    
    // Create a date formatter
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .short
    formatter.dateFormat = "E' @ 'h:mm a"
    
    // Get the enum of today's DoW
    let todayDay = getDayOfWeek(date: today)
    
    // See if today's DoW is in the parking
    if isDayInDayRange(day: todayDay, range: (self.activeStreet?.DoW)!){
      
      // The start of today
      let midnightThisMorning = calendar.startOfDay(for: today)
      
      // The time this morning the hours begin
      let todayHoursBegin = calendar.date(bySettingHour: (self.activeStreet?.hoursBegin.hour)!, minute: (self.activeStreet?.hoursBegin.minute)!, second: 0, of: today)
      
      // This is the begin time plus the hour limit
      let todayHoursBeginSoft = calendar.date(byAdding: .hour, value: (self.activeStreet?.limit)!, to:todayHoursBegin!)
      
      // The time today the rule hours end
      let todayHoursEnd = calendar.date(bySettingHour: (self.activeStreet?.hoursEnd.hour)!, minute: (self.activeStreet?.hoursEnd.minute)!, second: 0, of: today)
      
      // This is the end time minus the hour limit
      let todayHoursEndSoft = todayHoursEnd?.addingTimeInterval(-(self.activeStreet?.hourLimit)!)
      
      // The end of today
      let midnightTonight = calendar.date(byAdding: DateComponents(day: 1), to: midnightThisMorning)
      
      // TODO: Is today's time in the rule times?
      
      // If midnightMorning < Today < HoursBegin
      if today > midnightThisMorning && today < todayHoursBegin! {
        
        // Set moveby to park till HoursBeginSoft
        setMoveByValues(date: todayHoursBeginSoft!)
        
      // If HoursBegin < Today < HoursEndSoft
      } else if today > todayHoursBegin! && today < todayHoursEndSoft! {
        
        // Set moveby to park till today + HourLimit
        let time = today.addingTimeInterval((self.activeStreet?.hourLimit)!)
        setMoveByValues(date: time)

        // If HoursEndSoft < Today < HoursEnd
      } else if today > todayHoursEndSoft! && today < todayHoursEnd! {
        
        // Is the current DoW the last in the rules day range?
        if isDayEndOfDayRange(day: todayDay, range: (self.activeStreet?.DoW)!) == true {
          
          // Set moveby to park to monday at HoursBegin
          let component = DateComponents(hour: self.activeStreet?.self.hoursBegin.hour, minute: activeStreet?.hoursBegin.minute, weekday: 2)
          let time = calendar.nextDate(after: today, matching: component, matchingPolicy: .nextTime)
          setMoveByValues(date: time!)
          
        } else {
          
          // Set moveby to park till tomorrow at HoursBegin
          self.moveByDate = getDayOfWeek(date: today)
          self.moveByTime = today.addingTimeInterval((self.activeStreet?.hourLimit)!)
          self.moveByComponent = calendar.dateComponents(in: calendar.timeZone, from: self.moveByTime!)
          self.moveByText = formatter.string(from: self.moveByTime!)
          
        }
      } else if today > todayHoursEnd! && today < midnightTonight! {
        
        // Is the current DoW the last in the rules day range?
        if isDayEndOfDayRange(day: todayDay, range: (self.activeStreet?.DoW)!) == true {
          
          // Set the moveBy... values to monday hours begin plus hour limit
          let component = DateComponents(hour: (self.activeStreet?.hoursBegin.hour)! + (self.activeStreet?.limit)!, minute: self.activeStreet?.hoursBegin.minute, weekday: 2)
          let time = calendar.nextDate(after: today, matching: component, matchingPolicy: .nextTime)
          setMoveByValues(date: time!)
          
        } else {
          
          // Set moveby to park till tomorrow at HoursBeginSoft
          let time = calendar.date(byAdding: .day, value: 1, to: todayHoursBeginSoft!)
          setMoveByValues(date: time!)
          
        }
      }
    // If not in the day range, must be on the weekend, therefore...
    } else {
      
      // Set the moveBy... values to monday hours begin plus hour limit
      let component = DateComponents(hour: (self.activeStreet?.hoursBegin.hour)! + (self.activeStreet?.limit)!, minute: self.activeStreet?.hoursBegin.minute, weekday: 2)
      let time = calendar.nextDate(after: today, matching: component, matchingPolicy: .nextTime)
      setMoveByValues(date: time!)
      
    }
  }
  
  // Sets all the Move By Values from a given date
  func setMoveByValues(date: Date) {
    
    // Get the user's calendar
    let calendar = Calendar.current
    
    // Create a date formatter
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .short
    formatter.dateFormat = "E' @ 'h:mm a"
    
    // Set the move-by values
    self.moveByDate = getDayOfWeek(date: date)
    self.moveByTime = date
    self.moveByComponent = calendar.dateComponents(in: calendar.timeZone, from: date)
    self.moveByText = formatter.string(from: self.moveByTime!)
    
  }
}
