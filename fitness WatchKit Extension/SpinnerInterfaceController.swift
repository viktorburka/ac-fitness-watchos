//
//  SpinnerInterfaceController.swift
//  fitness WatchKit Extension
//
//  Created by Viktor Burka on 1/1/20.
//  Copyright © 2020 Viktor Burka. All rights reserved.
//

import WatchKit
import Foundation


class SpinnerInterfaceController: WKInterfaceController {

    @IBOutlet weak var messageLabel: WKInterfaceLabel!
    
    override func awake(withContext context: Any?) {
        super.awake(withContext: context)
        
        // Configure interface objects here.
        if let text = context {
            let displayText = text as! String
            messageLabel.setText(displayText)
        }
    }

    override func willActivate() {
        // This method is called when watch view controller is about to be visible to user
        super.willActivate()
    }

    override func didDeactivate() {
        // This method is called when watch view controller is no longer visible
        super.didDeactivate()
    }

}
