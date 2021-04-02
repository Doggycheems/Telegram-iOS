import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils
import TelegramStringFormatting

class BotCheckoutTipItem: ListViewItem, ItemListItem {
    let theme: PresentationTheme
    let title: String
    let currency: String
    let value: String
    let numericValue: Int64
    let availableVariants: [(String, Int64)]
    let updateValue: (Int64) -> Void

    let sectionId: ItemListSectionId
    
    let requestsNoInset: Bool = true
    
    init(theme: PresentationTheme, title: String, currency: String, value: String, numericValue: Int64, availableVariants: [(String, Int64)], sectionId: ItemListSectionId, updateValue: @escaping (Int64) -> Void) {
        self.theme = theme
        self.title = title
        self.currency = currency
        self.value = value
        self.numericValue = numericValue
        self.availableVariants = availableVariants
        self.updateValue = updateValue
        self.sectionId = sectionId
    }
    
    func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = BotCheckoutTipItemNode()
            let (layout, apply) = node.asyncLayout()(self, params, itemListNeighbors(item: self, topItem: previousItem as? ItemListItem, bottomItem: nextItem as? ItemListItem))
            
            node.contentSize = layout.contentSize
            node.insets = layout.insets
            
            Queue.mainQueue().async {
                completion(node, {
                    return (nil, { _ in apply() })
                })
            }
        }
    }
    
    func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, previousItem: ListViewItem?, nextItem: ListViewItem?, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping (ListViewItemApply) -> Void) -> Void) {
        Queue.mainQueue().async {
            if let nodeValue = node() as? BotCheckoutTipItemNode {
                let makeLayout = nodeValue.asyncLayout()
                
                async {
                    let (layout, apply) = makeLayout(self, params, itemListNeighbors(item: self, topItem: previousItem as? ItemListItem, bottomItem: nextItem as? ItemListItem))
                    Queue.mainQueue().async {
                        completion(layout, { _ in
                            apply()
                        })
                    }
                }
            }
        }
    }
    
    let selectable: Bool = false
}

private let titleFont = Font.regular(17.0)
private let finalFont = Font.semibold(17.0)

private func priceItemInsets(_ neighbors: ItemListNeighbors) -> UIEdgeInsets {
    var insets = UIEdgeInsets()
    switch neighbors.top {
        case .otherSection:
            insets.top += 8.0
        case .none, .sameSection:
            break
    }
    switch neighbors.bottom {
        case .none, .otherSection:
            insets.bottom += 8.0
        case .sameSection:
            break
    }
    return insets
}

private final class TipValueNode: ASDisplayNode {
    private let backgroundNode: ASImageNode
    private let titleNode: ImmediateTextNode

    private let button: HighlightTrackingButtonNode

    private var currentBackgroundColor: UIColor?

    var action: (() -> Void)?

    override init() {
        self.backgroundNode = ASImageNode()
        self.titleNode = ImmediateTextNode()

        self.button = HighlightTrackingButtonNode()

        super.init()

        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.titleNode)
        self.addSubnode(self.button)
        self.button.addTarget(self, action:  #selector(self.buttonPressed), forControlEvents: .touchUpInside)
    }

    @objc private func buttonPressed() {
        self.action?()
    }

    func update(theme: PresentationTheme, text: String, isHighlighted: Bool, height: CGFloat) -> CGFloat {
        var updateBackground = false
        let backgroundColor = isHighlighted ? UIColor(rgb: 0x00A650) : UIColor(rgb: 0xE5F6ED)
        if let currentBackgroundColor = self.currentBackgroundColor {
            if !currentBackgroundColor.isEqual(backgroundColor) {
                updateBackground = true
            }
        } else {
            updateBackground = true
        }
        if updateBackground {
            self.currentBackgroundColor = backgroundColor
            self.backgroundNode.image = generateStretchableFilledCircleImage(diameter: 20.0, color: backgroundColor)
        }

        self.titleNode.attributedText = NSAttributedString(string: text, font: Font.semibold(15.0), textColor: isHighlighted ? UIColor(rgb: 0xffffff) : UIColor(rgb: 0x00A650))
        let titleSize = self.titleNode.updateLayout(CGSize(width: 200.0, height: height))

        let minWidth: CGFloat = 80.0

        let calculatedWidth = max(titleSize.width + 16.0 * 2.0, minWidth)

        self.titleNode.frame = CGRect(origin: CGPoint(x: floor((calculatedWidth - titleSize.width) / 2.0), y: floor((height - titleSize.height) / 2.0)), size: titleSize)

        let size = CGSize(width: calculatedWidth, height: height)
        self.backgroundNode.frame = CGRect(origin: CGPoint(), size: size)

        self.button.frame = CGRect(origin: CGPoint(), size: size)

        return size.width
    }
}

class BotCheckoutTipItemNode: ListViewItemNode, UITextFieldDelegate {
    let titleNode: TextNode
    let labelNode: TextNode
    private let textNode: TextFieldNode

    private let scrollNode: ASScrollNode
    private var valueNodes: [TipValueNode] = []
    
    private var item: BotCheckoutTipItem?
    
    init() {
        self.titleNode = TextNode()
        self.titleNode.isUserInteractionEnabled = false

        self.labelNode = TextNode()
        self.labelNode.isUserInteractionEnabled = false

        self.textNode = TextFieldNode()

        self.scrollNode = ASScrollNode()
        self.scrollNode.view.disablesInteractiveTransitionGestureRecognizer = true
        self.scrollNode.view.showsVerticalScrollIndicator = false
        self.scrollNode.view.showsHorizontalScrollIndicator = false
        self.scrollNode.view.scrollsToTop = false
        self.scrollNode.view.delaysContentTouches = false
        self.scrollNode.view.canCancelContentTouches = true
        if #available(iOS 11.0, *) {
            self.scrollNode.view.contentInsetAdjustmentBehavior = .never
        }
        
        super.init(layerBacked: false, dynamicBounce: false)
        
        self.addSubnode(self.titleNode)
        self.addSubnode(self.labelNode)
        self.addSubnode(self.textNode)
        self.addSubnode(self.scrollNode)

        self.textNode.clipsToBounds = true
        self.textNode.textField.delegate = self
        self.textNode.textField.addTarget(self, action: #selector(self.textFieldTextChanged(_:)), for: .editingChanged)
        self.textNode.hitTestSlop = UIEdgeInsets(top: -5.0, left: -5.0, bottom: -5.0, right: -5.0)
    }
    
    func asyncLayout() -> (_ item: BotCheckoutTipItem, _ params: ListViewItemLayoutParams, _ insets: ItemListNeighbors) -> (ListViewItemNodeLayout, () -> Void) {
        let makeTitleLayout = TextNode.asyncLayout(self.titleNode)
        let makeLabelLayout = TextNode.asyncLayout(self.labelNode)
        
        return { item, params, neighbors in
            //let rightInset: CGFloat = 16.0 + params.rightInset

            let labelsContentHeight: CGFloat = 34.0
            
            var contentSize = CGSize(width: params.width, height: labelsContentHeight)
            if !item.availableVariants.isEmpty {
                contentSize.height += 75.0
            }

            let insets = priceItemInsets(neighbors)
            
            let textFont: UIFont
            let textColor: UIColor

            textFont = titleFont
            textColor = item.theme.list.itemSecondaryTextColor
            
            let (titleLayout, titleApply) = makeTitleLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: item.title, font: textFont, textColor: textColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width - params.leftInset - params.rightInset - 20.0, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))

            let (labelLayout, labelApply) = makeLabelLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: "Enter Custom", font: textFont, textColor: textColor.withMultipliedAlpha(0.8)), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width - params.leftInset - params.rightInset - 20.0, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            return (ListViewItemNodeLayout(contentSize: contentSize, insets: insets), { [weak self] in
                if let strongSelf = self {
                    strongSelf.item = item
                    
                    let _ = titleApply()
                    let _ = labelApply()
                    
                    let leftInset: CGFloat = 16.0 + params.leftInset
                    
                    strongSelf.titleNode.frame = CGRect(origin: CGPoint(x: leftInset, y: floor((labelsContentHeight - titleLayout.size.height) / 2.0)), size: titleLayout.size)
                    strongSelf.labelNode.frame = CGRect(origin: CGPoint(x: params.width - leftInset - labelLayout.size.width, y: floor((labelsContentHeight - labelLayout.size.height) / 2.0)), size: labelLayout.size)

                    let text: String
                    if item.numericValue == 0 {
                        text = ""
                    } else {
                        text = formatCurrencyAmount(item.numericValue, currency: item.currency)
                    }
                    if strongSelf.textNode.textField.text ?? "" != text {
                        strongSelf.textNode.textField.text = text
                        strongSelf.labelNode.isHidden = !text.isEmpty
                    }

                    strongSelf.textNode.textField.typingAttributes = [NSAttributedString.Key.font: titleFont]
                    strongSelf.textNode.textField.font = titleFont

                    strongSelf.textNode.textField.textColor = textColor
                    strongSelf.textNode.textField.textAlignment = .right
                    strongSelf.textNode.textField.keyboardAppearance = item.theme.rootController.keyboardColor.keyboardAppearance
                    strongSelf.textNode.textField.keyboardType = .decimalPad
                    strongSelf.textNode.textField.tintColor = item.theme.list.itemAccentColor

                    strongSelf.textNode.frame = CGRect(origin: CGPoint(x: params.width - leftInset - 150.0, y: -2.0), size: CGSize(width: 150.0, height: labelsContentHeight))

                    let valueHeight: CGFloat = 52.0
                    let valueY: CGFloat = labelsContentHeight + 9.0

                    var index = 0
                    var variantsOffset: CGFloat = 16.0
                    for (variantText, variantValue) in item.availableVariants {
                        if index != 0 {
                            variantsOffset += 12.0
                        }

                        let valueNode: TipValueNode
                        if strongSelf.valueNodes.count > index {
                            valueNode = strongSelf.valueNodes[index]
                        } else {
                            valueNode = TipValueNode()
                            strongSelf.valueNodes.append(valueNode)
                            strongSelf.scrollNode.addSubnode(valueNode)
                        }
                        let nodeWidth = valueNode.update(theme: item.theme, text: variantText, isHighlighted: item.value == variantText, height: valueHeight)
                        valueNode.action = {
                            guard let strongSelf = self else {
                                return
                            }
                            strongSelf.item?.updateValue(variantValue)
                        }
                        valueNode.frame = CGRect(origin: CGPoint(x: variantsOffset, y: 0.0), size: CGSize(width: nodeWidth, height: valueHeight))
                        variantsOffset += nodeWidth
                        index += 1
                    }

                    variantsOffset += 16.0

                    strongSelf.scrollNode.frame = CGRect(origin: CGPoint(x: 0.0, y: valueY), size: CGSize(width: params.width, height: max(0.0, contentSize.height - valueY)))
                    strongSelf.scrollNode.view.contentSize = CGSize(width: variantsOffset, height: strongSelf.scrollNode.frame.height)
                }
            })
        }
    }

    @objc private func textFieldTextChanged(_ textField: UITextField) {
        let text = textField.text ?? ""
        self.labelNode.isHidden = !text.isEmpty

        guard let item = self.item else {
            return
        }

        if text.isEmpty {
            item.updateValue(0)
            return
        }

        var cleanText = ""
        for c in text {
            if c.isNumber {
                cleanText.append(c)
            } else if c == "," {
                cleanText.append(".")
            }
        }

        guard let doubleValue = Double(cleanText) else {
            return
        }

        if let value = fractionalToCurrencyAmount(value: doubleValue, currency: item.currency) {
            item.updateValue(value)
        }
    }

    @objc public func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        guard let item = self.item else {
            return false
        }
        let newText = ((textField.text ?? "") as NSString).replacingCharacters(in: range, with: string)

        return true
    }

    @objc public func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        return false
    }

    @objc public func textFieldDidBeginEditing(_ textField: UITextField) {
    }

    @objc public func textFieldDidEndEditing(_ textField: UITextField) {
    }
    
    override func animateInsertion(_ currentTimestamp: Double, duration: Double, short: Bool) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.4)
    }
    
    override func animateAdded(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
    }
    
    override func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, removeOnCompletion: false)
    }
}
