import UIKit

class StorySequencePlayer: UIView {
    /* *******************************
     MARK: Properties
     ******************************* */
    weak var delegate: StorySequencePlayerDelegate?

    let fontName: String = "Montserrat-Bold",
        fontSize: CGFloat = 16,
        indicatorImage: String = "indicator_placeholder",
        baseAnimDuration: Double = 0.5

    var textContainer: UIView,
        imageViewContainer: UIView,
        leftImageView: UIImageView,
        rightImageView: UIImageView,
        indicator: UIImageView

    var model: StorySequence,
        currentStep: Int

    var imgNear: CGFloat,
        imgMid: CGFloat,
        imgFar: CGFloat

    var soundPlayer: SoundPlayer = SoundPlayer()

    private var canTap: Bool

    // for easy access to accessibility identifiers
    enum AccessibilityIdentifiers: String {
        case storySequencePlayer = "story-sequence-player"
        case skipWarningView = "ssp-skip-warning-view"
        case skipWarningYes = "ssp-skip-warning-view-button-yes"
        case skipWarningNo = "ssp-skip-warning-view-button-no"
    }

    /* *******************************
     MARK: Initializers
     ******************************* */
    required init(coder aDecoder: NSCoder) {
        fatalError("This class does not support NSCoding")
    }

    override init(frame: CGRect) {
        self.model = StorySequence(music: nil, [:])
        self.textContainer = UIView(frame: CGRect.zero)
        self.imageViewContainer = UIView(frame: CGRect.zero)
        self.leftImageView = UIImageView(frame: CGRect.zero)
        self.rightImageView = UIImageView(frame: CGRect.zero)
        self.indicator = UIImageView(frame: CGRect.zero)

        self.currentStep = -1
        self.canTap = false

        self.imgNear = 0
        self.imgMid = 0
        self.imgFar = 0

        super.init(frame: frame)

        self.accessibilityIdentifier = AccessibilityIdentifiers.storySequencePlayer.rawValue
        let margin: CGFloat = 10
        let imageViewHeight: CGFloat = 0.6

        addBlur(self, .dark)
        layoutImageViews(margin, imageViewHeight)
        layoutTextContainer(margin, 1 - imageViewHeight)
        addTapGesture()
        addLPGesture()
    }

    convenience init(delegate: StorySequencePlayerDelegate?, model: StorySequence) {
        self.init(frame: UIScreen.main.bounds)

        self.delegate = delegate
        self.model = model
        DispatchQueue.global(qos: .background).async {
            DispatchQueue.main.asyncAfter(deadline: .now() + self.baseAnimDuration) {
                self.checkCurrentStep()
                let soundFile = self.model.music
                guard let sound = soundFile else { return }
                self.soundPlayer.numberOfLoops = -1
                self.soundPlayer.playSound(sound, 0.1)
            }
        }
    }

    /* *******************************
     MARK: Private Class Functions
     ******************************* */
    // Add a full screen blurred view as the background layer
    private func addBlur(_ view: UIView, _ style: UIBlurEffectStyle) {
        let blur = UIBlurEffect(style: UIBlurEffectStyle.dark)
        let blurView = UIVisualEffectView(effect: blur)
        blurView.frame = view.bounds
        blurView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(blurView)
    }

    // layout the image container in the main view, layout the imageviews in the image container, also add the indicator view
    private func layoutImageViews(_ margin: CGFloat, _ height: CGFloat) {
        let containerW = self.bounds.width - (margin * 2)
        let containerH = self.bounds.height * height

        imageViewContainer.frame = CGRect(x: margin, y: self.bounds.height - containerH, width: containerW, height: containerH)

        let bounds = imageViewContainer.bounds
        let imageWidth: CGFloat = bounds.width * 0.3
        let imageHeight: CGFloat = bounds.height

        let leftRect = CGRect(x: 0, y: 0, width: imageWidth, height: imageHeight)
        let rightRect = CGRect(x: bounds.width - imageWidth, y: 0, width: imageWidth, height: imageHeight)

        leftImageView.frame = leftRect
        rightImageView.frame = rightRect

        leftImageView.contentMode = .scaleAspectFit
        rightImageView.contentMode = .scaleAspectFit

        leftImageView.isOpaque = true
        rightImageView.isOpaque = true

        imgMid = (imageViewContainer.bounds.width / 4) - (imageWidth / 2)
        imgFar = (imageViewContainer.bounds.width / 2) - imageWidth

        moveImage(pos: .hidden, view: leftImageView, left: true)
        moveImage(pos: .hidden, view: rightImageView, left: false)

        let indicatorSize = 15
        indicator.frame = CGRect(x: 0, y: 0, width: indicatorSize, height: indicatorSize)
        indicator.contentMode = .scaleAspectFit
        indicator.image = UIImage(named: indicatorImage)
        indicator.center = CGPoint(x: (self.bounds.width / 2), y: self.bounds.height - indicator.frame.height)
        hideIndicator()

        imageViewContainer.addSubview(leftImageView)
        imageViewContainer.addSubview(rightImageView)
        self.addSubview(imageViewContainer)
        self.addSubview(indicator)
    }

    // layout the text container
    private func layoutTextContainer(_ margin: CGFloat, _ height: CGFloat) {
        let containerW = self.bounds.width - (margin * 2)
        let containerH = (self.bounds.height * height) - (margin * 2)
        textContainer.frame = CGRect(x: margin, y: margin, width: containerW, height: containerH)
        textContainer.layer.masksToBounds = true
        textContainer.layer.cornerRadius = 12

        self.addSubview(textContainer)
    }

    // add a tap gesture to manually step through the story sequence
    private func addTapGesture() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(self.tapView(_:)))
        self.addGestureRecognizer(tap)
    }

    @objc private func tapView(_ sender: UITapGestureRecognizer) {
        if canTap {
            checkCurrentStep()
        }
    }

    // add a long press gesture to skip the story sequence
    private func addLPGesture() {
        let lp = UILongPressGestureRecognizer(target: self, action: #selector(self.lpView(_:)))
        self.addGestureRecognizer(lp)
    }

    @objc private func lpView(_ sender: UILongPressGestureRecognizer) {
        if sender.state == UIGestureRecognizerState.began {
            displaySkipWarning()
        }
    }

    private func displaySkipWarning() {
        let view = UIView(frame: self.bounds)
        view.accessibilityIdentifier = AccessibilityIdentifiers.skipWarningView.rawValue

        let warningView = UIView(frame: CGRect(x: 0, y: 0, width: self.frame.width, height: self.frame.height / 2))
        warningView.center = CGPoint(x: self.bounds.width / 2, y: self.bounds.height / 2)

        if #available(iOS 10.0, *) {
            addBlur(view, .prominent)
            addBlur(warningView, .prominent)
        } else {
            addBlur(view, .extraLight)
            addBlur(warningView, .extraLight)
        }

        let bounds = warningView.bounds
        let topContainer = UIView(frame: CGRect(x: 0, y: 0, width: bounds.width, height: bounds.height / 2))
        let botContainer = UIView(frame: CGRect(x: 0, y: bounds.height / 2, width: bounds.width, height: bounds.height / 2))

        let label = UILabel(frame: topContainer.bounds)
        label.font = UIFont(name: fontName, size: fontSize * 2)
        label.textColor = UIColor.white
        label.textAlignment = .center
        label.text = "Ready to skip?"

        let botBounds = botContainer.bounds
        let yes = UIButton(frame: CGRect(x: 0, y: 0, width: botBounds.width / 2, height: botBounds.height))
        yes.accessibilityIdentifier = AccessibilityIdentifiers.skipWarningYes.rawValue
        yes.addTarget(self, action: #selector(tapSkipButton(_:)), for: .touchUpInside)
        yes.setTitle("Yes", for: .normal)
        yes.tag = 1

        let no = UIButton(frame: CGRect(x: botBounds.width / 2, y: 0, width: botBounds.width / 2, height: botBounds.height))
        no.accessibilityIdentifier = AccessibilityIdentifiers.skipWarningNo.rawValue
        no.addTarget(self, action: #selector(tapSkipButton(_:)), for: .touchUpInside)
        no.setTitle("No", for: .normal)

        topContainer.addSubview(label)
        botContainer.addSubview(yes)
        botContainer.addSubview(no)
        warningView.addSubview(topContainer)
        warningView.addSubview(botContainer)
        view.addSubview(warningView)
        self.addSubview(view)

        let dur = 0.05
        Animate(view, dur).fadeIn()
    }

    @objc private func tapSkipButton(_ sender: UIButton?) {
        guard let button = sender else { return }
        if button.tag > 0 {
            // cancel the sequence and remove the StorySequencePlayer view
            hide()
        } else {
            // find and target the warning view for dismissal
            for view in self.subviews {
                if view.accessibilityIdentifier == AccessibilityIdentifiers.skipWarningView.rawValue {
                    let dur = 0.05
                    Animate(view, dur).fade(to: 0, then: {
                        view.removeFromSuperview()
                    })
                }
            }
        }
    }

    // check if there is another step in the sequence, update count and call ui updates, else hide and dismiss
    // called when the view is tapped (and once when the view is initialized)
    private func checkCurrentStep() {
        // stop interactions, enabled after updateToCurrentStep is complete
        self.canTap = false
        hideIndicator()

        if currentStep < model.steps.count - 1 {
            currentStep = currentStep + 1
            updateToCurrentStep()
        } else {
            hide()
        }
    }

    // these functions check for data in the model and calls the appropriate updates
    private func updateToCurrentStep() {
        updateLeftSide()
        updateRightSide()

        // wait double the baseAnimDuration
        let dur = baseAnimDuration * 2
        DispatchQueue.global(qos: .background).async {
            DispatchQueue.main.asyncAfter(deadline: .now() + dur) {
                self.canTap = true
                self.showIndicator()
            }
        }
    }

    /**
     Important: Should handle alpha for left and right text at the same time. Right now it'll fade the left text since it reads left to right and fades all text other than the latest.
     */
    private func updateLeftSide() {
        guard let m = model.steps[currentStep]!.lftEvent else { return }
        if m.image != nil {
            changeImage(imageView: leftImageView, image: m.image!)
        }
        if m.position != nil {
            moveImage(pos: m.position!, view: leftImageView, left: true)
        }
        if m.imgAnim != nil {
            DispatchQueue.global(qos: .background).async {
                DispatchQueue.main.asyncAfter(deadline: .now() + self.baseAnimDuration) {
                    self.doAnimation(anim: m.imgAnim!, view: self.leftImageView)
                }
            }
        }
        if m.text != nil {
            let label = self.makeLabel(text: m.text!, left: true)
            self.textContainer.addSubview(label)
            shiftLabels()
        }
    }

    private func updateRightSide() {
        guard let m = model.steps[currentStep]!.rgtEvent else { return }
        if m.image != nil {
            changeImage(imageView: rightImageView, image: m.image!)
        }
        if m.position != nil {
            moveImage(pos: m.position!, view: rightImageView, left: false)
        }
        if m.imgAnim != nil {
            DispatchQueue.global(qos: .background).async {
                DispatchQueue.main.asyncAfter(deadline: .now() + self.baseAnimDuration) {
                    self.doAnimation(anim: m.imgAnim!, view: self.rightImageView)
                }
            }
        }
        if m.text != nil {
            let label = self.makeLabel(text: m.text!, left: false)
            self.textContainer.addSubview(label)
            shiftLabels()
        }
    }

    // return a formatted label
    private func makeLabel(text: String, left: Bool) -> UILabel {
        // determine properties based on container bounds
        let margin: CGFloat = 10
        let bounds = textContainer.bounds
        let width = (bounds.width - (margin * 4)) / 2
        let height = (bounds.height - (margin * 2)) / 4
        let y = bounds.height - margin
        // determine if it's on the left or right side
        let x = (left) ? margin : bounds.width - width - margin

        let label = UILabel(frame: CGRect(x: x, y: y, width: width, height: height))

        // set basic properties
        label.textColor = UIColor.white
        label.font = UIFont(name: fontName, size: fontSize)
        label.text = text
        label.textAlignment = (left) ? .left : .right

        // resize and reformat to account for word wrapping
        label.numberOfLines = 0
        label.preferredMaxLayoutWidth = width
        label.lineBreakMode = NSLineBreakMode.byWordWrapping
        label.sizeToFit()

        // force width back to original value
        label.frame.size.width = width

        return label
    }

    // shift labels up as new labels are added
    private func shiftLabels() {
        // get subviews from the textcontainer
        let labels = textContainer.subviews

        // 50% longer than the baseAnimDuration
        let dur = baseAnimDuration + (baseAnimDuration / 2)
        let fadeTo: Float = 0.2

        DispatchQueue.global(qos: .background).async {
            DispatchQueue.main.async {
                // if there are labels, get the height of the newly added label and shift all labels by that amount + a buffer
                let buffer: CGFloat = 15
                let height = (labels.count > 0) ? labels.last!.frame.size.height + buffer : 0

                // loop through and shift the labels, reduce alpha for old labels
                for label in labels {
                    // animate moving all labels, use random value to make the spring jiggle more dynamic
                    Animate(label, dur).setSpring(0.6, 6.5 + (self.randomCGFloat() * 8)).setOptions(.curveEaseOut).move(by: [0, -height])

                    // if the label isnt't the new label, and alpha is still 1, then reduce alpha
                    if label != labels.last {
                        if label.alpha == 1 {
                            Animate(label, dur).fade(to: fadeTo)
                        }
                    }
                }
            }

            // wait until shifting animations are done, and deal with labels moving off screen
            DispatchQueue.main.asyncAfter(deadline: .now() + dur) {
                for label in labels {
                    // remove old labels
                    if label.alpha == 0 {
                        label.removeFromSuperview()
                    }
                    // fade out labels if that may be partially on screen
                    if label.frame.origin.y < 0 {
                        Animate(label, self.baseAnimDuration).fade(to: 0)
                    }
                }
            }
        }
    }

    // returns a random CGFloat 0 - 1
    private func randomCGFloat() -> CGFloat {
        return CGFloat(Float(arc4random()) / Float(UINT32_MAX))
    }

    // fade out view, then change image, then fade in view
    private func changeImage(imageView: UIImageView, image: String) {
        imageView.image = UIImage(named: image)
    }

    // determine x position and animate moving the imageView
    private func moveImage(pos: StorySequence.ImagePosition, view: UIImageView, left: Bool) {
        var x: CGFloat

        switch pos {
        case .near:
            x = 0
        case .mid:
            x = imgMid
        case .far:
            x = imgFar
        case .hidden:
            x = -view.frame.width * 2
        }

        x = (left) ? x : imageViewContainer.bounds.width - view.bounds.width - x

        let v = Animate(view, baseAnimDuration)
        v.move(to: [x, view.frame.origin.y])
    }

    private func hideIndicator() {
        indicator.isHidden = true
        blinkIndicator()
    }

    private func showIndicator() {
        indicator.isHidden = false
        blinkIndicator()
    }

    // blink the indicator, turn off if the view is hidden
    private func blinkIndicator() {
        let dur = baseAnimDuration + (baseAnimDuration / 2)
        var flash = true
        if indicator.isHidden {
            flash = false
        }
        Animate(indicator, dur).flashing(flash)
    }

    private func doAnimation(anim: StorySequence.ImageAnimation, view: UIView) {
        let duration = 0.4
        let tiltDuration = 0.7
        switch anim {
        case .shake:
            Animate(view, duration).setDelay(baseAnimDuration / 3).shake()
        case .tiltLeft:
            Animate(view, tiltDuration).tilt(degrees: -30)
        case .tiltRight:
            Animate(view, tiltDuration).tilt(degrees: 30)
        case .jiggle:
            Animate(view, duration).jiggle()
        case .flip:
            let v = Animate(view, tiltDuration / 2)
            v.flip(then: {
                v.flip()
            })
        }
    }

    /* *******************************
     MARK: Public Class Methods
     ******************************* */
    func hide() {
        if #available(iOS 10.0, *) {
            soundPlayer.player?.setVolume(0, fadeDuration: baseAnimDuration)
        }
        let v = Animate(self, baseAnimDuration)
        v.fade(to: 0, then: {
            self.soundPlayer.player?.stop()
            self.delegate?.sequenceDidFinish(sender: self)
        })
    }

}

/* *******************************
 MARK: Delegate Methods
 ******************************* */
protocol StorySequencePlayerDelegate: AnyObject {
    func sequenceDidFinish(sender: StorySequencePlayer)
}
