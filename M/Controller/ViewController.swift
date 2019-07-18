import UIKit

class ViewController: UIViewController {
    
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var motionButton: UIButton!
    
    var selectedImage: UIImage?
    
    var imagePicker: ImagePicker!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        motionButton.isEnabled = false
        imagePicker = ImagePicker(presentationController: self, delegate: self)
    }
    
    @IBAction func addPhotoButtonPressed(_ sender: UIButton) {
        imagePicker.present(from: sender)
        motionButton.isEnabled = true
    }
    
    @IBAction func motionButtonPressed(_ sender: UIButton) {
        if imageView.image == nil {
            motionButton.isEnabled = false
            popAlert()
            return
        } else {
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            let vc = storyboard.instantiateViewController(withIdentifier: "MotionViewController") as! MotionViewController
            vc.image = selectedImage
            present(vc, animated: true, completion: nil)
        }
    }
    
    // FUN ALERT
    func popAlert() {
        let alertController = UIAlertController(title: "Where the heck is image?", message: nil, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: { ctx in
            alertController.dismiss(animated: true, completion: nil)
        }))
        self.present(alertController, animated: true, completion: nil)
    }
}

extension ViewController: ImagePickerDelegate {
    func didSelect(image: UIImage?) {
        self.selectedImage = image
        imageView.image = image
    }
}
