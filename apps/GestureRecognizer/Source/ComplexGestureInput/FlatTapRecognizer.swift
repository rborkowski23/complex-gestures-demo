import UIKit
import UIKit.UIGestureRecognizerSubclass

class FlatTapRecognizer: UIGestureRecognizer {
    private var touch: UITouch?
    private var startPosition: CGPoint?
    private var conditionsMet = false
    private var distanceFromStart: CGFloat {
        guard let touch = touch, let startPos = startPosition else {
            return 0
        }
        
        let currentPos = touch.location(in: view)
        let diffX = startPos.x - currentPos.x
        let diffY = startPos.y - currentPos.y
        
        return sqrt(diffX * diffX + diffY * diffY)
    }
    
    // For debugging
//    private var maxMajorRadius = CGFloat(0)
//    private var maxTranslationDistance = CGFloat(0)
    
    var minimumMajorRadius = CGFloat(55)
    var maximumTranslationDistance = CGFloat(60)
    // Pros and cons. When true, recognition will be slightly faster, but a
    // flat finger used to scroll will be recognized (bad).
    var recognizeImmediatelyOnMetConditions = false
    
    private func update() {
        guard let touch = touch, state == .possible else {
            return
        }
        
//        maxMajorRadius = max(touch.majorRadius, maxMajorRadius)
//        maxTranslationDistance = max(distanceFromStart, maxTranslationDistance)
        
        if distanceFromStart > maximumTranslationDistance {
            state = .failed
            return
        }
        
        if touch.majorRadius >= minimumMajorRadius {
            conditionsMet = true
            
            if recognizeImmediatelyOnMetConditions {
                state = .recognized
            }
        }
    }

    // MARK: UIGestureRecognizer
    
    override func reset() {
        super.reset()
        
//        print("maxMajorRadius", maxMajorRadius)
//        print("maxTranslationDistance", maxTranslationDistance)
        
        touch = nil
        startPosition = nil
        conditionsMet = false
        
//        maxMajorRadius = 0
//        maxTranslationDistance = 0
        
        // Resetting to .possible
        state = .possible
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)
        
        if state == .possible {
            touch = touches.first!
            startPosition = touch?.location(in: view)
            update()
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesMoved(touches, with: event)
        
        update()
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesEnded(touches, with: event)
        
        update()
        
        if state == .possible, let touch = touch, touches.contains(touch) {
            if conditionsMet {
                state = .recognized
            } else {
                state = .failed
            }
        }
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesCancelled(touches, with: event)
        
        if state == .possible, let touch = touch, touches.contains(touch) {
            state = .failed
        }
    }
}
