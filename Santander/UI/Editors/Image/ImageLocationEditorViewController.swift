//
//  ImageLocationEditorViewController.swift
//  Santander
//
//  Created by Serena on 25/08/2022.
//

import UIKit
import MapKit
import CoreLocation

class ImageLocationEditorViewController: UIViewController, MKMapViewDelegate {
    let fileURL: URL
    let metadata: ImageMetadata
    // used to update the metadata if changed
    let metadataSenderVC: ImageMetadataViewController
    
    var mapView: MKMapView!
    var annotation: MKPointAnnotation!
    
    init(metadata: ImageMetadata, metadataSenderVC: ImageMetadataViewController, fileURL: URL) {
        self.metadata = metadata
        self.fileURL = fileURL
        self.metadataSenderVC = metadataSenderVC
        
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = "Location"
        
        let dismissAction = UIAction {
            self.dismiss(animated: true)
        }
        
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Dismiss", primaryAction: dismissAction)
        
        mapView = MKMapView()
        mapView.translatesAutoresizingMaskIntoConstraints = false
        mapView.delegate = self
        
        annotation = MKPointAnnotation()
        
        mapView.addAnnotation(annotation)
        
        view.addSubview(mapView)
        
        NSLayoutConstraint.activate([
            mapView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            mapView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            mapView.topAnchor.constraint(equalTo: view.topAnchor),
            mapView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        
        if let center = metadata.location.coordinate {
            annotation.coordinate = center
            // set the location on the map to be the image's location
            mapView.setRegion(MKCoordinateRegion(center: center, span: .init()), animated: true)
        }
        
        configureNavigationBarToNormal()
        setRightBarButton()
    }
    
    func setRightBarButton() {
        // edit if not editing,
        // and end editing if already doing editing
        let action = UIAction {
            self.setEditing(!self.isEditing, animated: true)
        }
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            systemItem: isEditing ? .done : .edit,
            primaryAction: action
        )
    }
    
    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)
        
        setRightBarButton()
        
        if !editing {
            // finalize editing, set location chosen
            setImageLocation()
        }
    }
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        guard let anno = self.annotation else {
            return nil
        }
        
        let view = MKPinAnnotationView(annotation: anno, reuseIdentifier: "DraggablePin")
        view.isDraggable = true
        return view
    }
    
    func moveAnnotation(_ mapView: MKMapView) {
        // Central coordinates of the map when editing location
        if isEditing {
            annotation.coordinate = mapView.centerCoordinate
        }
    }
    
    /// Sets the image location in the metadata
    func setImageLocation() {
        let coordinate = annotation.coordinate
        var newGPSDict = (metadata.dictionary[kCGImagePropertyGPSDictionary as String] as? [String: Any]) ?? [:]
        newGPSDict[kCGImagePropertyGPSLatitude as String] = coordinate.latitude
        newGPSDict[kCGImagePropertyGPSLongitude as String] = coordinate.longitude
        
        var copy = metadata.dictionary
        copy[kCGImagePropertyGPSDictionary as String] = newGPSDict
        
        // did succeed in setting the properties
        let didSucceed = metadata.setProperties(toDictionary: copy, forFileURL: fileURL)
        if !didSucceed {
            errorAlert("", title: "Unable to set location of image")
        } else {
            metadataSenderVC.metadata = .init(dictionary: copy)
            metadataSenderVC.tableView.reloadData()
        }
    }
    
    func mapView (_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        moveAnnotation(mapView)
    }
    
    /// Sets up the "Set" toolbar button
    func setupToolbarButton() {
        if let toolbar = navigationController?.toolbar {
            let visualEffectView = UIVisualEffectView(effect: UIBlurEffect(style: .regular))
            visualEffectView.frame = toolbar.bounds
            
            let action = UIAction {
                self.setImageLocation()
            }
            
            let button = UIButton(type: .system, primaryAction: action)
            button.setTitle("Set Location", for: .normal)
            button.titleLabel?.font = .systemFont(ofSize: UIFont.systemFontSize + 10)
            button.translatesAutoresizingMaskIntoConstraints = false
            
            visualEffectView.contentView.addSubview(button)
            NSLayoutConstraint.activate([
                button.centerXAnchor.constraint(equalTo: visualEffectView.contentView.centerXAnchor),
                button.centerYAnchor.constraint(equalTo: visualEffectView.contentView.centerYAnchor)
            ])
            
            toolbar.addSubview(visualEffectView)
            
            navigationController?.setToolbarHidden(false, animated: true)
        }
        
    }
}
