//
//  TimerViewController.swift
//  PARKR
//
//  Created by Buka Cakrawala on 1/11/17.
//  Copyright © 2017 SsosSoft. All rights reserved.
//

import UIKit
import UserNotifications

let notificationDelegate = PARKRNotificationDelegate()

class TimerViewController: UIViewController, UNUserNotificationCenterDelegate {
  
  var viewControllerInstance: MapViewController!
  
  var timer = Timer()
  var parkingRule: ParkingInfo?
  var counter = 0

  @IBOutlet weak var tenMinuteSwitch: UISwitch!
  @IBOutlet weak var fifteenMinuteSwitch: UISwitch!
  @IBOutlet weak var thirtyMinuteSwitch: UISwitch!
  
  @IBOutlet weak var hoursLabel: UILabel!
  @IBOutlet weak var minutesLabel: UILabel!
  @IBOutlet weak var secondsLabel: UILabel!
  @IBOutlet weak var moveByTimeLabel: UILabel!
  
  @IBAction func tenMinuteAction(_ sender: UISwitch) {
    if sender.isOn {
      tenMinuteSwitch.setOn(true, animated: true)
      scheduleNotification(minutes: 10, type: "10-minutes",  completion: { (success) in
        if success {
          print("successfully scheduled notification")
        } else {
          print("Error scheduling notification")
        }
      })
    } else if sender.isOn == false {
      tenMinuteSwitch.setOn(false, animated: true)
      UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["10-minutes"])
      
    }
  }
  
  @IBAction func fifteenMinuteAction(_ sender: UISwitch) {
    if sender.isOn {
      fifteenMinuteSwitch.setOn(true, animated: true)
      scheduleNotification(minutes: 15, type: "15-minutes", completion: { (success) in
        if success {
          print("successfully scheduled notification")
        } else {
          print("Error scheduling notification")
        }
      })
    } else if sender.isOn == false {
      tenMinuteSwitch.setOn(false, animated: true)
      UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["15-minutes"])
      
    }
  }
  @IBAction func thirtyMinuteAction(_ sender: UISwitch) {
    if sender.isOn {
      thirtyMinuteSwitch.setOn(true, animated: true)
      
      scheduleNotification(minutes: 30, type: "30-minutes",  completion: { (success) in
        if success {
          print("successfully scheduled notification")
        } else {
          print("Error scheduling notification")
        }
      })
    } else if sender.isOn == false {
      tenMinuteSwitch.setOn(false, animated: true)
      UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["30-minutes"])
      
    }
  }
 
  @IBAction func stopAction(_ sender: UIButton) {
    // TODO: Stop the timer
    timer.invalidate()
    
    viewControllerInstance.locationManager.startUpdatingLocation()
    UNUserNotificationCenter.current().removeAllPendingNotificationRequests()

    self.dismiss(animated: true, completion: nil)
  }
  
  
  @objc func updateTimer () {
//    counter -= 1
    let calendar = Calendar.current
    let f = DateFormatter()
    f.timeStyle = .short
    let interval = parkingRule?.moveByTime?.timeIntervalSinceNow
    let hours = Int(interval!) / 3600
    let minutes = Int(interval!) / 60 % 60
    let seconds = Int(interval!) % 60
    
    if hours < 0 || minutes < 0 || seconds < 0 {
      hoursLabel.text = String(format: "%02i",abs(hours) * -1)
    } else {
      hoursLabel.text = String(format: "%02i",abs(hours))
    }
    minutesLabel.text = String(format: "%02i",abs(minutes))
    secondsLabel.text = String(format: "%02i",abs(seconds))
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    viewControllerInstance.locationManager.stopUpdatingLocation()
    
    moveByTimeLabel.text = viewControllerInstance.activeParking?.moveByText
    
    counter = (Int((viewControllerInstance.activeParking?.moveByTime?.timeIntervalSince(Date()))!))
    
    timer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(updateTimer), userInfo: nil, repeats: true)
    
    self.configureNotification()
    
    tenMinuteSwitch.setOn(false, animated: true)
    
    // Schedule a 15 minute notification by default
    scheduleNotification(minutes: 15, type: "15-minutes", completion: { (success) in
      if success {
        print("successfully scheduled notification")
      } else {
        print("Error scheduling notification")
      }
    })
    fifteenMinuteSwitch.setOn(true, animated: true)
    thirtyMinuteSwitch.setOn(false, animated: true)
    // Do any additional setup after loading the view.
  }
  
  
  
  func configureNotification() {
    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { (success, error) in
      if success {
        print("notification access granted")
      } else {
        print(error?.localizedDescription as Any)
      }
    }
  }
  
  func scheduleNotification(minutes: Int, type: String, completion: @escaping (_ Success: Bool) -> ()) {
    let notif = UNMutableNotificationContent()
    let center = UNUserNotificationCenter.current()
    
//    let snoozeAction = UNNotificationAction(identifier: "Snooze",
//                                            title: "Snooze", options: [])
//    let deleteAction = UNNotificationAction(identifier: "UYLDeleteAction",
//                                            title: "Delete", options: [.destructive])
    
    notif.title = "PARKR"
    notif.subtitle = "Your parking expires in " + type + "!!!"
    notif.body = "Move your vehicle soon to avoid getting a ticket or towed!! 🚘 🎫 👮"
    notif.sound = UNNotificationSound.init(named: "flowerdove-alert.caf")
    
    let timeInterval = TimeInterval(minutes * 60)
    var newComponents = viewControllerInstance.activeParking?.moveByComponent
    newComponents?.minute = (newComponents?.minute)! - minutes
    
    let notificationTrigger = UNCalendarNotificationTrigger(dateMatching: newComponents!,
                                                            repeats: false)
    let request = UNNotificationRequest(identifier: type, content: notif, trigger: notificationTrigger)
    
    center.add(request) { (error) in
      if error != nil {
        print(error as Any)
        completion(false)
      } else {
        completion(true)
      }
    }
  }
  
  func userNotificationCenter(_ center: UNUserNotificationCenter,
                              willPresent notification: UNNotification,
                              withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
    // Play sound and show alert to the user
    completionHandler([.alert,.sound])
  }
  
  func userNotificationCenter(_ center: UNUserNotificationCenter,
                              didReceive response: UNNotificationResponse,
                              withCompletionHandler completionHandler: @escaping () -> Void) {
    
    // Determine the user action
    switch response.actionIdentifier {
    case UNNotificationDismissActionIdentifier:
      print("Dismiss Action")
    case UNNotificationDefaultActionIdentifier:
      print("Default")
    case "Snooze":
      print("Snooze")
    case "Delete":
      print("Delete")
    default:
      print("Unknown action")
    }
    completionHandler()
  }
  
}
