import UIKit

extension Touches_Label {
    var image: UIImage? {
        switch self {
        case .checkmark:
            return UIImage(named: "checkmark")!
        case .xmark:
            return UIImage(named: "x_mark")!
        case .lineAscending:
            return UIImage(named: "diagonal_line")!
        case .scribble:
            return UIImage(named: "scribble")!
        case .circle:
            return UIImage(named: "circle")!
        case .semicircleOpenUp:
            return UIImage(named: "u_shape")!
        case .heart:
            return UIImage(named: "heart")!
        case .plusSign:
            return UIImage(named: "plus_sign")!
        case .questionMark:
            return UIImage(named: "question_mark")!
        case .letterACapital:
            return UIImage(named: "capital_a")!
        case .letterBCapital:
            return UIImage(named: "capital_b")!
        case .faceHappy:
            return UIImage(named: "happy_face")!
        case .faceSad:
            return UIImage(named: "sad_face")!
        default:
            return nil
        }
    }
}

