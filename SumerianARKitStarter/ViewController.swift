//
//  ViewController.swift
//  SumerianARKitStarter
//
// Copyright 2017 Amazon.com, Inc. or its affiliates. All Rights Reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License"). You may not use this file except in compliance with the License. A copy of the License is located at
// http://aws.amazon.com/apache2.0/
// or in the "license" file accompanying this file. This file is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.
//

import UIKit
import ARKit
import WebKit

class ViewController: UIViewController, ARSCNViewDelegate {
    @IBOutlet weak var sceneView: ARSCNView!

    // URL of the Sumerian scene.
    private let sceneURL = URL(string: "https://d1550wa51vq95s.cloudfront.net/cab395b5e46b44f3affe4957fb04cf32.scene/?arMode=true")!

    private var cubeMaterials: [SCNMaterial]!
    private var sumerianConnector: SumerianConnector!
    private var createDebugNodes: Bool = true
    
    /// A serial queue for thread safety when modifying the SceneKit node graph.
    let updateQueue = DispatchQueue(label: Bundle.main.bundleIdentifier! +
        ".serialSceneKitQueue")
    
    /// Convenience accessor for the session owned by ARSCNView.
    var session: ARSession {
        return sceneView.session
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // Prevent the screen from being dimmed to avoid interupting the AR experience.
        UIApplication.shared.isIdleTimerDisabled = true
        
        // Setup the image recognition reference images
        guard let referenceImages = ARReferenceImage.referenceImages(inGroupNamed: "AR Resources", bundle: nil) else {
            fatalError("Missing expected asset catalog resources.")
        }
        
        let configuration = ARWorldTrackingConfiguration()
        configuration.detectionImages = referenceImages
        session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.createCubeMaterials()
        self.sumerianConnector = SumerianConnector()
        self.sumerianConnector.setup(withParentView: self.sceneView, sceneView.session)

        sceneView.scene = SCNScene()
        sceneView.delegate = self
        sceneView.preferredFramesPerSecond = 60

        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = .horizontal
        configuration.isLightEstimationEnabled = true
        sceneView.session.run(configuration)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.sumerianConnector.loadUrl(url: self.sceneURL)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sceneView.session.pause()
    }

    // ARSCNViewDelegate
    func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
        if !self.createDebugNodes {
            return nil
        }

        let cube = SCNBox(width: 0.1, height: 0.1, length: 0.1, chamferRadius: 0.0)
        cube.materials = self.cubeMaterials

        let cubeNode = SCNNode()
        cubeNode.geometry = cube

        return cubeNode
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        guard let imageAnchor = anchor as? ARImageAnchor else { return }
        DispatchQueue.main.async {
            self.sumerianConnector.imageAnchorCreated(imageAnchor: imageAnchor, imageName: imageAnchor.referenceImage.name ?? "");
        }
    }

    func createCubeMaterials() {
        let greenMaterial = SCNMaterial()
        greenMaterial.diffuse.contents = UIColor.green;
        greenMaterial.locksAmbientWithDiffuse = true

        let redMaterial = SCNMaterial()
        redMaterial.diffuse.contents = UIColor.red;
        redMaterial.locksAmbientWithDiffuse = true

        let blueMaterial = SCNMaterial()
        blueMaterial.diffuse.contents = UIColor.blue;
        blueMaterial.locksAmbientWithDiffuse = true

        let yellowMaterial = SCNMaterial()
        yellowMaterial.diffuse.contents = UIColor.yellow;
        yellowMaterial.locksAmbientWithDiffuse = true

        let purpleMaterial = SCNMaterial()
        purpleMaterial.diffuse.contents = UIColor.purple;
        purpleMaterial.locksAmbientWithDiffuse = true

        let grayMaterial = SCNMaterial()
        grayMaterial.diffuse.contents = UIColor.gray;
        grayMaterial.locksAmbientWithDiffuse = true

        cubeMaterials = [greenMaterial, redMaterial, blueMaterial, yellowMaterial, purpleMaterial, grayMaterial]
    }
}
