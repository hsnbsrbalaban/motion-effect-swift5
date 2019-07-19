import UIKit

class Device {
    static var safeAreaInset: UIEdgeInsets {
        guard let window = UIApplication.shared.keyWindow else { return .zero }
        return window.safeAreaInsets
    }
}

class MotionViewController: UIViewController {
    
    @IBOutlet weak var topContainer: UIView!
    @IBOutlet weak var bottomContainer: UIView!
    
    @IBOutlet weak var invisibleButton: UIButton!
    @IBOutlet weak var preView: UIImageView!
    
    //TODO: - Scissor is missing
    
    var image: UIImage!
    var drawableImageView: DrawableImageView!
    var maskedImageView: UIImageView?
    var scissorView: UIImageView?
    
    var motionImageCount: Int = 10
    var motionImageAlpha: Int = 100
    var motionUIArray = [UIImageView]()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Create imageView
        let calculatedHeight = view.frame.height - Device.safeAreaInset.top - Device.safeAreaInset.bottom
        let imageViewSizeConstant = min(view.frame.size.width / image.size.width,
                                        (calculatedHeight - 280) / image.size.height)
        drawableImageView = DrawableImageView(frame: CGRect(origin: CGPoint.zero,
                                                    size: CGSize(width: image.size.width * imageViewSizeConstant,
                                                                 height: image.size.height * imageViewSizeConstant)))
        let centerHeight = ((calculatedHeight - topContainer.frame.height - bottomContainer.frame.height) / 2) + topContainer.frame.height + Device.safeAreaInset.top
        drawableImageView.center = CGPoint(x: self.view.center.x, y: centerHeight)
        drawableImageView.clipsToBounds = true
        // Set the image of imageView
        drawableImageView.imageView?.image = image
        drawableImageView.delegate = self
        
        view.addSubview(drawableImageView)
        
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
    
    @IBAction func discardButton(_ sender: UIButton) {
        let alertController = UIAlertController(title: "Discard changes?", message: nil, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "Yep", style: .default, handler: { ctx in
            self.dismiss(animated: true, completion: nil)
        }))
        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        
        self.present(alertController, animated: true, completion: nil)
    }

    @IBAction func saveButton(_ sender: UIButton) {
        //TODO: - save button will be implemented
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
                let tempView = UIImageView(frame: drawableImageView.imageView!.frame)
                tempView.image = drawableImageView.imageView!.image
                tempView.isUserInteractionEnabled = false
                
                maskView(tempView: tempView, path: drawableImageView.path!)
                
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
                let yPos: CGFloat = self.menuView.frame.height - self.view.frame.maxY + self.view.convert(self.menuView.frame, from: self.menuView.superview).origin.y + Device.safeAreaInset.bottom - 8
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
        return frame.contains(location)
    }
    
    func previewTheTouchedPoint(touch: UITouch) {
        //TODO: - Preview is missing
    }
    
    func removePreviewImage() {
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
        let rect: CGRect = drawableImageView.imageView!.frame
        
        maskedImageView = UIImageView(frame: rect)
        maskedImageView?.image = drawableImageView.imageView?.image
        maskedImageView?.isUserInteractionEnabled = false
        
        let maskLayer = CAShapeLayer()
        maskLayer.frame = CGRect(origin: .zero, size: rect.size)
        maskLayer.path = path.cgPath
        maskedImageView?.layer.mask = maskLayer
        
        drawableImageView.addSubview(maskedImageView!)
    }
    
    func createScissorView(location: CGPoint) {
        scissorView = UIImageView(image: UIImage(named: "scissor"))
        scissorView?.center = location
        
        
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
            
            drawableImageView.addSubview(scissorView!)
        }
    }
}

// MARK: - Helper Functions
extension MotionViewController {
    //creates, relocates the views
    func viewHandler(lastPoint: CGPoint, isNew: Bool, sender: String) {
        
        guard let path = drawableImageView.path else { return }
        
        let sPx = path.bounds.origin.x + path.bounds.width / 2
        let sPy = path.bounds.origin.y + path.bounds.height / 2
        
        for i in 0..<motionImageCount {
            
            let diffX = (lastPoint.x - sPx) / CGFloat(motionImageCount)
            let centerX = drawableImageView.imageView!.center.x + (CGFloat(i) + 1) * diffX
            let diffY = (lastPoint.y - sPy) / CGFloat(motionImageCount)
            let centerY = drawableImageView.imageView!.center.y + (CGFloat(i) + 1) * diffY
            
            if sender == "touch" {
                if isNew {
                    let tempView = UIImageView(frame: drawableImageView.imageView!.frame)
                    tempView.isUserInteractionEnabled = false
                    tempView.image = drawableImageView.imageView?.image
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
        let rect: CGRect = drawableImageView.imageView!.frame
        let maskLayer = CAShapeLayer()
        maskLayer.frame = CGRect(origin: .zero, size: rect.size)
        maskLayer.path = path.cgPath
        tempView.layer.mask = maskLayer
    }
}
