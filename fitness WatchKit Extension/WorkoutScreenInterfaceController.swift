//
//  WorkoutScreenInterfaceController.swift
//  fitness WatchKit Extension
//
//  Created by Viktor Burka on 12/27/19.
//  Copyright © 2019 Viktor Burka. All rights reserved.
//

import WatchKit
import HealthKit
import Foundation

struct WorkoutSession {
    var startDate: Date
    var endDate: Date
}

struct WorkoutData: Codable {
    let heartRate: Int
}

class WorkoutScreenInterfaceController: WKInterfaceController {
    
    private var healthStore: HKHealthStore
    private var session: HKWorkoutSession?
    private var workoutIsActive: Bool = false
    private var ws: WorkoutSession
    private var timer: Timer?
    private var processing: Bool = false
    
    @IBOutlet weak var displayTimer: WKInterfaceTimer!
    @IBOutlet weak var displayBPM: WKInterfaceLabel!
    
    override init() {
        healthStore = HKHealthStore()
        ws = WorkoutSession(startDate: Date(), endDate: Date())
        super.init()
    }
    
    override func awake(withContext context: Any?) {
        super.awake(withContext: context)
        print("WorkoutScreenInterfaceController: awake")
        let allTypes = Set([HKObjectType.workoutType(),
                            HKObjectType.quantityType(forIdentifier: .heartRate)!])
        
        healthStore.requestAuthorization(toShare: allTypes, read: allTypes) { (success, error) in
            if !success {
                print("error request auth for health data!")
                self.pop()
            }
        }
    }

    override func willActivate() {
        print("WorkoutScreenInterfaceController: willActivate")
        // This method is called when watch view controller is about to be visible to user
        super.willActivate()
        startWorkout()
    }

    override func didDeactivate() {
        print("WorkoutScreenInterfaceController: didDeactivate")
        // This method is called when watch view controller is no longer visible
        super.didDeactivate()
//        endWorkout()
    }
    
    private func startWorkout() {
        if workoutIsActive {
            return
        }
        displayTimer.start()
        startTrackingWorkout()
        workoutIsActive = true
    }
    
    private func endWorkout() {
        if !workoutIsActive {
            return
        }
        displayTimer.stop()
        stopTrackingWorkout()
        workoutIsActive = false
        
    }

    @IBAction func endWorkoutPressed() {
        pop()
        endWorkout()
    }
    
    private func startTrackingWorkout() {
        let conf = HKWorkoutConfiguration()
        conf.activityType = .other
        
        guard let session = try? HKWorkoutSession(healthStore: healthStore, configuration: conf) else {
            print("can't create workout session")
            return
        }
        
        ws.startDate = Date()
        session.startActivity(with: ws.startDate)
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) {
            timer in
            
            // check whether the previous operation has finished yet
            if self.processing {
                print("request in progress. skipping...")
                return
            }
            // set processing flag to block any concurrent operations
            self.processing = true
            
            self.readHeartRate() {
                heartRate, error in
                
                if let error = error {
                    print(error)
                    self.processing = false
                    return
                }
                
                print("current heart rate: \(heartRate)BPM")
                self.displayBPM.setText("\(heartRate)BPM")
                
                // send heart rate to the server
                self.sendWorkoutData(heartRate: heartRate) {
                    error, httpCode in
                    // unblock further heart rate processing
                    self.processing = false
                    if let error = error {
                        print(error)
                        return
                    }
                    print("successfully sent workout data: \(heartRate)")
                }
            }
        }
    }
    
    private func stopTrackingWorkout() {
        guard let t = timer else {
            print("can't cast timer")
            return
        }
        t.invalidate()
        guard let s = session else {
            print("can't create workout session")
            return
        }
        s.stopActivity(with: Date())
        session = nil
    }
    
    private func readHeartRate(result: @escaping (Int,String?) -> Void) {

        let heartRateUnit = HKUnit(from: "count/min")
        let predicate = HKQuery.predicateForSamples(withStart: ws.startDate, end: nil, options: [])

        guard let sampleType = HKSampleType.quantityType(forIdentifier: HKQuantityTypeIdentifier.heartRate) else {
            result(-1, "can't init quantity type for HKQuantityTypeIdentifier.heartRate")
            return
        }
        
        let query = HKSampleQuery(sampleType: sampleType, predicate: predicate, limit: Int(HKObjectQueryNoLimit), sortDescriptors: nil) {
            query, results, error in
            
            if let error = error {
                result(-1, "\(error)")
                return
            }
            
            guard let samples = results as? [HKQuantitySample] else {
                result(-1, "can't convert resulting samples to [HKQuantitySample] type")
                return
            }

            if let event = samples.last {
                // read heart rate with the specified unit
                let heartRate = event.quantity.doubleValue(for: heartRateUnit)
                // update 'read from' position
                self.ws.startDate = event.endDate
                // return heart rate to the caller
                result(Int(heartRate), nil)
                return
            }
            
            result(-1, "no heart rate data available")
        }
        
        healthStore.execute(query)
    }
    
    private func sendWorkoutData(heartRate: Int, result: @escaping (String?, Int) -> Void) {
        
        let data = WorkoutData(heartRate: heartRate)
        guard let uploadData = try? JSONEncoder().encode(data) else {
            result("unable to encode workout data", -1)
            return
        }
        
        let url = URL(string: "http://cosml-1686857.local:8080/bar")!
        
        var request = URLRequest(url: url, cachePolicy: .useProtocolCachePolicy, timeoutInterval: 10.0)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let task = URLSession.shared.uploadTask(with: request, from: uploadData) {
            data, response, error in
            
            if let error = error {
                result("\(error)", -1)
                return
            }
            guard let response = response as? HTTPURLResponse else {
                result("can't convert http response to HTTPURLResponse", -1)
                return
            }
            if !(200...299).contains(response.statusCode) {
                result(HTTPURLResponse.localizedString(forStatusCode: response.statusCode), response.statusCode)
                return
            }
            result(nil, response.statusCode)
        }
        task.resume()
    }
}
