import UIKit

enum States {
    case initial
    case drawing
    case drawed
    case motioning
    case motioned
}

protocol DrawableImageViewDelegate {
    func createMaskedImageView(path: UIBezierPath)
    func createMotioningViews(lastPoint: CGPoint)
    func createScissorView(location: CGPoint)
    func previewTheTouchedPoint(touch: UITouch)
    func removePreviewImage()
    func removeScissorView()
    func didTouchedOutsidePath()
    func isScissorContainsTouch(location: CGPoint) -> Bool
}

class DrawableImageView: UIView {
    
    var imageView: UIImageView?
    
    //MARK: - Drawing
    var dashedLayer = CAShapeLayer()
    var path: UIBezierPath?
    var touchPoints = [CGPoint]()
    var pathPoints = [CGPoint]()
    var isDrawing: Bool = false
    
    var delegate: DrawableImageViewDelegate!
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        customInit()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        customInit()
    }
    
    private func customInit() {
        imageView = UIImageView(frame: self.frame)
        self.addSubview(imageView!)
        //initiliaze the path
        path = UIBezierPath()
        // ImageView Constraints
        imageView?.contentMode = .scaleAspectFill
        imageView?.translatesAutoresizingMaskIntoConstraints = false
        let centerXConstraint = NSLayoutConstraint(item: imageView!, attribute: NSLayoutConstraint.Attribute.centerX,
                                                   relatedBy: NSLayoutConstraint.Relation.equal, toItem: self,
                                                   attribute: NSLayoutConstraint.Attribute.centerX, multiplier: 1, constant: 0)
        let centerYConstraint = NSLayoutConstraint(item: imageView!, attribute: NSLayoutConstraint.Attribute.centerY,
                                                   relatedBy: NSLayoutConstraint.Relation.equal, toItem: self,
                                                   attribute: NSLayoutConstraint.Attribute.centerY, multiplier: 1, constant: 0)
        let widthConstraint = NSLayoutConstraint(item: imageView!, attribute: NSLayoutConstraint.Attribute.width,
                                                 relatedBy: NSLayoutConstraint.Relation.equal, toItem: self,
                                                 attribute: NSLayoutConstraint.Attribute.width, multiplier: 1, constant: 0)
        let heightConstraint = NSLayoutConstraint(item: imageView!, attribute: NSLayoutConstraint.Attribute.height,
                                                  relatedBy: NSLayoutConstraint.Relation.equal, toItem: self,
                                                  attribute: NSLayoutConstraint.Attribute.height, multiplier: 1, constant: 0)
        self.addConstraints([centerXConstraint, centerYConstraint, widthConstraint, heightConstraint])
        
        dashedLayer.lineDashPattern = [8, 6]
        dashedLayer.strokeColor = UIColor.black.cgColor
        dashedLayer.fillColor = nil
        self.layer.addSublayer(dashedLayer)
    }
    
    
    override func draw(_ rect: CGRect) {
        super.draw(rect)
        //check if points array contains some points
        if pathPoints.isEmpty {
            return
        }
        //initiliaze the path
        path = UIBezierPath()
        //draw the path by using the points inside points array
        path?.move(to: pathPoints.first!)
        for point in pathPoints {
            path?.addLine(to: point)
        }
        //if the drawing is finished, close the path and start line animations
        if !isDrawing {
            path?.close()
            dashedLayer.path = path?.cgPath
            animateDashedLayer()
        } else {
            dashedLayer.path = path?.cgPath
        }
    }
    
    private func animateDashedLayer() {
        //dashed line animation
        let animation_0 = CABasicAnimation(keyPath: "lineDashPhase")
        animation_0.fromValue = 0
        animation_0.toValue = dashedLayer.lineDashPattern?.reduce(0) { $0 - $1.intValue } ?? 0
        animation_0.duration = 1
        animation_0.repeatCount = .infinity
        //line color change animation
        let animation_1 = CABasicAnimation(keyPath: "strokeColor")
        animation_1.fromValue = UIColor.black.cgColor
        animation_1.toValue = UIColor.green.cgColor
        animation_1.duration = 1
        animation_1.autoreverses = true
        animation_1.repeatCount = .infinity
        //add animations to the layer
        dashedLayer.add(animation_0, forKey: "dashedLineAnimation")
        dashedLayer.add(animation_1, forKey: "lineColorAnimation")
    }
    
    //MARK: - Touch Handling
    var motionState: States = .initial
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        //get the drawed path and the location of the touched point
        guard let tempPath = path, let touch = touches.first else { return }
        let location = touch.location(in: self)
        //this variable avoids the path from closing
        isDrawing = true
        
        if motionState == .initial {
            //update the state
            motionState = .drawing
            //draw the starting point
            pathPoints.append(location)
            self.setNeedsDisplay()
            //preview the touched point
            self.delegate.previewTheTouchedPoint(touch: touch)
        }
        else if motionState == .drawing {
            //if the user touched to scissor
            if self.delegate.isScissorContainsTouch(location: location) {
                //remove scissor
                self.delegate.removeScissorView()
            } else { //if the user touched someone else
                //remove scissor
                self.delegate.removeScissorView()
                //remove the pre-created views for motioning
                self.delegate.didTouchedOutsidePath()
                //clear the path
                path?.removeAllPoints()
                pathPoints.removeAll()
                //draw the touched point
                pathPoints.append(location)
                self.setNeedsDisplay()
                //preview the touched point
                self.delegate.previewTheTouchedPoint(touch: touch)
            }
        }
        else if motionState == .drawed {
            //if the touched point is inside the path, update the state and stop the animations
            if tempPath.contains(location) {
                motionState = .motioning
                dashedLayer.removeAllAnimations()
            } else { //if the touched point IS NOT inside the path, reset the state
                motionState = .drawing
                //remove the pre-created views for motioning
                self.delegate.didTouchedOutsidePath()
                //clear the path
                path?.removeAllPoints()
                pathPoints.removeAll()
                //draw the touched point
                pathPoints.append(location)
                self.setNeedsDisplay()
                //preview the touched point
                self.delegate.previewTheTouchedPoint(touch: touch)
            }
        }
        else if motionState == .motioned {
            //if the touched point is inside the path, update the state
            if tempPath.contains(location) {
                motionState = .motioning
            } else { //if the touched point IS NOT inside the path, reset the state
                motionState = .drawing
                //remove the pre-created views for motioning
                self.delegate.didTouchedOutsidePath()
                //clear the path
                path?.removeAllPoints()
                pathPoints.removeAll()
                //draw the touched point
                pathPoints.append(location)
                self.setNeedsDisplay()
                //preview the touched point
                self.delegate.previewTheTouchedPoint(touch: touch)
            }
        }
        touchPoints.removeAll()
        touchPoints.append(location)
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        //get the drawed path and the location of the touched point
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        
        if motionState == .drawing {
            //draw the touched point
            pathPoints.append(location)
            self.setNeedsDisplay()
            //preview the touched point
            self.delegate.previewTheTouchedPoint(touch: touch)
        }
        else if motionState == .motioning {
            //create the motion views
            self.delegate.createMotioningViews(lastPoint: location)
        }
        
        touchPoints.append(location)
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        //get the drawed path and the location of the touched point
        guard let tempPath = path, let touch = touches.first else { return }
        let location = touch.location(in: self)
        
        if motionState == .drawing {
            
            if distance(location, pathPoints.first!) > 50 {
                self.delegate.createScissorView(location: location)
                return
            }
            
            motionState = .drawed
            //close the path
            isDrawing = false
            //draw the touched point
            pathPoints.append(location)
            self.setNeedsDisplay()
            //remove the preview's image
            self.delegate.removePreviewImage()
            //create the masked view
            self.delegate.createMaskedImageView(path: tempPath)
        }
        else if motionState == .motioning {
            motionState = .motioned
        }
        
        touchPoints.append(location)
        
//        print("first: \(String(describing: touchPoints.first)) \nlast: \(String(describing: touchPoints.last))")
    }
    
    func distance(_ a: CGPoint, _ b: CGPoint) -> Float {
        return hypotf(Float(a.x - b.x), Float(a.y - b.y))
    }
}
