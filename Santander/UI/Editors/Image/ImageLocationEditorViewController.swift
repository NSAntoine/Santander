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
        
        mapView.constraintCompletely(to: view)
        
        if let center = metadata.location.coordinate {
            annotation.coordinate = center
            // set the location on the map to be the image's location
            mapView.setRegion(MKCoordinateRegion(center: center, span: .init()), animated: true)
        }
        
        configureNavigationBarToNormal()
        setRightBarButton()
        setupToolbar()
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
            setImageLocation(nullify: false)
        } else {
            // add back annotation, if necessary
            mapView.addAnnotation(annotation)
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
    func setImageLocation(nullify: Bool) {
        let coordinate = annotation.coordinate
        var newGPSDict = (metadata.dictionary[kCGImagePropertyGPSDictionary as String] as? [String: Any?]) ?? [:]
        if nullify {
            newGPSDict[kCGImagePropertyGPSLatitude as String] = nil
            newGPSDict[kCGImagePropertyGPSLongitude as String] = nil
            metadata.location = ImageLocation(lat: nil, long: nil)
        } else {
            newGPSDict[kCGImagePropertyGPSLatitude as String] = coordinate.latitude
            newGPSDict[kCGImagePropertyGPSLongitude as String] = coordinate.longitude
            metadata.location = ImageLocation(lat: coordinate.latitude, long: coordinate.longitude)
        }
        
        var copy = metadata.dictionary
        copy[kCGImagePropertyGPSDictionary as String] = newGPSDict
        
        // did succeed in setting the properties
        let didSucceed = metadata.setProperties(toDictionary: copy, forFileURL: fileURL)
        if !didSucceed {
            errorAlert("", title: "Unable to set location of image")
        } else {
            metadataSenderVC.metadata = .init(dictionary: copy)
            metadataSenderVC.tableView.reloadData()
            if nullify {
                mapView.removeAnnotation(annotation)
            }
        }
        self.setupToolbar()
    }
    
    func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        moveAnnotation(mapView)
    }
    
    func setupToolbar() {
        // here, we setup the trash button
        // in case the user wants to nullify the location
        // of the image
        
        let action = UIAction {
            // confirm if the user wants to remove it
            let alert = UIAlertController(title: "Remove image location?", message: nil, preferredStyle: .actionSheet)
            let removeAction = UIAlertAction(title: "Remove", style: .destructive) { _ in
                self.setImageLocation(nullify: true)
            }
            
            alert.addAction(removeAction)
            alert.addAction(.cancel())
            self.present(alert, animated: true)
        }
        
        let trashButton = UIBarButtonItem(image: UIImage(systemName: "trash"), primaryAction: action)
        // enable trash button only if location isnt nil
        trashButton.isEnabled = metadata.location.coordinate != nil
        trashButton.tintColor = .systemRed
        
        navigationController?.setToolbarHidden(false, animated: true)
        self.toolbarItems = [trashButton]
    }
}
