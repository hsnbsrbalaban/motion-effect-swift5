import UIKit

//This class is used to get safe area insets
class Device {
    static var safeAreaInset: UIEdgeInsets {
        guard let window = UIApplication.shared.keyWindow else { return .zero }
        return window.safeAreaInsets
    }
}

//Returns an image that contains the screenshot of given view
extension UIImage {
    convenience init(view: UIView, scale: CGFloat) {
        UIGraphicsBeginImageContextWithOptions(view.bounds.size, true, scale)
        view.drawHierarchy(in: view.bounds, afterScreenUpdates: true)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        self.init(cgImage: image!.cgImage!)
    }
}

class MotionViewController: UIViewController {
    
    @IBOutlet weak var topContainer: UIView!
    @IBOutlet weak var bottomContainer: UIView!
    
    @IBOutlet weak var invisibleButton: UIButton!
    @IBOutlet weak var preView: UIView!
    
    //image that will be used for motion
    var image: UIImage!
    //imageView that contains the image
    var drawableImageView: DrawableImageView!
    //scrollView is used for zoom in/out. contains drawableImageView
    var scrollView: UIScrollView!
    //this view contains the scissor and circle
    var iDontKnowItsNameView: UIView!
    //this image view contains the masked image
    var maskedImageView: UIImageView?
    //will be initialized when drawing interrupted. contains a scissor image
    var scissorView: UIImageView?
    //will be initialized when a new drawing occurs. contains a full circle image
    var circleView: UIImageView?
    //this image view is used for the showing the preview of the touched point
    var tempImageView: UIImageView?
    
    //can be changed by count slider
    var motionImageCount: Int = 10
    //can be changed by opacity slider
    var motionImageAlpha: Int = 100
    //contains the image views for motion effect
    var motionUIArray = [UIImageView]()
    
    //if the preview is on the left side: 0
    //if the preview is on the right side : 1
    var previewState: Int = 0
    //the ratio that is used for fitting the image to screen
    var frameSizeConstant: CGFloat = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setInitialScreen()
        
        // Menu part
        //makes the arrow button circular
        darkFillingView.layer.cornerRadius = darkFillingView.frame.width / 2
        //makes the count menu invisible
        imageCountView.alpha = 0
        //makes the opacity menu invisible
        opacityView.alpha = 0
        
        // Invisible button gesture recognizer
        let pressedGR = UILongPressGestureRecognizer(target: self, action: #selector(invisibleButtonPressed(_:)))
        //sets the minimumPressDuration feature
        pressedGR.minimumPressDuration = 0.01
        invisibleButton.addGestureRecognizer(pressedGR)
    }
    //initializes scrollView and drawableImageView. sets their properties and adds them to hierarchy
    func setInitialScreen() {
        //extract safe area insets from the view's height
        let heightWithoutSafeArea = view.frame.height - Device.safeAreaInset.top - Device.safeAreaInset.bottom
        frameSizeConstant = min(view.frame.size.width / image.size.width, (heightWithoutSafeArea - 280) / image.size.height)
        let frame = CGRect(origin: CGPoint.zero, size: CGSize(width: image.size.width * frameSizeConstant, height: image.size.height * frameSizeConstant))
        //center height for the frame
        let frameCenterHeight = ((heightWithoutSafeArea - topContainer.frame.height - bottomContainer.frame.height) / 2) + topContainer.frame.height + Device.safeAreaInset.top
        //initialize scrollView
        scrollView = UIScrollView(frame: CGRect(origin: CGPoint.zero, size: CGSize(width: self.view.frame.width, height: heightWithoutSafeArea * 0.8)))
        scrollView.center = CGPoint(x: self.view.center.x, y: frameCenterHeight)
        scrollView.backgroundColor = UIColor.clear
        scrollView.contentSize = frame.size
        scrollView.autoresizingMask = UIView.AutoresizingMask(rawValue: UIView.AutoresizingMask.flexibleHeight.rawValue | UIView.AutoresizingMask.flexibleWidth.rawValue)
        scrollView.minimumZoomScale = 0.5
        scrollView.maximumZoomScale = 5
        scrollView.zoomScale = 1
        scrollView.delegate = self
        //remove panGestureRecognizer from the scrollView to allow drawing a path on it
        scrollView.removeGestureRecognizer(scrollView.panGestureRecognizer)
        
        //initialize drawableImageView
        drawableImageView = DrawableImageView(frame: frame)
        drawableImageView.clipsToBounds = true
        //set the image of imageView
        drawableImageView.imageView?.image = image
        //set its delegate to self
        drawableImageView.delegate = self
        
        //initialize iDontKnowItsNameView
        iDontKnowItsNameView = UIView(frame: scrollView.frame)
        iDontKnowItsNameView.center = scrollView.center
        iDontKnowItsNameView.clipsToBounds = true
        iDontKnowItsNameView.backgroundColor = UIColor.clear
        iDontKnowItsNameView.isUserInteractionEnabled = false
        
        //add drawableImageView to scrollView
        scrollView.addSubview(drawableImageView)
        //add scrollView and iDontKnowItsNameView to screen
        self.view.insertSubview(scrollView, at: 0)
        self.view.insertSubview(iDontKnowItsNameView, at: 0)
        
        //set the content insets of the scrollView
        setContentInset(scrollView)
        
        //initialize tempImageView
        tempImageView = UIImageView(frame: drawableImageView.frame)
        tempImageView?.isUserInteractionEnabled = false
        tempImageView?.center = CGPoint(x: preView.frame.width / 2, y: preView.frame.height / 2)
        
        guard let tempImageView = tempImageView else { return }
        
        //add tempImageView to preView
        preView.addSubview(tempImageView)
    }
    
    //creates an alert controller and asks the user if s/he wants to discard changes and go back
    @IBAction func discardButton(_ sender: UIButton) {
        //declare and initialize the alertController
        let alertController = UIAlertController(title: "Discard changes?", message: nil, preferredStyle: .alert)
        //add "yep" action to alertController
        alertController.addAction(UIAlertAction(title: "Yep", style: .default, handler: { ctx in
            self.dismiss(animated: true, completion: nil)
        }))
        //add "cancel" action to alertController
        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        //present the alertController
        self.present(alertController, animated: true, completion: nil)
    }

    //creates an alert controller and asks the user if s/he wants to save the image
    @IBAction func saveButton(_ sender: UIButton) {
        //declare and initialize the alertController
        let alertController = UIAlertController(title: "Save image?", message: nil, preferredStyle: .alert)
        //add "yep" action to alertController
        alertController.addAction(UIAlertAction(title: "Yep", style: .default, handler: { ctx in
            //remove the drawed path
            self.drawableImageView.dashedLayer.removeFromSuperlayer()
            //take screen shot of the drawableImageView
            let imageData = self.captureScreenshot(view: self.drawableImageView)
            //save the image to photos album
            UIImageWriteToSavedPhotosAlbum(imageData, nil, nil, nil)
            //add the drawed path again
            self.drawableImageView.layer.addSublayer(self.drawableImageView.dashedLayer)
            //stop animations of the path
            self.drawableImageView.dashedLayer.removeAllAnimations()
        }))
        //add "cancel" action to alertController
        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        //present the alertController
        self.present(alertController, animated: true, completion: nil)
    }
    
    //UILongPressGestureRecognizer handler for invisibleButton
    @objc func invisibleButtonPressed(_ pressedGR: UILongPressGestureRecognizer) {
        //when the press begins, hide all the content that is created
        if pressedGR.state == .began {
            maskedImageView?.isHidden = true
            for view in motionUIArray {
                view.isHidden = true
            }
            drawableImageView.dashedLayer.isHidden = true
            iDontKnowItsNameView.isHidden = true
        } //when the press ends, make invisible all the content that is created
        else if pressedGR.state == .ended {
            maskedImageView?.isHidden = false
            for view in motionUIArray {
                view.isHidden = false
            }
            drawableImageView.dashedLayer.isHidden = false
            iDontKnowItsNameView.isHidden = false
        }
    }
    
    //removes all changes and refresh the screen to its original condition
    @IBAction func refreshButton(_ sender: UIButton) {
        //remove scissorView
        if scissorView != nil {
            removeScissorView()
        }
        //remove circleView
        if circleView != nil {
            removeCircleView()
        }
        //remove all the created views for motion effect
        didTouchedOutsidePath()
        //remove the path
        drawableImageView.path?.removeAllPoints()
        drawableImageView.pathPoints.removeAll()
        drawableImageView.dashedLayer.path = nil
        drawableImageView.setNeedsDisplay()
        //set motionstate to initial
        drawableImageView.motionState = .initial
        //set scrollView's zoomScale to default
        scrollView.zoomScale = 1
        //set preView's frame to default
        self.preView.frame = CGRect(x: 8, y: self.preView.frame.minY, width: 80, height: 80)
        //set previewState to default
        previewState = 0
    }
    
    //updates the count label and creates/deletes views from motionUIArray according to slider's current value
    @IBAction func countSliderF(_ sender: UISlider) {
        //update imageCountLabel
        imageCountLabel.text = String(format: "%.0f", imageCountSlider.value)
        //update motionImageCount
        motionImageCount = Int(imageCountSlider.value)
        
        guard let maskedImageView = self.maskedImageView else { return }
        
        var currVal = motionUIArray.count
        //if the value of the slider is decreased, delete views from the motionUIArray
        if Int(sender.value) < currVal {
            //remove views until the length of the array becomes equal to slider's value
            while Int(sender.value) != currVal {
                motionUIArray.last?.removeFromSuperview()
                motionUIArray.removeLast()
                //update current value
                currVal -= 1
            }
        } else { // if the value of the slider is increased, create new views and add them to motionUIArray
            //create views until the length of the arrat becomes equal to slider's value
            while Int(sender.value) != currVal {
                guard let imageView = drawableImageView.imageView, let path = drawableImageView.path else { return }
                //declare and initialize a new view
                let tempView = UIImageView(frame: imageView.frame)
                tempView.image = imageView.image
                tempView.isUserInteractionEnabled = false
                //mask the new view according to drawableImageView's path
                maskView(tempView: tempView, path: path)
                //add the new view to motionUIArray
                motionUIArray.append(tempView)
                //add the new view to tempView
                drawableImageView.addSubview(tempView)
                //bring the original masked view to front
                drawableImageView.bringSubviewToFront(maskedImageView)
                //update the current value
                currVal += 1
            }
        }
        guard let lastPoint = drawableImageView.touchPoints.last else { return }
        //update each view's center according to last point
        viewHandler(lastPoint: lastPoint, isNew: false, sender: "slider")
    }
    
    //updates the opacity label and alpha values of all views inside motionUIArray
    @IBAction func opacitySliderF(_ sender: UISlider) {
        //update the opacity label
        opacityLabel.text = String(format: "%.0f", opacitySlider.value)
        //update the motionImageAlpha
        motionImageAlpha = Int(opacitySlider.value)
        
        if maskedImageView == nil { return }
        //update alpha of every view inside motionUIArray
        var i: Int = 0
        for view in motionUIArray {
            view.alpha = CGFloat(1 - 0.9 / Double(motionImageCount) * Double(i))
            view.alpha = (view.alpha / 100) * CGFloat(motionImageAlpha)
            i += 1
        }
    }
    
    //MARK: - Menu Animations
    
    @IBOutlet weak var menuView: UIView!
    @IBOutlet weak var darkFillingView: UIView!
    @IBOutlet weak var imageCountView: UIView!
    @IBOutlet weak var opacityView: UIView!
    @IBOutlet weak var imageCountLabel: UILabel!
    @IBOutlet weak var opacityLabel: UILabel!
    @IBOutlet weak var imageCountSlider: UISlider!
    @IBOutlet weak var opacitySlider: UISlider!
    @IBOutlet weak var toggleMenuButton: UIButton!
    
    @IBAction func menuButtonPressed(_ sender: UIButton) {
        //if the menu is closed, open it
        if darkFillingView.transform == .identity {
            UIView.animate(withDuration: 0.5, animations: {
                self.darkFillingView.transform = CGAffineTransform(scaleX: 11, y: 11)
                self.toggleMenuButton.transform = CGAffineTransform(rotationAngle: CGFloat(Double.pi))
                // Took more than 1 hour to figure this yPos out !! FML
                let yPos: CGFloat = self.menuView.frame.height - self.view.frame.maxY + self.view.convert(self.menuView.frame, from: self.menuView.superview).origin.y + Device.safeAreaInset.bottom - 2
                self.menuView.transform = CGAffineTransform(translationX: 0, y: -yPos)
            }) { (true) in
                UIView.animate(withDuration: 0.3, animations: {
                    self.imageCountView.alpha = 1
                    self.opacityView.alpha = 1
                })
            }
        } else { // if menu is open, close it
            UIView.animate(withDuration: 0.5) {
                self.darkFillingView.transform = .identity
                self.toggleMenuButton.transform = .identity
                self.menuView.transform = .identity
                self.imageCountView.alpha = 0
                self.opacityView.alpha = 0
            }
        }
    }
    
    //MARK: - Helper Functions
    
    //creates, relocates the views
    func viewHandler(lastPoint: CGPoint, isNew: Bool, sender: String) {
        
        guard let imageView = drawableImageView.imageView, let path = drawableImageView.path, let maskedImageView = self.maskedImageView else { return }
        //calculate the start points
        let sPx = path.bounds.origin.x + path.bounds.width / 2
        let sPy = path.bounds.origin.y + path.bounds.height / 2
        
        for i in 0..<motionImageCount {
            //calculate center for the current view
            let diffX = (lastPoint.x - sPx) / CGFloat(motionImageCount)
            let centerX = imageView.center.x + (CGFloat(i) + 1) * diffX
            let diffY = (lastPoint.y - sPy) / CGFloat(motionImageCount)
            let centerY = imageView.center.y + (CGFloat(i) + 1) * diffY
            //if the caller is touch
            if sender == "touch" {
                if isNew { //if a new view will be created
                    //initialize a new view
                    let tempView = UIImageView(frame: imageView.frame)
                    tempView.isUserInteractionEnabled = false
                    tempView.image = imageView.image
                    tempView.center = CGPoint(x: centerX, y: centerY)
                    //take the path and mask the new view
                    guard let path = drawableImageView.path else { return }
                    maskView(tempView: tempView, path: path)
                    //calculate and set its alpha
                    tempView.alpha = CGFloat(1 - 0.9 / Double(motionImageCount) * Double(i))
                    //append it to motionUIArray
                    motionUIArray.append(tempView)
                    //add it ti screen
                    drawableImageView.addSubview(tempView)
                    //bring the original masked view to front
                    drawableImageView.bringSubviewToFront(maskedImageView)
                } else { //if the user motioning
                    //take the current view from motionUIArray
                    let curView = motionUIArray[i]
                    //set its center to calculated center
                    curView.center = CGPoint(x: centerX, y: centerY)
                }
            } else { //if the caller is slider
                //take the current view from motionUIArray
                let curView = motionUIArray[i]
                //calculate and set its alpha
                curView.alpha = CGFloat(1 - 0.9 / Double(motionImageCount) * Double(i))
                //set its center to calculated center
                curView.center = CGPoint(x: centerX, y: centerY)
            }
        }
    }
    
    //masks the given view according to path
    func maskView(tempView: UIImageView, path: UIBezierPath) {
        //take the imageView
        guard let imageView = drawableImageView.imageView else { return }
        let rect: CGRect = imageView.frame
        //create a CAShapeLayer
        let maskLayer = CAShapeLayer()
        maskLayer.frame = CGRect(origin: .zero, size: rect.size)
        //set the path of maskLayer to drawableImageView's path
        maskLayer.path = path.cgPath
        //mask the layer
        tempView.layer.mask = maskLayer
    }
    
    //returns a screenshot of the given view
    func captureScreenshot(view: UIView) -> UIImage {
        return UIImage(view: view, scale: UIScreen.main.scale)
    }
    
    //checks if the currently touched point is inside the pathView
    func checkPreview(location: CGPoint) {
        //if the pathView contains the touched point, change its position
        if preView.frame.contains(topContainer.convert(location, from: drawableImageView)) {
            //if the preview is on the left side, change its from so that it will be on the right side after animation
            if previewState == 0 {
                UIView.animate(withDuration: 0.05) {
                    self.preView.frame = CGRect(x: self.view.frame.width - 88, y: self.preView.frame.minY, width: 80, height: 80)
                }
                //update the previewState
                previewState = 1
            } else { //if the preview is on the right side, change its from so that it will be on the left side after animation
                UIView.animate(withDuration: 0.05) {
                    self.preView.frame = CGRect(x: 8, y: self.preView.frame.minY, width: 80, height: 80)
                }
                //update the previewState
                previewState = 0
            }
        }
    }
}

//MARK: - Delegation Functions
extension MotionViewController: DrawableImageViewDelegate {
    //shows an 80x80 preview of the currently touched point inside preView
    func previewTheTouchedPoint(touch: UITouch) {
        //take snapshot of drawableImageView
        let snapshotImage = UIImage(view: drawableImageView, scale: UIScreen.main.scale)
        //set the preView's image
        tempImageView?.image = snapshotImage
        //get the touched point
        var location = touch.location(in: drawableImageView)
        //checks if the touched point is inside preView
        checkPreview(location: location)
        //bound restrictions for the touched point
        location.x = min(drawableImageView.frame.width - 40, max(location.x, 40))
        location.y = min(drawableImageView.frame.height - 40, max(location.y, 40))
        //calculate the original center from the zoomed in/out drawableImageView
        let scaledCenter: CGPoint = CGPoint(x: drawableImageView.center.x / scrollView.zoomScale, y: drawableImageView.center.y / scrollView.zoomScale)
        //calculate the difference between touched point and drawableImageView's center
        let diff = CGPoint(x: location.x - scaledCenter.x, y: location.y - scaledCenter.y)
        //shift the center of tempImageView by the calculated difference
        tempImageView?.center = CGPoint(x: preView.frame.width / 2 - diff.x, y: preView.frame.height / 2 - diff.y)
    }
    
    //removes the preView's image
    func removePreviewImage() {
        tempImageView?.image = nil
    }
    
    //creates scissorView and centers it at the given location
    func createScissorView(location: CGPoint) {
        //initialize the scissorView
        scissorView = UIImageView(image: UIImage(named: "scissor"))
        scissorView?.frame = CGRect(origin: CGPoint.zero, size: CGSize(width: 24, height: 24))
        scissorView?.contentMode = .scaleAspectFit
        scissorView?.tintColor = UIColor.white
        scissorView?.center = iDontKnowItsNameView.convert(location, from: drawableImageView)
        //calculate the rotation angle for the scissor
        if drawableImageView.pathPoints.count > 1 {
            guard let p1 = drawableImageView.pathPoints.last else { return }
            let p2 = drawableImageView.pathPoints[drawableImageView.pathPoints.count - 2]
            
            var angle: CGFloat = 0
            if p2.x - p1.x > 0 {
                angle = atan((p2.y - p1.y) / (p2.x - p1.x)) - CGFloat.pi / 180 * 90
            }
            else {
                angle = atan((p2.y - p1.y) / (p2.x - p1.x)) + CGFloat.pi / 180 * 90
            }
            //rotate scissor by the calculated angle
            scissorView?.transform = CGAffineTransform(rotationAngle: angle)
            
            guard let tempView = scissorView else { return }
            //add scissorView to screen and bring it to front
            self.iDontKnowItsNameView.addSubview(tempView)
            self.view.bringSubviewToFront(iDontKnowItsNameView)
        }
    }
    
    //removes the scissorView from the screen
    func removeScissorView() {
        scissorView?.removeFromSuperview()
        scissorView = nil
    }
    
    //checks if the given point is inside the scissorView
    func isScissorContainsTouch(location: CGPoint) -> Bool {
        guard let frame = scissorView?.frame else { return false }
        return frame.contains(iDontKnowItsNameView.convert(location, from: drawableImageView))
    }
    
    //creates circleView and centers it at the given location
    func createCircleView(location: CGPoint) {
        //initialize the circleView
        circleView = UIImageView(image: UIImage(named: "circle"))
        circleView?.tintColor = UIColor.white
        circleView?.center = iDontKnowItsNameView.convert(location, from: drawableImageView)
        
        guard let tempView = circleView else { return }
        //add circleView to screen and bring it to front
        self.iDontKnowItsNameView.addSubview(tempView)
        self.view.bringSubviewToFront(iDontKnowItsNameView)
    }
    
    //removes the circleView from the screen
    func removeCircleView() {
        circleView?.removeFromSuperview()
        circleView = nil
    }
    
    //initialize the maskedImageView and adds it to screen
    func createMaskedImageView(path: UIBezierPath) {
        guard let imageView = drawableImageView.imageView else { return }
        let rect: CGRect = imageView.frame
        //initialize the maskedImageView
        maskedImageView = UIImageView(frame: rect)
        maskedImageView?.image = imageView.image
        maskedImageView?.isUserInteractionEnabled = false
        //initialize the maskLayer and set its path
        let maskLayer = CAShapeLayer()
        maskLayer.frame = CGRect(origin: .zero, size: rect.size)
        maskLayer.path = path.cgPath
        maskedImageView?.layer.mask = maskLayer
        
        guard let tempView = maskedImageView else { return }
        //add the new view to screen
        drawableImageView.addSubview(tempView)
    }
    
    //calls viewHandler with correct parameters
    func createMotioningViews(lastPoint: CGPoint) {
        //if the motionUIArray is empty, create new views
        if motionUIArray.isEmpty {
            viewHandler(lastPoint: lastPoint, isNew: true, sender: "touch")
        }
        else { //if the motionUIArray is not empty, re-arrange the views
            viewHandler(lastPoint: lastPoint, isNew: false, sender: "touch")
        }
    }
    
    //removes all the views that are created after drawing and motioning
    func didTouchedOutsidePath() {
        maskedImageView?.removeFromSuperview()
        maskedImageView = nil
        
        if motionUIArray.isEmpty { return }
        
        for item in motionUIArray {
            item.removeFromSuperview()
        }
        motionUIArray.removeAll()
    }
}

//MARK: - ScrollView
extension MotionViewController: UIScrollViewDelegate {
    //returns the view that will be zoomed
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return drawableImageView
    }
    
    //this function is called after every zoom
    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        //re-arrange the content insets
        setContentInset(scrollView)
        guard let lastPoint = drawableImageView.touchPoints.last, let firstPoint = drawableImageView.pathPoints.first else {return}
        //re-arrange the scissorView's center
        scissorView?.center = iDontKnowItsNameView.convert(lastPoint, from: drawableImageView)
        //re-arrange the circleView's center
        circleView?.center = iDontKnowItsNameView.convert(firstPoint, from: drawableImageView)
        //bring topContainer to front so the preView can be seen
        view.bringSubviewToFront(topContainer)
    }
    
    //calculates and sets the insets for scrollView
    func setContentInset(_ scrollView: UIScrollView) {
        let imageViewSize = drawableImageView.frame.size
        let scrollViewSize = scrollView.bounds.size
        //calculate the vertical and horizontal paddings
        let verticalPadding = imageViewSize.height < scrollViewSize.height ? (scrollViewSize.height - imageViewSize.height) / 2 : 0
        let horizontalPadding = imageViewSize.width < scrollViewSize.width ? (scrollViewSize.width - imageViewSize.width) / 2 : 0
        // this is the distance that the content view is inset from the enclosing scroll view.
        scrollView.contentInset = UIEdgeInsets(top: verticalPadding, left: horizontalPadding, bottom: verticalPadding, right: horizontalPadding)
    }
}
