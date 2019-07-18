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
        
        didTouchedOutsidePath()
        
        drawableImageView.path?.removeAllPoints()
        drawableImageView.points.removeAll()
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
            //TODO: - First and Last points are wrong
            guard let lastPoint = motionUIArray.first?.center else { return }
            guard let firstPoint = motionUIArray.last?.center else { return }
            
            viewHandler(firstPoint: firstPoint, lastPoint: lastPoint, path: drawableImageView.path!, sender: "slider")
        }
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
    func previewTheTouchedPoint(touch: UITouch) {
        //TODO: - Preview is missing
    }
    
    func removePreviewImage() {
        //TODO: - Preview is missing
    }

    func createMotioningViews(firstPoint: CGPoint, lastPoint: CGPoint, path: UIBezierPath) {
        viewHandler(firstPoint: firstPoint, lastPoint: lastPoint, path: path, sender: "touch")
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
}

// MARK: - Helper Functions
extension MotionViewController {
    //creates, relocates the views
    func  viewHandler(firstPoint: CGPoint, lastPoint: CGPoint, path: UIBezierPath, sender: String) {
        guard let size: CGSize = drawableImageView.imageView?.frame.size else { return }
        
        for i in 0..<motionImageCount {
            let diffX = (lastPoint.x - firstPoint.x) / CGFloat(motionImageCount) * CGFloat(i)
            let diffY = (lastPoint.y - firstPoint.y) / CGFloat(motionImageCount) * CGFloat(i)
            //if the next view will be created
            if motionUIArray.count < motionImageCount {
                //create a new view
                let tempView = UIImageView(frame: CGRect(origin: drawableImageView.imageView!.frame.origin, size: size))
                tempView.isUserInteractionEnabled = false
                tempView.image = drawableImageView.imageView?.image
                tempView.transform = CGAffineTransform(translationX: diffX, y: diffY)
                //mask the view
                maskView(tempView: tempView, path: path)
                //set its alpha
                tempView.alpha = CGFloat(1 - 0.9 / Double(motionImageCount) * Double(i))
                //add the view to screen and to motionUIArray
                motionUIArray.append(tempView)
                drawableImageView.addSubview(tempView)
                
                drawableImageView.bringSubviewToFront(maskedImageView!)
                continue
            }
            if sender == "touch" {
                let curView = motionUIArray[i]
                curView.transform = CGAffineTransform(translationX: diffX, y: diffY)
            } else { //if the caller is slider
                let curView = motionUIArray[i]
                curView.alpha = CGFloat(1 - 0.9 / Double(motionImageCount) * Double(i))
                curView.transform = CGAffineTransform(translationX: diffX, y: diffY)
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
