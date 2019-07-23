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
    
    var image: UIImage!
    var drawableImageView: DrawableImageView!
    var scrollView: UIScrollView!
    var maskedImageView: UIImageView?
    var scissorView: UIImageView?
    var tempImageView: UIImageView?
    
    var motionImageCount: Int = 10
    var motionImageAlpha: Int = 100
    var motionUIArray = [UIImageView]()
    
    var frameSizeConstant: CGFloat!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setInitialScreen()
        
        // Menu part
        darkFillingView.layer.cornerRadius = darkFillingView.frame.width / 2
        imageCountLabel.text = String(format: "%.0f", imageCountSlider.value)
        imageCountView.alpha = 0
        opacityView.alpha = 0
        
        // Invisible button gesture recognizer
        let pressedGR = UILongPressGestureRecognizer(target: self, action: #selector(invisibleButtonPressed(_:)))
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
        scrollView.removeGestureRecognizer(scrollView.panGestureRecognizer)
        
        drawableImageView = DrawableImageView(frame: frame)
        drawableImageView.clipsToBounds = true
        // Set the image of imageView
        drawableImageView.imageView?.image = image
        drawableImageView.delegate = self
        
        scrollView.addSubview(drawableImageView)
        self.view.insertSubview(scrollView, at: 0)
        
        setContentInset(scrollView)
        
        tempImageView = UIImageView(frame: drawableImageView.frame)
        tempImageView?.isUserInteractionEnabled = false
        preView.addSubview(tempImageView!)
        tempImageView?.center = CGPoint(x: preView.frame.width / 2, y: preView.frame.height / 2)
    }
    
    @IBAction func discardButton(_ sender: UIButton) {
        let alertController = UIAlertController(title: "Discard changes?", message: nil, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "Yep", style: .default, handler: { ctx in
            self.dismiss(animated: true, completion: nil)
        }))
        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        
        self.present(alertController, animated: true, completion: nil)
    }

    @IBAction func saveButton(_ sender: UIButton) {
        let alertController = UIAlertController(title: "Save image?", message: nil, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "Yep", style: .default, handler: { ctx in
            self.drawableImageView.dashedLayer.removeFromSuperlayer()
            let imageData = self.captureScreenshot(view: self.drawableImageView)
            UIImageWriteToSavedPhotosAlbum(imageData, nil, nil, nil)
            self.drawableImageView.layer.addSublayer(self.drawableImageView.dashedLayer)
            self.drawableImageView.dashedLayer.removeAllAnimations()
        }))
        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        
        self.present(alertController, animated: true, completion: nil)
    }

    @objc func invisibleButtonPressed(_ pressedGR: UILongPressGestureRecognizer) {
        if pressedGR.state == .began {
            maskedImageView?.isHidden = true
            for view in motionUIArray {
                view.isHidden = true
            }
            drawableImageView.dashedLayer.isHidden = true
        }
        else if pressedGR.state == .ended {
            maskedImageView?.isHidden = false
            for view in motionUIArray {
                view.isHidden = false
            }
            drawableImageView.dashedLayer.isHidden = false
        }
    }
    
    @IBAction func refreshButton(_ sender: UIButton) {
        
        if scissorView != nil {
            removeScissorView()
        }
        
        didTouchedOutsidePath()
        
        drawableImageView.path?.removeAllPoints()
        drawableImageView.pathPoints.removeAll()
        drawableImageView.dashedLayer.path = nil
        drawableImageView.setNeedsDisplay()
        
        drawableImageView.motionState = .initial
        
        scrollView.zoomScale = 1
    }
    
    
    @IBAction func countSliderF(_ sender: UISlider) {
        imageCountLabel.text = String(format: "%.0f", imageCountSlider.value)
        motionImageCount = Int(imageCountSlider.value)
        
        if maskedImageView == nil { return }
        
        var currVal = motionUIArray.count
        
        if Int(sender.value) < currVal {
            while Int(sender.value) != currVal {
                motionUIArray.last?.removeFromSuperview()
                motionUIArray.removeLast()
                
                currVal -= 1
            }
        } else {
            while Int(sender.value) != currVal {
                guard let imageView = drawableImageView.imageView, let path = drawableImageView.path else { return }
                let tempView = UIImageView(frame: imageView.frame)
                tempView.image = imageView.image
                tempView.isUserInteractionEnabled = false
                
                maskView(tempView: tempView, path: path)
                
                motionUIArray.append(tempView)
                drawableImageView.addSubview(tempView)
                drawableImageView.bringSubviewToFront(maskedImageView!)
                
                currVal += 1
            }
        }
        guard let lastPoint = drawableImageView.touchPoints.last else { return }
        viewHandler(lastPoint: lastPoint, isNew: false, sender: "slider")
    }
    
    @IBAction func opacitySliderF(_ sender: UISlider) {
        opacityLabel.text = String(format: "%.0f", opacitySlider.value)
        motionImageAlpha = Int(opacitySlider.value)
        
        if maskedImageView == nil { return }
        
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
    @IBOutlet weak var toggleMenuButton: UIButton!
    @IBOutlet weak var imageCountLabel: UILabel!
    @IBOutlet weak var imageCountSlider: UISlider!
    @IBOutlet weak var opacityLabel: UILabel!
    @IBOutlet weak var opacitySlider: UISlider!
    
    @IBOutlet weak var imageCountView: UIView!
    @IBOutlet weak var opacityView: UIView!
    
    @IBAction func menuButtonPressed(_ sender: UIButton) {
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
        } else {
            UIView.animate(withDuration: 0.5) {
                self.darkFillingView.transform = .identity
                self.toggleMenuButton.transform = .identity
                self.menuView.transform = .identity
                self.imageCountView.alpha = 0
                self.opacityView.alpha = 0
            }
        }
    }
}

//MARK: - Delegation Functions
extension MotionViewController: DrawableImageViewDelegate {
    func removeScissorView() {
        scissorView?.removeFromSuperview()
        scissorView = nil
    }
    
    func isScissorContainsTouch(location: CGPoint) -> Bool {
        guard let frame = scissorView?.frame else { return false }
        return frame.contains(view.convert(location, from: drawableImageView))
    }
    
    func previewTheTouchedPoint(touch: UITouch) {
        
        let snapshotImage = UIImage(view: drawableImageView, scale: UIScreen.main.scale)
        
        tempImageView?.image = snapshotImage
        
        var location = touch.location(in: drawableImageView)
        
        location.x = min(drawableImageView.frame.width - 40, max(location.x, 40))
        location.y = min(drawableImageView.frame.height - 40, max(location.y, 40))
        
        let diff = CGPoint(x: location.x - drawableImageView.center.x, y: location.y - drawableImageView.center.y)
        tempImageView?.center = CGPoint(x: preView.frame.width / 2 - diff.x, y: preView.frame.height / 2 - diff.y)
    }
    
    func removePreviewImage() {
        tempImageView?.image = nil
    }

    func createMotioningViews(lastPoint: CGPoint) {
        if motionUIArray.isEmpty {
            viewHandler(lastPoint: lastPoint, isNew: true, sender: "touch")
        }
        else {
            viewHandler(lastPoint: lastPoint, isNew: false, sender: "touch")
        }
    }
    
    func didTouchedOutsidePath() {
        maskedImageView?.removeFromSuperview()
        maskedImageView = nil
        
        if motionUIArray.isEmpty { return }
        
        for item in motionUIArray {
            item.removeFromSuperview()
        }
        motionUIArray.removeAll()
    }
    
    func createMaskedImageView(path: UIBezierPath) {
        guard let imageView = drawableImageView.imageView else { return }
        let rect: CGRect = imageView.frame
        
        maskedImageView = UIImageView(frame: rect)
        maskedImageView?.image = imageView.image
        maskedImageView?.isUserInteractionEnabled = false
        
        let maskLayer = CAShapeLayer()
        maskLayer.frame = CGRect(origin: .zero, size: rect.size)
        maskLayer.path = path.cgPath
        maskedImageView?.layer.mask = maskLayer
        
        drawableImageView.addSubview(maskedImageView!)
    }
    
    func createScissorView(location: CGPoint) {
        scissorView = UIImageView(image: UIImage(named: "scissor"))
        scissorView?.frame = CGRect(origin: CGPoint.zero, size: CGSize(width: 24, height: 24))
        scissorView?.contentMode = .scaleAspectFit
        scissorView?.tintColor = UIColor.white
        scissorView?.center = view.convert(location, from: drawableImageView)
        
        if drawableImageView.pathPoints.count > 1 {
            guard let p1 = drawableImageView.pathPoints.last else { return }
            let p2 = drawableImageView.pathPoints[drawableImageView.pathPoints.count - 2]
            
            let angle: CGFloat!
            if p2.x - p1.x > 0 {
                angle = atan((p2.y - p1.y) / (p2.x - p1.x)) - CGFloat.pi / 180 * 90
            }
            else {
                angle = atan((p2.y - p1.y) / (p2.x - p1.x)) + CGFloat.pi / 180 * 90
            }
            
            scissorView?.transform = CGAffineTransform(rotationAngle: angle)
            
            self.view.addSubview(scissorView!)
        }
    }
}

//MARK: - ScrollView
extension MotionViewController: UIScrollViewDelegate {
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return drawableImageView
    }
    
    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        setContentInset(scrollView)
        guard let lastPoint = drawableImageView.touchPoints.last else {return}
        scissorView?.center = view.convert(lastPoint, from: drawableImageView)
        view.bringSubviewToFront(topContainer)
    }
    
    func setContentInset(_ scrollView: UIScrollView) {
        let imageViewSize = drawableImageView.frame.size
        let scrollViewSize = scrollView.bounds.size
        
        let verticalPadding = imageViewSize.height < scrollViewSize.height ? (scrollViewSize.height - imageViewSize.height) / 2 : 0
        let horizontalPadding = imageViewSize.width < scrollViewSize.width ? (scrollViewSize.width - imageViewSize.width) / 2 : 0
        // this is the distance that the content view is inset from the enclosing scroll view.
        scrollView.contentInset = UIEdgeInsets(top: verticalPadding, left: horizontalPadding, bottom: verticalPadding, right: horizontalPadding)
    }
}

//MARK: - Helper Functions
extension MotionViewController {
    //creates, relocates the views
    func viewHandler(lastPoint: CGPoint, isNew: Bool, sender: String) {
        
        guard let imageView = drawableImageView.imageView, let path = drawableImageView.path else { return }
        
        let sPx = path.bounds.origin.x + path.bounds.width / 2
        let sPy = path.bounds.origin.y + path.bounds.height / 2
        
        for i in 0..<motionImageCount {
            
            let diffX = (lastPoint.x - sPx) / CGFloat(motionImageCount)
            let centerX = imageView.center.x + (CGFloat(i) + 1) * diffX
            let diffY = (lastPoint.y - sPy) / CGFloat(motionImageCount)
            let centerY = imageView.center.y + (CGFloat(i) + 1) * diffY
            
            if sender == "touch" {
                if isNew {
                    let tempView = UIImageView(frame: imageView.frame)
                    tempView.isUserInteractionEnabled = false
                    tempView.image = imageView.image
                    tempView.center = CGPoint(x: centerX, y: centerY)
                    
                    guard let path = drawableImageView.path else { return }
                    maskView(tempView: tempView, path: path)

                    tempView.alpha = CGFloat(1 - 0.9 / Double(motionImageCount) * Double(i))

                    motionUIArray.append(tempView)
                    drawableImageView.addSubview(tempView)

                    drawableImageView.bringSubviewToFront(maskedImageView!)
                } else {
                    let curView = motionUIArray[i]
                    curView.center = CGPoint(x: centerX, y: centerY)
                }
            } else {
                let curView = motionUIArray[i]

                curView.alpha = CGFloat(1 - 0.9 / Double(motionImageCount) * Double(i))
                curView.center = CGPoint(x: centerX, y: centerY)
            }
        }
    }
    //masks the given view according to path
    func maskView(tempView: UIImageView, path: UIBezierPath) {
        guard let imageView = drawableImageView.imageView else { return }
        let rect: CGRect = imageView.frame
        let maskLayer = CAShapeLayer()
        maskLayer.frame = CGRect(origin: .zero, size: rect.size)
        maskLayer.path = path.cgPath
        tempView.layer.mask = maskLayer
    }
    
    func captureScreenshot(view: UIView) -> UIImage {
        return UIImage(view: view, scale: UIScreen.main.scale)
    }
}
