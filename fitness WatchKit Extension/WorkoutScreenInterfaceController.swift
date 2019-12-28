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
        do {
            try session = HKWorkoutSession(healthStore: healthStore, configuration: conf)
        } catch {
            print("can't create workout session")
            return
        }
        guard let s = session else {
            print("can't create workout session")
            return
        }
        ws.startDate = Date()
        s.startActivity(with: ws.startDate)
        
        print("started activity with date: \(ws.startDate)")
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true, block: { timer in
            self.readHeartRateData()
        })
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
    
    private func readHeartRateData() {

        let heartRateUnit:HKUnit = HKUnit(from: "count/min")
        let predicate = HKQuery.predicateForSamples(withStart: ws.startDate, end: nil, options: [])

        guard let sampleType = HKSampleType.quantityType(forIdentifier: HKQuantityTypeIdentifier.heartRate) else {
            fatalError("*** This method should never fail ***")
        }
        
        print("query with date \(ws.startDate)")
        let query = HKSampleQuery(sampleType: sampleType, predicate: predicate, limit: Int(HKObjectQueryNoLimit), sortDescriptors: nil) {
            query, results, error in
            
            if let e = error {
                print("error: \(e)")
                return
            }
            
            guard let samples = results as? [HKQuantitySample] else {
                fatalError("cast error");
            }
            
            //DispatchQueue.async(DispatchQueue.main) {
                
            print("reading samples...")
            if let event = samples.last
            {
                let hr = event.quantity.doubleValue(for: heartRateUnit)
                print("\(hr)")
                self.displayBPM.setText("\(hr)BPM")
                
                print("sending data...")
                self.sendWorkoutData(heartRate: Int(hr))
                
                self.ws.startDate = event.endDate
            }
            //}
        }
        print("running query...")
        healthStore.execute(query)
    }
    
    private func sendWorkoutData(heartRate hr: Int) {
        let data = WorkoutData(heartRate: hr)
        guard let uploadData = try? JSONEncoder().encode(data) else {
            print("unable to encode workout data")
            return
        }
        
        let url = URL(string: "http://cosml-1686857.local:8080/bar")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let task = URLSession.shared.uploadTask(with: request, from: uploadData) { data, response, error in
            if let error = error {
                print("error: \(error)")
                return
            }
            if let response = response as? HTTPURLResponse {
                if !(200...299).contains(response.statusCode) {
                    print("server error code: \(response.statusCode)")
                    return
                } else {
                    print("success: \(response.statusCode)")
                }
                if let mimeType = response.mimeType,
                    mimeType == "application/json",
                    let data = data,
                    let dataString = String(data: data, encoding: .utf8) {
                    print("got data: \(dataString)")
                }
            }
        }
        task.resume()
    }
}
