//
//  CloudFoodSecrets.example.swift
//  ------------------------------
//  THIS IS A TEMPLATE. It is not compiled — it isn't in the Xcode target.
//
//  Copy it to `CloudFoodSecrets.swift` in this same folder and fill in your
//  two values. That file is listed in .gitignore, so:
//
//    • your values never reach this PUBLIC repo
//    • `git pull` never wipes them (git leaves untracked files alone)
//    • they compile into the Release binary, so App Store PRO users get
//      smart analysis with no setup of their own
//
//  How to create it — see worker/README.md § "Step 4" for the full walkthrough:
//
//    1. In Xcode, right-click the Services folder → New File from Template…
//       → Swift File → name it exactly `CloudFoodSecrets`
//    2. Make sure "DailyPlanner" is ticked under Targets
//    3. Replace its contents with the code below, with your real values
//
//  If you ever re-clone this repo, recreate this file before building —
//  the project expects it and the build will fail with
//  "Build input file cannot be found" until it exists.
//

import Foundation

enum CloudFoodSecrets {

    /// Your Worker URL. No trailing slash.
    static let workerBaseURL = "https://PASTE-YOUR-WORKER-URL-HERE.workers.dev"

    /// Must exactly match the APP_TOKEN secret set on the Worker.
    static let appToken = "PASTE-YOUR-APP-TOKEN-HERE"
}
