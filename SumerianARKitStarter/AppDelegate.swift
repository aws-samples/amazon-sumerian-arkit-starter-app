//
//  AppDelegate.swift
//  SumerianARKitStarter
//
// Copyright 2017 Amazon.com, Inc. or its affiliates. All Rights Reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License"). You may not use this file except in compliance with the License. A copy of the License is located at
// http://aws.amazon.com/apache2.0/
// or in the "license" file accompanying this file. This file is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.
//

import UIKit
import AVFoundation

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        AVCaptureDevice.requestAccess(for: AVMediaType.video) { [weak self] (accepted) in
            if(!accepted) {
                let alert = UIAlertController(title: "Camera Disabled", message: "AR scenes require access to the camera.", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "Enable Camera", style: .default, handler: { (action: UIAlertAction!) in
                    UIApplication.shared.open(URL(string: "app-settings:")!, options: [:], completionHandler: nil);
                }))
                self?.window?.rootViewController?.present(alert, animated: true)
            }
        }
    }

    func applicationWillTerminate(_ application: UIApplication) {
    }
}

