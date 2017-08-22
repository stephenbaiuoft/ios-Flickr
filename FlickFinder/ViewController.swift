//
//  ViewController.swift
//  FlickFinder
//
//  Created by Jarrod Parkes on 11/5/15.
//  Copyright © 2015 Udacity. All rights reserved.
//

import UIKit

// MARK: - ViewController: UIViewController

class ViewController: UIViewController {
    
    // MARK: Properties
    
    var keyboardOnScreen = false
    
    // MARK: Outlets
    
    @IBOutlet weak var photoImageView: UIImageView!
    @IBOutlet weak var photoTitleLabel: UILabel!
    @IBOutlet weak var phraseTextField: UITextField!
    @IBOutlet weak var phraseSearchButton: UIButton!
    @IBOutlet weak var latitudeTextField: UITextField!
    @IBOutlet weak var longitudeTextField: UITextField!
    @IBOutlet weak var latLonSearchButton: UIButton!
    
    // MARK: Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        phraseTextField.delegate = self
        latitudeTextField.delegate = self
        longitudeTextField.delegate = self
        subscribeToNotification(.UIKeyboardWillShow, selector: #selector(keyboardWillShow))
        subscribeToNotification(.UIKeyboardWillHide, selector: #selector(keyboardWillHide))
        subscribeToNotification(.UIKeyboardDidShow, selector: #selector(keyboardDidShow))
        subscribeToNotification(.UIKeyboardDidHide, selector: #selector(keyboardDidHide))
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        unsubscribeFromAllNotifications()
    }
    
    // MARK: method Parametesr Load
    func loadMethodParameters( methodParameters:inout [String: AnyObject]){
        
        methodParameters[Constants.FlickrParameterKeys.Extras] = Constants.FlickrParameterValues.MediumURL as AnyObject
        methodParameters[Constants.FlickrParameterKeys.SafeSearch] = Constants.FlickrParameterValues.UseSafeSearch as AnyObject
        methodParameters[Constants.FlickrParameterKeys.APIKey] = Constants.FlickrParameterValues.APIKey as AnyObject
        methodParameters[Constants.FlickrParameterKeys.Format] = Constants.FlickrParameterValues.ResponseFormat as AnyObject
        methodParameters[Constants.FlickrParameterKeys.NoJSONCallback] = Constants.FlickrParameterValues.DisableJSONCallback as AnyObject
        methodParameters[Constants.FlickrParameterKeys.Method] = Constants.FlickrParameterValues.SearchMethod as AnyObject
        
    }
    
    // MARK: Search Actions
    
    @IBAction func searchByPhrase(_ sender: AnyObject) {

        userDidTapView(self)
        setUIEnabled(false)
        
        if !phraseTextField.text!.isEmpty {
            photoTitleLabel.text = "Searching..."
            // TODO: Set necessary parameters!
            var methodParameters: [String: AnyObject] = [:]
            
            loadMethodParameters(methodParameters: &methodParameters)
        
            
            methodParameters[Constants.FlickrParameterKeys.Text]
                = phraseTextField.text! as AnyObject
            
            displayImageFromFlickrBySearch(methodParameters)
        } else {
            setUIEnabled(true)
            photoTitleLabel.text = "Phrase Empty."
        }
    }
    
    @IBAction func searchByLatLon(_ sender: AnyObject) {

        userDidTapView(self)
        setUIEnabled(false)
        
        if isTextFieldValid(latitudeTextField, forRange: Constants.Flickr.SearchLatRange) && isTextFieldValid(longitudeTextField, forRange: Constants.Flickr.SearchLonRange) {
            photoTitleLabel.text = "Searching..."
            // TODO: Set necessary parameters!
            var methodParameters: [String: AnyObject] = [:]
            loadMethodParameters(methodParameters: &methodParameters)
            
            methodParameters[Constants.FlickrParameterKeys.BoundingBox] = getBBox() as AnyObject
            
            displayImageFromFlickrBySearch(methodParameters)
        }
        else {
            setUIEnabled(true)
            photoTitleLabel.text = "Lat should be [-90, 90].\nLon should be [-180, 180]."
        }
    }
    
    // MARK: Return Proper Formatted Lattidue and Longtitude Value
    func getBBox()->String{
        if let doubleLatitude = Double(latitudeTextField.text!),
           let doubleLongtitude = Double(longitudeTextField.text!)
        {
            let latitude = doubleLatitude.rounded(toPlaces: 2)
            let longtitude = doubleLongtitude.rounded(toPlaces: 2)
            
            let latitudeMin = min( Constants.Flickr.SearchLatRange.0, latitude - Constants.Flickr.SearchBBoxHalfHeight )
            let latitudeMax = max( Constants.Flickr.SearchLatRange.1, latitude + Constants.Flickr.SearchBBoxHalfHeight)
            
            
            let longtitudeMin =  min( Constants.Flickr.SearchLonRange.0, longtitude - Constants.Flickr.SearchBBoxHalfWidth )
            
            let longtitudeMax = max( Constants.Flickr.SearchLonRange.1, longtitude + Constants.Flickr.SearchBBoxHalfWidth )
            return String(longtitudeMin) + "," + String(latitudeMin) + "," + String(longtitudeMax) + ","  + String(latitudeMax)
        }
        
        return ""
    }
    
    
    // MARK: Flickr API
    
    
    
    private func displayImageFromFlickrBySearch(_ methodParameters: [String: AnyObject]) {
        let session = URLSession.shared
        let url = flickrURLFromParameters(methodParameters)
        let request = URLRequest(url: url)
        
        
        let taskPage = session.dataTask(with: request) { (data, response, error) in
            func displayError(_ error:String){
                print(error)
                print("url at time of error:", url)
            }
            
            guard (error == nil) else{
                displayError("error is:" + (error?.localizedDescription)!)
                return
            }
            
            guard let statusCode = (response as? HTTPURLResponse)?.statusCode, statusCode >= 200 && statusCode <= 299 else{
                displayError("Your request returned a status code other than 2xx ")
                return
            }
            
            /* GUARD: Was there any data returned? */
            guard let data = data else {
                displayError("No data was returned by the request!")
                return
            }
            
            // Parse the data
            let parsedResult:[String:AnyObject]!
            do{
                parsedResult = try JSONSerialization.jsonObject(with: data, options: JSONSerialization.ReadingOptions.allowFragments) as! [String:AnyObject]
                
            }
            catch{
                displayError("Could not parse the data as JSON: \(data)")
                return
            }
            guard let photosDictionary = parsedResult[Constants.FlickrResponseKeys.Photos] as? [String:AnyObject] else{
                displayError("Could not find \(Constants.FlickrResponseKeys.Photos)")
                return
            }
            
            
            guard let pageCount = photosDictionary[Constants.FlickrResponseKeys.Pages] as? Int else {
                displayError("Coult not parse the page number")
                return
            }
            
            let pageLimit = min(pageCount, 40)
            let randomPage = arc4random_uniform(UInt32(pageLimit)) + 1
            self.displayImageFromFlickrBySearch(methodParameters, pageNumber: Int(randomPage))
            
        }
        
        
        taskPage.resume()
        
        // TODO: Make request to Flickr!
    }
    
    private func  displayImageFromFlickrBySearch( _ methodParameters: [String: AnyObject], pageNumber: Int){
        let session = URLSession.shared
        // Add additional argument to generate the new url
        
        var methodParameters = methodParameters
        methodParameters[Constants.FlickrResponseKeys.Pages] = pageNumber as AnyObject
        
        let url = flickrURLFromParameters(methodParameters)
        let request = URLRequest(url: url)
        
        let task = session.dataTask(with: request) { (data, response, error) in
            func displayError(_ error:String){
                print(error)
                print("url at time of error:", url)
            }
            
            guard (error == nil) else{
                displayError("error is:" + (error?.localizedDescription)!)
                return
            }
            
            guard let statusCode = (response as? HTTPURLResponse)?.statusCode, statusCode >= 200 && statusCode <= 299 else{
                displayError("Your request returned a status code other than 2xx ")
                return
            }
            
            /* GUARD: Was there any data returned? */
            guard let data = data else {
                displayError("No data was returned by the request!")
                return
            }
            
            // Parse the data
            let parsedResult:[String:AnyObject]!
            do{
                parsedResult = try JSONSerialization.jsonObject(with: data, options: JSONSerialization.ReadingOptions.allowFragments) as! [String:AnyObject]
                
            }
            catch{
                displayError("Could not parse the data as JSON: \(data)")
                return
            }
            
            guard let photosDictionary = parsedResult[Constants.FlickrResponseKeys.Photos] as? [String:AnyObject],
                let photoArray = photosDictionary[Constants.FlickrResponseKeys.Photo] as?
                    [[String:AnyObject]]
                
                else {
                    displayError("Could not find the key \(Constants.FlickrResponseKeys.Photos) or the key \(Constants.FlickrResponseKeys.Photo)")
                    return
            }
            
            if(photoArray.count == 0){
                performUIUpdatesOnMain {
                    self.photoTitleLabel.text = "No Image Found"
                }
            }
            else{
                // select a random photo
                let randomPhotoIndex = Int(arc4random_uniform(UInt32(photoArray.count)))
                let photoInfo = photoArray[randomPhotoIndex]
                
                let photoTitle = photoInfo[Constants.FlickrResponseKeys.Title] as? String ?? "No Title"
                
                guard let imageUrlString = photoInfo[Constants.FlickrResponseKeys.MediumURL] as? String else {
                    displayError("Could not parse url correctly")
                    return
                }
                
                let imageUrl = URL.init(string: imageUrlString)
                if let imageData = try? Data.init(contentsOf: imageUrl!){
                    performUIUpdatesOnMain {
                        self.setUIEnabled(true)
                        self.photoImageView.image = UIImage.init(data: imageData)
                        self.photoTitleLabel.text = photoTitle
                    }
                }else{
                    displayError("Does not exist url: \(imageUrl!)")
                }
                
            }
        }
        
        task.resume()
    
    }

    
    
    // MARK: Helper for Creating a URL from Parameters
    
    private func flickrURLFromParameters(_ parameters: [String: AnyObject]) -> URL {
        
        var components = URLComponents()
        components.scheme = Constants.Flickr.APIScheme
        components.host = Constants.Flickr.APIHost
        components.path = Constants.Flickr.APIPath
        components.queryItems = [URLQueryItem]()
        
        for (key, value) in parameters {
            let queryItem = URLQueryItem(name: key, value: "\(value)")
            components.queryItems!.append(queryItem)
        }
        
        return components.url!
    }
}

// MARK: - ViewController: UITextFieldDelegate

extension ViewController: UITextFieldDelegate {
    
    // MARK: UITextFieldDelegate
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
    // MARK: Show/Hide Keyboard
    
    func keyboardWillShow(_ notification: Notification) {
        if !keyboardOnScreen {
            view.frame.origin.y -= keyboardHeight(notification)
        }
    }
    
    func keyboardWillHide(_ notification: Notification) {
        if keyboardOnScreen {
            view.frame.origin.y += keyboardHeight(notification)
        }
    }
    
    func keyboardDidShow(_ notification: Notification) {
        keyboardOnScreen = true
    }
    
    func keyboardDidHide(_ notification: Notification) {
        keyboardOnScreen = false
    }
    
    func keyboardHeight(_ notification: Notification) -> CGFloat {
        let userInfo = (notification as NSNotification).userInfo
        let keyboardSize = userInfo![UIKeyboardFrameEndUserInfoKey] as! NSValue
        return keyboardSize.cgRectValue.height
    }
    
    func resignIfFirstResponder(_ textField: UITextField) {
        if textField.isFirstResponder {
            textField.resignFirstResponder()
        }
    }
    
    @IBAction func userDidTapView(_ sender: AnyObject) {
        resignIfFirstResponder(phraseTextField)
        resignIfFirstResponder(latitudeTextField)
        resignIfFirstResponder(longitudeTextField)
    }
    
    // MARK: TextField Validation
    
    func isTextFieldValid(_ textField: UITextField, forRange: (Double, Double)) -> Bool {
        if let value = Double(textField.text!), !textField.text!.isEmpty {
            return isValueInRange(value, min: forRange.0, max: forRange.1)
        } else {
            return false
        }
    }
    
    func isValueInRange(_ value: Double, min: Double, max: Double) -> Bool {
        return !(value < min || value > max)
    }
}

// MARK: - ViewController (Configure UI)

private extension ViewController {
    
     func setUIEnabled(_ enabled: Bool) {
        photoTitleLabel.isEnabled = enabled
        phraseTextField.isEnabled = enabled
        latitudeTextField.isEnabled = enabled
        longitudeTextField.isEnabled = enabled
        phraseSearchButton.isEnabled = enabled
        latLonSearchButton.isEnabled = enabled
        
        // adjust search button alphas
        if enabled {
            phraseSearchButton.alpha = 1.0
            latLonSearchButton.alpha = 1.0
        } else {
            phraseSearchButton.alpha = 0.5
            latLonSearchButton.alpha = 0.5
        }
    }
}

// MARK: - ViewController (Notifications)

private extension ViewController {
    
    func subscribeToNotification(_ notification: NSNotification.Name, selector: Selector) {
        NotificationCenter.default.addObserver(self, selector: selector, name: notification, object: nil)
    }
    
    func unsubscribeFromAllNotifications() {
        NotificationCenter.default.removeObserver(self)
    }
}
