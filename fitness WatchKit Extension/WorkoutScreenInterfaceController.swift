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
                
//                for sample in samples {
//
//                    guard let currData:HKQuantitySample = sample as? HKQuantitySample else { return }
//                    let hr = currData.quantity.doubleValue(for: heartRateUnit)
//                    print("hr: \(hr)")
//                    self.displayBPM.setText("\(hr)BPM")
//                    print("end date: \(currData.endDate)")
////                    self.ws.startDate = currData.startDate
//                }
            print("reading samples...")
            if let event = samples.last
            {
                let hr = event.quantity.doubleValue(for: heartRateUnit)
                print("\(hr)")
                self.displayBPM.setText("\(hr)BPM")
                self.ws.startDate = event.endDate
            }
            //}
        }
        print("running query...")
        healthStore.execute(query)
    }
}
