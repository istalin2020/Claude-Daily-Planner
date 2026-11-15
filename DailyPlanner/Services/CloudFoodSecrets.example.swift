//
//  CloudFoodSecrets — analysis service credentials
//  ----------------------------------------------
//  Fill in the two values below with your own, from worker/README.md step 4.
//  Until you do, the app falls back to on-device food recognition — which is
//  exactly what free-tier users get, so nothing breaks in the meantime.
//
//  This file is `CloudFoodSecrets.example.swift`, the committed template.
//  The real file is `CloudFoodSecrets.swift` in the same folder: it is
//  gitignored, because this repo is PUBLIC, which means
//
//    • your values never leave your Mac
//    • `git pull` never wipes them — git leaves untracked files alone
//    • they still compile into the Release binary, so App Store PRO users
//      get smart analysis with no setup of their own
//
//  A build phase copies this template to CloudFoodSecrets.swift whenever that
//  file is missing, so a fresh clone always builds. It never overwrites an
//  existing one, so your real values are safe across pulls and rebuilds.
//
//  Edit the copy, not this template — edits here would be committed.
//

import Foundation

enum CloudFoodSecrets {

    /// Your Worker URL. No trailing slash.
    static let workerBaseURL = "https://PASTE-YOUR-WORKER-URL-HERE.workers.dev"

    /// Must exactly match the APP_TOKEN secret set on the Worker.
    static let appToken = "PASTE-YOUR-APP-TOKEN-HERE"
}
