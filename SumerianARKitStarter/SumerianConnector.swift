//
//  SumerianWebViewLink.swift
//  SumerianARKitStarter
//
// Copyright 2017 Amazon.com, Inc. or its affiliates. All Rights Reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License"). You may not use this file except in compliance with the License. A copy of the License is located at
// http://aws.amazon.com/apache2.0/
// or in the "license" file accompanying this file. This file is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.
//

import Foundation
import ARKit
import WebKit

class SumerianConnector : NSObject, WKScriptMessageHandler, ARSessionDelegate {

    private static let hitTestMessageName = "arkit_hit_test"
    private static let registerAnchorMessageName = "arkit_register_anchor"

    private var arSession: ARSession!
    private var webView: FullScreenWKWebView!
    private var viewportSize: CGSize!
    
    class FullScreenWKWebView: WKWebView {
        override var safeAreaInsets: UIEdgeInsets {
            return UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        }
    }

    func setup(withParentView parentView: UIView, _ arSession: ARSession) {
        self.arSession = arSession
        self.viewportSize = CGSize(width: parentView.frame.width, height: parentView.frame.height)

        let webViewConfiguration = WKWebViewConfiguration()
        webViewConfiguration.userContentController = WKUserContentController()
        webViewConfiguration.userContentController.add(self, name: SumerianConnector.hitTestMessageName)
        webViewConfiguration.userContentController.add(self, name: SumerianConnector.registerAnchorMessageName)
        webViewConfiguration.mediaTypesRequiringUserActionForPlayback = []
        webViewConfiguration.allowsInlineMediaPlayback = true

        self.webView = FullScreenWKWebView(frame: CGRect(x: 0, y: 0, width: parentView.frame.width, height: parentView.frame.height), configuration: webViewConfiguration)
        self.webView.scrollView.isScrollEnabled = false
        self.webView.isUserInteractionEnabled = true
        self.webView.isOpaque = false
        self.webView.backgroundColor = .clear
        self.webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        parentView.addSubview(self.webView)
        self.arSession.delegate = self
    }

    func loadUrl(url: URL) {
        self.webView.load(URLRequest(url: url))
    }

    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        DispatchQueue.main.async {
            let orientation = UIApplication.shared.statusBarOrientation

            let viewMatrix = frame.camera.viewMatrix(for: orientation)
            let projectionMatrix = frame.camera.projectionMatrix(for: orientation, viewportSize: self.webView.frame.size, zNear: 0.02, zFar: 20)

            self.webView.evaluateJavaScript("ARKitBridge.viewProjectionMatrixUpdate(\'\(self.serializeMatrix(matrix: viewMatrix))', '\(self.serializeMatrix(matrix: projectionMatrix))');")

            if let lightEstimate = frame.lightEstimate {
                self.webView.evaluateJavaScript("ARKitBridge.lightingEstimateUpdate(\(lightEstimate.ambientIntensity), \(lightEstimate.ambientColorTemperature));")
            }

            if (frame.anchors.count > 0) {
                self.webView.evaluateJavaScript("ARKitBridge.anchorTransformUpdate(\'\(self.serializeAnchorTransforms(anchors: frame.anchors))');")
            }
        }
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == SumerianConnector.hitTestMessageName {
            guard let parameters = message.body as? Dictionary<String, String> else {
                return
            }

            guard let requestId = parameters["requestId"] else {
                return
            }

            guard let screenXString = parameters["screenX"], let screenX = Float(screenXString) else {
                return
            }

            guard let screenYString = parameters["screenY"], let screenY = Float(screenYString) else {
                return
            }

            if let hitTestResult = self.performHitTest(location: CGPoint(x: CGFloat(screenX), y: CGFloat(screenY))) {
                let serializedMatrix = serializeMatrix(matrix:hitTestResult)

                self.webView.evaluateJavaScript("ARKitBridge.hitTestResponse(\'\(requestId)\', \'\(serializedMatrix)\');")
            } else {
                self.webView.evaluateJavaScript("ARKitBridge.hitTestResponse(\'\(requestId)\', null);")
            }
        } else if message.name == SumerianConnector.registerAnchorMessageName {
            guard let parameters = message.body as? Dictionary<String, String> else {
                return;
            }

            guard let requestId = parameters["requestId"] else {
                return
            }

            guard let jsonTransform = parameters["transform"] else {
                return
            }

            guard let transform = deserializeMatrix(jsonString: jsonTransform) else {
                return
            }

            let anchor = ARAnchor(transform: transform)
            self.arSession.add(anchor: anchor)

            self.webView.evaluateJavaScript("ARKitBridge.registerAnchorResponse(\'\(requestId)\', \'\(anchor.identifier.uuidString)\');")
        }
    }

    func performHitTest(location: CGPoint) -> matrix_float4x4? {
        guard let currentFrame = self.arSession.currentFrame else {
            return nil;
        }

        let hitTestResults = currentFrame.hitTest(location, types: .existingPlaneUsingExtent);

        guard let firstResult = hitTestResults.first else {
            return nil;
        }

        return firstResult.worldTransform;
    }

    func serializeAnchorTransforms(anchors: [ARAnchor]) -> String {
        var anchorDictionary = Dictionary<String, Array<Float>>()

        for anchor in anchors {
            let serializedTransform = matrixToArray(matrix: anchor.transform)
            anchorDictionary[anchor.identifier.uuidString] = serializedTransform
        }

        let anchorJSONData = try! JSONSerialization.data(withJSONObject: anchorDictionary)
        return String(data: anchorJSONData, encoding: String.Encoding.utf8)!
    }
    
    func imageAnchorCreated(imageAnchor: ARImageAnchor, imageName: String) {
        let serializedMatrix = serializeMatrix(matrix: imageAnchor.transform)
        self.webView.evaluateJavaScript("ARKitBridge.imageAnchorResponse(\'\(imageName)\', \'\(serializedMatrix)\');")
    }

    func serializeMatrix(matrix: matrix_float4x4) -> String {
        let matrixJSONData = try! JSONSerialization.data(withJSONObject: matrixToArray(matrix: matrix))
        return String(data: matrixJSONData, encoding: String.Encoding.utf8)!
    }

    func deserializeMatrix(jsonString: String) -> matrix_float4x4? {
        guard let jsonData = jsonString.data(using: String.Encoding.utf8),
            let jsonObject = try? JSONSerialization.jsonObject(with: jsonData),
            let array = jsonObject as? [Float] else {
                return nil
        }

        return matrix_float4x4(float4(x: array[0], y: array[1], z: array[2], w: array[3]),
                               float4(x: array[4], y: array[5], z: array[6], w: array[7]),
                               float4(x: array[8], y: array[9], z: array[10], w: array[11]),
                               float4(x: array[12], y: array[13], z: array[14], w: array[15]));
    }

    func matrixToArray(matrix: matrix_float4x4) -> Array<Float> {
        var array = Array<Float>();

        array.append(matrix.columns.0.x)
        array.append(matrix.columns.0.y)
        array.append(matrix.columns.0.z)
        array.append(matrix.columns.0.w)

        array.append(matrix.columns.1.x)
        array.append(matrix.columns.1.y)
        array.append(matrix.columns.1.z)
        array.append(matrix.columns.1.w)

        array.append(matrix.columns.2.x)
        array.append(matrix.columns.2.y)
        array.append(matrix.columns.2.z)
        array.append(matrix.columns.2.w)

        array.append(matrix.columns.3.x)
        array.append(matrix.columns.3.y)
        array.append(matrix.columns.3.z)
        array.append(matrix.columns.3.w)

        return array
    }
}
