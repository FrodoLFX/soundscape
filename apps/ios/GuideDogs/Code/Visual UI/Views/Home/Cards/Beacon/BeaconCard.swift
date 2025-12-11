//  BeaconCard.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Licensed under the MIT License.
//

import SwiftUI

struct BeaconCard: View {
    
    // MARK: Properties
    
    @Environment(\.colorPalette) var colorPalette
    
    let style: BeaconStyle
    
    // MARK: `body`
    
    var body: some View {
        VStack(spacing: 0.0) {
            BeaconMapCard(style: style.mapStyle)
            
            switch style {
            case .location, .route:
                // TODO: Add support for locations and routes
                EmptyView()
            case .tour(let behavior):
                TourToolbar(tour: behavior)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // 将地图和工具栏合并成一个无障碍元素，VoiceOver 一次性朗读
        .accessibilityElement(children: .combine)
        // 给整张卡片一个交互提示（双击 / 轻点可进一步操作）
        .accessibilityHint(GDLocalizedString("beacon_card.interact_hint"))
    }
    
}

struct BeaconCard_Previews: PreviewProvider {
    
    static let tour = BeaconMapCard_Previews.behavior
    
    static var previews: some View {
        BeaconCard(style: .tour(behavior: tour))
            .colorPalette(Palette.Theme.teal)
            .frame(height: 288.0)
            .roundedBorder(lineColor: Palette.Theme.teal.light)
            .padding(24.0)
    }
    
}

