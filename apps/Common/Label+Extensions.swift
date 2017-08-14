import Foundation

extension Touches_Label {
    // Must be kept in the same order they occur in the .proto file since the
    // model generates outputs in that order without space between them.
    static var all: [Touches_Label] = [
        .other,
        .checkmark,
        .xmark,
        .lineAscending,
        .scribble,
        .circle,
        .semicircleOpenUp,
        .heart,
        .plusSign,
        .questionMark,
        .letterACapital,
        .letterBCapital,
        .faceHappy,
        .faceSad
    ]
    
    static func random() -> Touches_Label {
        let randomIndex = Int(arc4random_uniform(UInt32(all.count)))
        return all[randomIndex]
    }
    
    var name: String {
        switch self {
        case .other:
            return "Other"
        case .checkmark:
            return "Checkmark"
        case .xmark:
            return "X mark"
//        case .lineVertical:
//            return "vertical line"
        case .lineAscending:
            return "Ascending diagonal"
        case .scribble:
            return "Scribble"
        case .circle:
            return "Circle"
//        case .triangle:
//            return "triangle"
//        case .square:
//            return "square"
        case .semicircleOpenUp:
            return "U shape"
//        case .semicircleOpenDown:
//            return "semcircle open down"
//        case .vOpenUp:
//            return "v open up"
//        case .vOpenDown:
//            return "v open down"
        case .heart:
            return "Heart"
        case .plusSign:
            return "Plus sign"
//        case .minusSign:
//            return "minus sign"
        case .questionMark:
            return "Question mark"
//        case .tilde:
//            return "tilde"
        case .letterACapital:
            return "Capital A"
        case .letterBCapital:
            return "Capital B"
//        case .letterCCapital:
//            return "capital c"
        case .faceHappy:
            return "Happy face"
        case .faceSad:
            return "Sad face"
        case .UNRECOGNIZED(let i):
            return "UNRECOGNIZED(\(String(i)))"
        }
    }
}
