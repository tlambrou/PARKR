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

// MARK: Enum Declarations
enum ModeTypes { case automatic, manual }
enum RuleType { case timed, metered, towAway, streetCleaning, permit }
enum RenderTypes { case active, inactive }

let polyCoords = [CLLocationCoordinate2DMake(37.7068, -122.4281), CLLocationCoordinate2DMake(37.7068, -122.5048), CLLocationCoordinate2DMake(37.7835, -122.5158), CLLocationCoordinate2DMake(37.8108, -122.4062), CLLocationCoordinate2DMake(37.7287, -122.3569), CLLocationCoordinate2DMake(37.7068, -122.3898)]

let sanFranciscoPolygon = MKPolygon(coordinates: polyCoords, count: polyCoords.count)

// Global variable for all timed parking data
var AllTimedParkingData = [TimedParking]()

class MapViewController: UIViewController, MKMapViewDelegate, CLLocationManagerDelegate, UIGestureRecognizerDelegate {
    
    // MARK: - IBOutlet Declarations
    @IBOutlet weak var LoadingView: UIView!
    @IBOutlet weak var moveByTimingLabel: UILabel!
    // This label located down right corner
    @IBOutlet weak var moveOutLabel: UILabel!
    // This label located down left corner
    @IBOutlet weak var durationParkingLabel: UILabel!
    @IBOutlet weak var geocodingLabel: UILabel!
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var TimedTimeLabel: UILabel!
    @IBOutlet weak var parkHereButton: UIButton!
    @IBAction func parkHereAction(_ sender: UIButton) {
        self.performSegue(withIdentifier: "moveTimerSegue", sender: nil)
    }
    @IBOutlet weak var loadingAnimation: UIActivityIndicatorView!
    @IBOutlet weak var reticuleImage: UIImageView!
    @IBOutlet weak var automaticModeButton: UIButton!
    
    
    // MARK: - Var Declarations
    var touchPoint: CGPoint!
    var touchPointCoordinate: CLLocationCoordinate2D!
    var locationManager = CLLocationManager()
    let showAlert = UIAlertController()
    var renderer: RenderTypes = .active
    var locationLastUpdated = Date(timeIntervalSinceNow: -2)
    var locationCurrentUpdated = Date(timeIntervalSinceNow: -2)
    var locationUpdateIndex = 0
    var notifiedOfSFOnly: Bool = false
    var loading: Bool = true {
        didSet {
            
            // Create time upon entering for comparison
            self.locationCurrentUpdated = Calendar.current.date(byAdding: .second, value: -2, to: Date())!
            
            // Call update on Parking from Location Update
            self.updateFromLocationChange()
            
            self.loadingAnimation.stopAnimating()
            // Hide Loading View and progress bar
            self.LoadingView.isHidden = true
        }
        
    }
    var mode: ModeTypes = .automatic {
        didSet {
            switch mode {
            case .automatic:
                mapView.userTrackingMode = .follow
                mapView.setUserTrackingMode(.follow, animated: true)
                automaticModeButton.isEnabled = false
                automaticModeButton.isHidden = true
                reticuleImage.isHidden = true
            case .manual:
                mapView.userTrackingMode = .none
                mapView.setUserTrackingMode(.none, animated: true)
                automaticModeButton.isEnabled = true
                automaticModeButton.isHidden = false
                reticuleImage.isHidden = false
            }
        }
    }
    
    // This variable represents the active parking displayed in the view at any point
    // MARK: Active Parking
    var activeParking: ParkingInfo? {
        didSet {
            if activeParking?.activeStreet?.hourLimit == nil || activeParking?.activeStreet?.hoursBegin == nil || activeParking?.activeStreet?.hoursEnd == nil || activeParking?.activeStreet == nil {
                // Park Here button becomes disabled
                self.parkHereButton.adjustsImageWhenDisabled = true
                self.parkHereButton.titleShadowColor(for: .disabled)
                self.parkHereButton.isEnabled = false
                self.parkHereButton.isUserInteractionEnabled = false
                
                self.moveByTimingLabel.text = "_ _ : _ _ _ _"
                self.durationParkingLabel.text = "No Timed Parking"
                self.moveOutLabel.text = "Nearby"
                
            } else {
                
                // Make Park Here button interactable and enabled
                self.parkHereButton.isEnabled = true
                self.parkHereButton.isUserInteractionEnabled = true
                
                // Update the labels
                self.moveByTimingLabel.text = activeParking?.moveByText
                self.durationParkingLabel.text = activeParking?.timedParkingRule
                self.moveOutLabel.text = activeParking?.timedParkingTimes
                
                // Paint the active line as active
                renderer = .active
                self.mapView.add((activeParking?.activeStreet?.line!)!, level: MKOverlayLevel.aboveLabels)
                renderer = .inactive
            }
        }
    }
    
    // MARK: Subset var declaration
    var subset = [TimedParking]() {
        willSet {
            mapView.removeOverlays(mapView.overlays)
        }
        didSet {
            for (index, item) in subset.enumerated() {
                if item.hourLimit == nil || item.hoursBegin == nil || item.hoursEnd == nil {
                    subset.remove(at: index)
                }
            }
            
            for line in subset {
                renderer = .inactive
                self.mapView.add(line.line!)
            }
            
            var location: CLLocation
            
            switch mode {
            case .automatic:
                location = CLLocation(latitude: (locationManager.location?.coordinate.latitude)!, longitude: (locationManager.location?.coordinate.longitude)!)
                
            case .manual:
                location = CLLocation(latitude: (mapView.centerCoordinate.latitude), longitude: (mapView.centerCoordinate.longitude))
            }
            
            // Find the nearest block among all of the nearest blocks...
            let currentBlock = findNearestBlock(data: subset, currentLocation: location)
            
            // Detect if User is out of range
            // Create a circle around the current location to see if the closest data intersects with the circle
            let radius = CLLocationDistance(24)
            let circle = MKCircle(center: (location.coordinate), radius: radius)
            let intersecting = MKMapRectIntersectsRect(circle.boundingMapRect, currentBlock.mapRect!)
            
            // If the current block is within 24 meters of the user's locatio
            if intersecting {
                // Update the reverse geocoding...
                updateReverseGeoCoding(location: location)
                // Otherwise if street is not within the threshold of the 24 meters
            } else {
                geocodingLabel.text = "No Data On This Street"
                activeParking?.activeStreet = nil
            }
            
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        automaticModeButton.addTarget(self, action:#selector(setModeToAutomatic), for: .touchUpInside)
        
        // Load the data
        readJSON(from: "TimedParkingData.geojson")
        
        // Initialize the MapView
        initializeMapView()
        
        // Add pan gesture to detect when the map moves
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(self.didDragMap(_:)))
        
        // Make your class the delegate of the pan gesture
        panGesture.delegate = self
        
        // Add the gesture to the mapView
        mapView.addGestureRecognizer(panGesture)
    }
    
    // MARK: - Location Manager Function
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        
        locationManager.stopUpdatingLocation()
        
        // If the data is done loading...
        if loading == false {
            
            // Call the main update function
            updateFromLocationChange()
        }
        
        locationManager.startUpdatingLocation()
    }
    
    func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        switch mode {
        case .automatic:
            break
        case .manual:
            
            // Check to see if in San Francisco
            // If so check to see if nil because not in SF
            if sanFranciscoPolygon.intersects(mapView.visibleMapRect){
                
                // Initialize the new subset
                subset = findSubsetForMapView()
                // Make sure to see if location is in SF and if not display a message
                guard subset.count > 0 else {
                        geocodingLabel.text = "No Data On This Street"
                        return
                }
                // If not then collect first subset and draw the lines
            } else {
                
                activeParking?.activeStreet = nil
                geocodingLabel.text = "Not in San Francisco"
                
                if notifiedOfSFOnly == false {
                    let alert = UIAlertController(title: "You are not in San Francisco!", message: "Unfortunately PARKR is only available for drivers in San Francisco", preferredStyle: .alert)
                    let action = UIAlertAction(title: "Okay", style: .default)
                    alert.addAction(action)
                    self.present(alert, animated: true)
                    notifiedOfSFOnly = true
                }
                
            }
            // Get a new subset
            
            // Find the closest
            
            // Render closest
        }
    }
    
    func mapView(_ mapView: MKMapView, didUpdate userLocation: MKUserLocation) {}
    
    func mapViewDidFinishLoadingMap(_ mapView: MKMapView) {
        //    let trackingBarButton = MKUserTrackingBarButtonItem(mapView: mapView)
        //    trackingBarButton.title = "Update your location"
    }
    
    // MARK: Update From Location Method
    func updateFromLocationChange() {
        
        
        // Create a counter of how many updates have been done
        locationUpdateIndex += 1
        
        // Create time upon entering for comparison
        locationCurrentUpdated = Date()
        
        // Make sure location is not nil
        guard let location = locationManager.location else {return}
        
        // Check to see whether in manual or automatic mode
        switch mode {
            
        // If in automatic mode...
        case .automatic:
            
            // Check to see if the time since the last update was greater than threshold
            if locationCurrentUpdated.timeIntervalSince(locationLastUpdated) > TimeInterval(0.1) {
                
                // Create a variable for centering the map on the user's current location
                let center = location.coordinate
                
                // Set the mapView's center
                self.mapView.setCenter(center, animated: true)
                self.mapView.camera.altitude = 300
            }
            
            // Check to see if the time since the last update was greater than threshold
            if locationCurrentUpdated.timeIntervalSince(locationLastUpdated) > TimeInterval(2.0) {
                
                // Update the center
                // Create a variable for centering the map on the user's current location
                let center = location.coordinate
                
                // Set the mapView's center
                self.mapView.setCenter(center, animated: true)
                self.mapView.camera.altitude = 300
                
                
                // Grab the time view was last updated
                locationLastUpdated = Date()
                
                // If so check to see if nil because not in SF
                if sanFranciscoPolygon.intersects(mapView.visibleMapRect){
                    
                    // Initialize the the subset
                    subset = findSubsetForMapView()
                    // Make sure to see if location is in SF and if not display a message
                    guard subset.count > 0 else {
                        geocodingLabel.text = "No Data On This Street"
                        return
                    }
                    // If not then collect first subset and draw the lines
                } else {
                    
                    activeParking?.activeStreet = nil
                    geocodingLabel.text = "Not in San Francisco"
                    
                    if notifiedOfSFOnly == false {
                        let alert = UIAlertController(title: "You are not in San Francisco!", message: "Unfortunately PARKR is only available for drivers in San Francisco", preferredStyle: .alert)
                        let action = UIAlertAction(title: "Okay", style: .default)
                        alert.addAction(action)
                        self.present(alert, animated: true)
                        notifiedOfSFOnly = true
                    }
                }
                
                // Then collect the closest and draw it as well
                
                // Check if the last subset check was larger than threshold distance delta
                
                // If so, get a new subset and redraw the views
                
                // Calculate the closest
            }
            
        // If in manual mode...
        case .manual:
            break
        }
    }

    private func locationManager(manager: CLLocationManager, didChangeAuthorizationStatus status: CLAuthorizationStatus) {
        
        switch status {
        case .notDetermined:
            print("NotDetermined")
        case .restricted:
            print("Restricted")
        case .denied:
            print("Denied")
            let alert = UIAlertController(title: "Location Permission Denied", message: "You have not given permssion for PARKR to get your phone's location.  Please change this by going to Settings -> Privacy -> Location Services -> PARKR SF, and set to \"Always\"", preferredStyle: .alert)
            let action = UIAlertAction(title: "Okay", style: .default)
            alert.addAction(action)
            self.present(alert, animated: true)
            notifiedOfSFOnly = true
        case .authorizedAlways:
            print("AuthorizedAlways")
            locationManager.startUpdatingLocation()
        case .authorizedWhenInUse:
            print("AuthorizedWhenInUse")
            locationManager.startUpdatingLocation()
        }
    }
    
    private func locationManager(manager: CLLocationManager, didFailWithError error: NSError) {
        print("Failed to initialize GPS: ", error.description)
    }
    
    // MARK: - Application View life Cycle
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
    
    func setModeToAutomatic() {
        mode = .automatic
    }
    
    // Protocol method so gesture recognizer will work with the existing MKMapView gestures
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
    
    // Will be called by the selector in pan gesture
    func didDragMap(_ sender: UIGestureRecognizer) {
        if sender.state == .ended {
            mode = .manual
        }
    }
    
    func longPress() {
        let touch = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(gestureRecognizer:)))
        touch.minimumPressDuration = 0.1
        self.mapView.addGestureRecognizer(touch)
    }
    
    func handleLongPress(gestureRecognizer: UIGestureRecognizer) {
        // function to initialize the touch point, and drop the annotation pin into the mapview
        if gestureRecognizer.state != .began {
            return
        } else {
            //      touchPoint = gestureRecognizer.location(in: self.mapView)
            //      touchPointCoordinate = self.mapView.convert(touchPoint, toCoordinateFrom: self.mapView)
            //      let center = self.mapView.center
            // create an annotation
            //      annotation.coordinate = touchPointCoordinate
            //      self.mapView.addAnnotation(annotation)
        }
    }
    
    
    // MARK: - Find Parking func
    func initializeMapView() {
        
        // Initialize the MapView
        mapView.delegate = self
        mapView.isScrollEnabled = true
        mapView.isZoomEnabled = true
        mapView.showsCompass = true
        mapView.showsPointsOfInterest = true
        mapView.isPitchEnabled = false
        mapView.showsUserLocation = true
        mapView.showsBuildings = true
        mapView.setUserTrackingMode(MKUserTrackingMode.follow, animated: true)
        mapView.userTrackingMode = .follow
        
        
        // Set the delegate
        locationManager.delegate = self
        
        // Start updating the user's location
        locationManager.startUpdatingLocation()
        
        // Edit the my location annotation
        mapView.userLocation.title = "You are here"
        
        // Make sure there is a user location and if not center the map on SF
        guard let location = locationManager.location else {

            let cityCenter = CLLocationCoordinate2DMake(CLLocationDegrees(37.756940), CLLocationDegrees(-122.444338))
            let region = MKCoordinateRegionMakeWithDistance(cityCenter, 1350, 1350)
            mapView.setRegion(region, animated: false)
            
            return
        }
        
        // Initialize the mapView's region with center at current location
        let center = CLLocationCoordinate2D(latitude: (location.coordinate.latitude), longitude: (location.coordinate.longitude))
        let region = MKCoordinateRegionMakeWithDistance(center, 160, 160)
        mapView.setRegion(region, animated: true)
        
    }
    
    // Method that updates the Reverse GeoCoding Text
    func updateReverseGeoCoding(location: CLLocation) {
        // Update geocoding label with address based on location
        CLGeocoder().reverseGeocodeLocation(location) { (placemark, error) in
            if error != nil {
                print ("\n\nThere was an error geocoding\n\n")
            } else {
                if let place = placemark?[0] {
                    if place.subThoroughfare != nil {
                        self.geocodingLabel.text = "\(place.subThoroughfare!) \(place.thoroughfare!)\n\(place.locality!), \(place.administrativeArea!)"
                    }
                }
            }
        }
    }
    
    // MARK: - MapView Line Renderer
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        // if MKOverlayPathRenderer
        let polylineRenderer = MKPolylineRenderer(overlay: overlay)
        switch renderer {
        case .active:
            polylineRenderer.strokeColor = #colorLiteral(red: 0, green: 0.902623508, blue: 0.7324799925, alpha: 1)
            polylineRenderer.lineWidth = 5
        case .inactive:
            polylineRenderer.strokeColor = #colorLiteral(red: 0.1764705926, green: 0.01176470611, blue: 0.5607843399, alpha: 1)
            polylineRenderer.lineWidth = 3
        }
        
        return polylineRenderer
        
    }
    
    
    // Function that forms API URL for call
    func formURL(parkingType: RuleType, mapRegion: MKCoordinateRegion) -> String {
        switch parkingType {
        
        // For Timed Parking...
        case .timed:
            let lat = mapRegion.center.latitude
            let long = mapRegion.center.longitude
            let spanConstant = CLLocationDegrees(0.001)
            
            // Return formed URL
            return "https://data.sfgov.org/resource/2ehv-6arf.json?$where=within_box(geom%2C%20" + String(lat) + "%2C%20" + String(long) + "%2C%20" + String(lat + spanConstant) + "%2C%20" + String(long + spanConstant) + ")"
        default:
            return ""
        }
        
    }
    
    // MARK: - Read JSON
    func readJSON(from file: String) {
        // Show progress bar
        let progressBar = UILabel()
        progressBar.text = "Loading..."
        progressBar.textColor = UIColor.darkGray
        progressBar.font = UIFont.boldSystemFont(ofSize: 18)
        progressBar.sizeToFit()
        self.mapView.addSubview(progressBar)
        
        // Create a background thread
        DispatchQueue.global().async {
            
            // Get the filename and remove the extension
            let fileComponents = file.components(separatedBy: ".")
            
            // Get the path to the file
            let path = Bundle.main.path(forResource: fileComponents[0], ofType: fileComponents[1])
            
            // Read file as text
            let text = try! String(contentsOfFile: path!) // read as string
            
            // Serialization
            let json = try! JSONSerialization.jsonObject(with: text.data(using: .utf8)!, options: []) as? [String: Any]
            
            // Deserialize as JSON
            let json2 = JSON(json!)
            
            // Begin parsing JSON
            let allData = json2["features"].arrayValue
            
            // Map each JSON entry to a model objects
            AllTimedParkingData = allData.map({ (entry: JSON) -> TimedParking in
                return TimedParking(json: entry)
            })
            
            // Return from asyncrhonous data import
            DispatchQueue.main.async {
                // Finished loading - should trigger didSet
                self.loading = false
                progressBar.removeFromSuperview()
            }
        }
    }
    
    // MARK: - Nearest Line
    func findSubsetForMapView() -> [TimedParking] {
        var subset = [TimedParking]()

        for location in AllTimedParkingData {
            if (location.line?.intersects(mapView.visibleMapRect))! {
                subset.append(location)
            }
        }
        
        return subset
    }
    
    // Find Nearby lines to location
    func findSubset(currentLocation: CLLocation) -> [TimedParking] {
        
        var subset = [TimedParking]()
        
        for location in AllTimedParkingData {
            
            let locationConvert = CLLocation.init(latitude: (location.line?.coordinate.latitude)!, longitude: (location.line?.coordinate.longitude)!)
            
            if location.line != nil && (locationConvert.distance(from: currentLocation) < CLLocationDistance(300)) {
                subset.append(location)
            }
        }
        
        for location in AllTimedParkingData {
            if (location.line?.intersects(mapView.visibleMapRect))! {
                subset.append(location)
            }
        }
        return subset
    }
    
    // MARK: Find Nearest Block function
    func findNearestBlock(data: [TimedParking], currentLocation: CLLocation) -> TimedParking {
        var closest: TimedParking?
        var closestDistance: CLLocationDistance = CLLocationDistance(99999999)
        
        // Iterate through all the data
        for location in data {
            
            // As long as there is more than one point in the line string...
            if location.geometry.count > 1 {
                
                // Create point coordinates for location in the data
                let x2 = location.geometry[1].longitude
                let x1 = location.geometry[0].longitude
                let y2 = location.geometry[1].latitude
                let y1 = location.geometry[0].latitude
                
                // Convert points to CLLocation
                let p1 = CLLocation(latitude: y1, longitude: x1)
                let p2 = CLLocation(latitude: y2, longitude: x2)
                
                // Distance of Current Location to Segment Call
                let distance = distanceCurrentLocToSegment(p: currentLocation, p1: p1, p2: p2)
                
                // Closest distance comparison
                if distance < closestDistance {
                    closest = location
                    closestDistance = distance
                }
            }
        }
        
        // Update the Active Parking Variable - Should trigger didSet in activeParking
        activeParking = ParkingInfo(activeStreet: closest!)
        //    guard ((activeParking = ParkingInfo(activeStreet: closest!)) != nil) else{
        //      print("Closest failed to set activeParking.activeStreet for some reason")
        //      return closest!
        //    }
        
        return closest!
    }
    
    // Determine closest distance between a point and a line defined by 2 points
    func distanceCurrentLocToSegment(p: CLLocation, p1: CLLocation, p2: CLLocation) -> CLLocationDistance {
        
        // Create point coordinates for longitude & latitude
        let x1 = p1.coordinate.longitude
        let x2 = p2.coordinate.longitude
        let y1 = p1.coordinate.latitude
        let y2 = p2.coordinate.latitude
        var ix: Double = 0
        var iy: Double = 0
        
        let lineMag = lineMagnitude(x1: x1, y1: y1, x2: x2, y2: y2)
        
        // Accounting for a line magnitude threshold that is neglibly zero
        if lineMag < 0.00000001 {
            return CLLocationDistance(abs(9999))
        }
        
        // Create point coordinates for non-line point for comparison
        let px = p.coordinate.longitude
        let py = p.coordinate.latitude
        
        // Find distance "u"
        var u = (((px - x1) * (x2 - x1)) + ((py - y1) * (y2 - y1)))
        u = u / (lineMag * lineMag)
        
        // Distance calculation
        if ((u < 0.00001) || (u > 1)) {
            ix = lineMagnitude(x1: px, y1: py, x2: x1, y2: y1)
            iy = lineMagnitude(x1: px, y1: py, x2: x2, y2: y2)
            if ix > iy {
                return CLLocationDistance(abs(iy))
            } else {
                return CLLocationDistance(abs(ix))
            }
        } else {
            ix = x1 + u * (x2 - x1)
            iy = y1 + u * (y2 - y1)
            return CLLocationDistance(abs(lineMagnitude(x1: px, y1: py, x2: ix, y2: iy)))
        }
    }
    
    
    // Function to find magnitude of line segment
    func lineMagnitude (x1: Double, y1: Double, x2: Double, y2: Double) -> Double {
        return CLLocationDistance(abs(sqrt(pow((x2-x1), 2) + pow((y2-y1), 2))))
    }
    
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "moveTimerSegue" {
            let timerView: TimerViewController = segue.destination as! TimerViewController
            timerView.viewControllerInstance = self
            timerView.parkingRule = activeParking!
        }
    }
}
