//
//  DateUtilities.swift
//  PARKR
//
//  Created by Tassos Lambrou on 1/10/17.
//  Copyright © 2017 SsosSoft. All rights reserved.
//

import Foundation

enum Day {
  case sunday, monday, tuesday, wednesday, thursday, friday, saturday
}

enum DayRange {
  case mondayThruFriday, mondayThruSaturday, mondayThruSunday
}


func getDayOfWeek(date: Date) -> Day {
  let myCalendar = Calendar(identifier: .gregorian)
  let weekDay = myCalendar.component(.weekday, from: date)
  switch weekDay {
  case 1:
    return .sunday
  case 2:
    return .monday
  case 3:
    return .tuesday
  case 4:
    return .wednesday
  case 5:
    return .thursday
  case 6:
    return .friday
  case 7:
    return .saturday
  default:
    return .sunday
  }
}

func isDayEndOfDayRange(day: Day, range: DayRange) -> Bool {
  switch range {
  case .mondayThruFriday:
    switch day {
    case .sunday:
      return false
    case .monday:
      return false
    case .tuesday:
      return false
    case .wednesday:
      return false
    case .thursday:
      return false
    case .friday:
      return true
    case.saturday:
      return false
    }
  case .mondayThruSaturday:
    switch day {
    case .sunday:
      return false
    case .monday:
      return false
    case .tuesday:
      return false
    case .wednesday:
      return false
    case .thursday:
      return false
    case .friday:
      return false
    case.saturday:
      return true
    }
  case .mondayThruSunday:
    switch day {
    case .sunday:
      return true
    case .monday:
      return false
    case .tuesday:
      return false
    case .wednesday:
      return false
    case .thursday:
      return false
    case .friday:
      return false
    case.saturday:
      return false
    }
  }

}

func isDayInDayRange(day: Day, range: DayRange) -> Bool {
  switch range {
  case .mondayThruFriday:
    switch day {
    case .sunday:
      return false
    case .monday:
      return true
    case .tuesday:
      return true
    case .wednesday:
      return true
    case .thursday:
      return true
    case .friday:
      return true
    case.saturday:
      return false
    }
  case .mondayThruSaturday:
    switch day {
    case .sunday:
      return false
    case .monday:
      return true
    case .tuesday:
      return true
    case .wednesday:
      return true
    case .thursday:
      return true
    case .friday:
      return true
    case.saturday:
      return true
    }
  case .mondayThruSunday:
    switch day {
    case .sunday:
      return true
    case .monday:
      return true
    case .tuesday:
      return true
    case .wednesday:
      return true
    case .thursday:
      return true
    case .friday:
      return true
    case.saturday:
      return true
    }
  }
}

func +(_ lhs: DateComponents, _ rhs: DateComponents) -> DateComponents {
  return combineComponents(lhs, rhs)
}

func -(_ lhs: DateComponents, _ rhs: DateComponents) -> DateComponents {
  return combineComponents(lhs, rhs, multiplier: -1)
}

func combineComponents(_ lhs: DateComponents,
                       _ rhs: DateComponents,
                       multiplier: Int = 1)
  -> DateComponents {
    var result = DateComponents()
    result.second     = (lhs.second     ?? 0) + (rhs.second     ?? 0) * multiplier
    result.minute     = (lhs.minute     ?? 0) + (rhs.minute     ?? 0) * multiplier
    result.hour       = (lhs.hour       ?? 0) + (rhs.hour       ?? 0) * multiplier
    result.day        = (lhs.day        ?? 0) + (rhs.day        ?? 0) * multiplier
    result.weekOfYear = (lhs.weekOfYear ?? 0) + (rhs.weekOfYear ?? 0) * multiplier
    result.month      = (lhs.month      ?? 0) + (rhs.month      ?? 0) * multiplier
    result.year       = (lhs.year       ?? 0) + (rhs.year       ?? 0) * multiplier
    return result
}

// (Previous code goes here)

prefix func -(components: DateComponents) -> DateComponents {
  var result = DateComponents()
  if components.second     != nil { result.second     = -components.second! }
  if components.minute     != nil { result.minute     = -components.minute! }
  if components.hour       != nil { result.hour       = -components.hour! }
  if components.day        != nil { result.day        = -components.day! }
  if components.weekOfYear != nil { result.weekOfYear = -components.weekOfYear! }
  if components.month      != nil { result.month      = -components.month! }
  if components.year       != nil { result.year       = -components.year! }
  return result
}

// Date + DateComponents
func +(_ lhs: Date, _ rhs: DateComponents) -> Date
{
  return Calendar.current.date(byAdding: rhs, to: lhs)!

}

// DateComponents + Dates
func +(_ lhs: DateComponents, _ rhs: Date) -> Date
{
  return rhs + lhs
}

// Date - DateComponents
func -(_ lhs: Date, _ rhs: DateComponents) -> Date
{
  return lhs + (-rhs)
}

// Extending Date so that creating dates is simpler
extension Date {
  
  init(year: Int,
       month: Int,
       day: Int,
       hour: Int = 0,
       minute: Int = 0,
       second: Int = 0,
       timeZone: TimeZone = TimeZone(abbreviation: "UTC")!) {
    var components = DateComponents()
    components.year = year
    components.month = month
    components.day = day
    components.hour = hour
    components.minute = minute
    components.second = second
    components.timeZone = timeZone
    self = Calendar.current.date(from: components)!
  }
  
  init(dateString: String) {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss zz"
    self = formatter.date(from: dateString)!
  }
  
}

// Overloading - so that we can use it to find the difference between two Dates
func -(_ lhs: Date, _ rhs: Date) -> DateComponents
{
  return Calendar.current.dateComponents([.year, .month, .day, .hour, .minute],
                                         from: lhs,
                                         to: rhs)
}


// Extending Int to add some syntactic magic to date components
extension Int {
  
  var second: DateComponents {
    var components = DateComponents()
    components.second = self;
    return components
  }
  
  var seconds: DateComponents {
    return self.second
  }
  
  var minute: DateComponents {
    var components = DateComponents()
    components.minute = self;
    return components
  }
  
  var minutes: DateComponents {
    return self.minute
  }
  
  var hour: DateComponents {
    var components = DateComponents()
    components.hour = self;
    return components
  }
  
  var hours: DateComponents {
    return self.hour
  }
  
  var day: DateComponents {
    var components = DateComponents()
    components.day = self;
    return components
  }
  
  var days: DateComponents {
    return self.day
  }
  
  var week: DateComponents {
    var components = DateComponents()
    components.weekOfYear = self;
    return components
  }
  
  var weeks: DateComponents {
    return self.week
  }
  
  var month: DateComponents {
    var components = DateComponents()
    components.month = self;
    return components
  }
  
  var months: DateComponents {
    return self.month
  }
  
  var year: DateComponents {
    var components = DateComponents()
    components.year = self;
    return components
  }
  
  var years: DateComponents {
    return self.year
  }
  
}

// Extending DateComponents to add even more syntactic magic: fromNow and ago
extension DateComponents {
  
  var fromNow: Date {
    return Calendar.current.date(byAdding: self,
                                 to: Date())!
  }
  
  var ago: Date {
    return Calendar.current.date(byAdding: -self,
                                 to: Date())!
  }
  
}
