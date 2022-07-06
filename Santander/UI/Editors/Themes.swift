//
//  Themes.swift
//  Santander
//
//  Created by Serena on 03/07/2022
//
	

import UIKit
import Runestone

/// A Generic theme instance.
class AnyTheme: Theme {
    public init(textColor: UIColor, font: UIFont, gutterBackgroundColor: UIColor, gutterHairlineColor: UIColor, lineNumberColor: UIColor, lineNumberFont: UIFont, selectedLineBackgroundColor: UIColor, selectedLinesLineNumberColor: UIColor, selectedLinesGutterBackgroundColor: UIColor, invisibleCharactersColor: UIColor, pageGuideBackgroundColor: UIColor, pageGuideHairlineColor: UIColor, markedTextBackgroundColor: UIColor, markedTextBackgroundBorderColor: UIColor) {
        self.textColor = textColor
        self.font = font
        self.gutterBackgroundColor = gutterBackgroundColor
        self.gutterHairlineColor = gutterHairlineColor
        self.lineNumberColor = lineNumberColor
        self.lineNumberFont = lineNumberFont
        self.selectedLineBackgroundColor = selectedLineBackgroundColor
        self.selectedLinesLineNumberColor = selectedLinesLineNumberColor
        self.selectedLinesGutterBackgroundColor = selectedLinesGutterBackgroundColor
        self.invisibleCharactersColor = invisibleCharactersColor
        self.pageGuideBackgroundColor = pageGuideBackgroundColor
        self.pageGuideHairlineColor = pageGuideHairlineColor
        self.markedTextBackgroundColor = markedTextBackgroundColor
        self.markedTextBackgroundBorderColor = markedTextBackgroundBorderColor
    }
    
    var textColor: UIColor
    var font: UIFont

    let gutterBackgroundColor: UIColor
    let gutterHairlineColor: UIColor

    let lineNumberColor: UIColor
    let lineNumberFont: UIFont

    let selectedLineBackgroundColor: UIColor
    let selectedLinesLineNumberColor: UIColor
    let selectedLinesGutterBackgroundColor: UIColor

    let invisibleCharactersColor: UIColor

    let pageGuideBackgroundColor: UIColor
    let pageGuideHairlineColor: UIColor

    let markedTextBackgroundColor: UIColor
    let markedTextBackgroundBorderColor: UIColor
    
    func textColor(for rawHighlightName: String) -> UIColor? {
        return nil
    }

    func font(for rawHighlightName: String) -> UIFont? {
        nil
    }
}

/// Represents a color, representable by a UIColor, which is Codable
struct CodableColor: Codable {
    let red: CGFloat
    let green: CGFloat
    let blue: CGFloat
    let alpha: CGFloat
    
    var uiColor: UIColor {
        return UIColor(red: self.red, green: self.green, blue: self.blue, alpha: self.alpha)
    }
    
    init(_ color: UIColor) {
        // We have to provide pointers in the function to get the colors from
        var _red: CGFloat = 0, _green: CGFloat = 0, _blue: CGFloat = 0, _alpha: CGFloat = 0
        
        color.getRed(&_red, green: &_green, blue: &_blue, alpha: &_alpha)
        
        self.red = _red
        self.blue = _blue
        self.green = _green
        self.alpha = _alpha
    }
}

struct CodableFont: Codable {
    var name: String
    var size: CGFloat
    
    var font: UIFont {
        return UIFont(name: name, size: size)!
    }
    
    init(_ font: UIFont) {
        self.name = font.fontName
        self.size = font.pointSize
    }
}

/// Represents a theme usable with Runestone, which is Codable.
struct CodableTheme: Codable {
    var textColor: CodableColor = CodableColor(.label)
    var font = CodableFont(UIFont(name: "Menlo-Regular", size: 25)!)

    var gutterBackgroundColor: CodableColor = CodableColor(.secondarySystemBackground)
    var gutterHairlineColor: CodableColor = CodableColor(.opaqueSeparator)

    var lineNumberColor: CodableColor = CodableColor(.secondaryLabel)
    var lineNumberFont = CodableFont(UIFont(name: "Menlo-Regular", size: 14)!)

    var selectedLineBackgroundColor: CodableColor = CodableColor(.secondarySystemBackground)
    var selectedLinesLineNumberColor: CodableColor = CodableColor(.label)
    var selectedLinesGutterBackgroundColor: CodableColor = CodableColor(UIColor.opaqueSeparator.withAlphaComponent(0.4))

    var invisibleCharactersColor: CodableColor = CodableColor(.tertiaryLabel)

    var pageGuideBackgroundColor: CodableColor = CodableColor(.secondarySystemBackground)
    var pageGuideHairlineColor: CodableColor = CodableColor(.opaqueSeparator)

    var markedTextBackgroundColor: CodableColor = CodableColor(.systemFill)
    var markedTextBackgroundBorderColor: CodableColor = CodableColor(.clear)
    
    var theme: AnyTheme {
        AnyTheme(
            textColor: textColor.uiColor,
            font: font.font,
            gutterBackgroundColor: gutterBackgroundColor.uiColor,
            gutterHairlineColor: gutterHairlineColor.uiColor,
            lineNumberColor: lineNumberColor.uiColor,
            lineNumberFont: lineNumberFont.font,
            selectedLineBackgroundColor: selectedLineBackgroundColor.uiColor,
            selectedLinesLineNumberColor: selectedLinesLineNumberColor.uiColor,
            selectedLinesGutterBackgroundColor: selectedLinesGutterBackgroundColor.uiColor,
            invisibleCharactersColor: invisibleCharactersColor.uiColor,
            pageGuideBackgroundColor: pageGuideBackgroundColor.uiColor,
            pageGuideHairlineColor: pageGuideHairlineColor.uiColor,
            markedTextBackgroundColor: markedTextBackgroundColor.uiColor,
            markedTextBackgroundBorderColor: markedTextBackgroundBorderColor.uiColor
        )
    }
}
