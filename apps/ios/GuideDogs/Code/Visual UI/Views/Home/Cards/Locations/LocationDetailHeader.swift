//  LocationDetailHeader.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Licensed under the MIT License.
//

import SwiftUI

struct LocationDetailHeader: View {
    
    // MARK: Properties
    
    let config: LocationDetailConfiguration
    
    // MARK: Accessibility
    
    /// Combined accessibility label for VoiceOver
    private var accessibilityCombinedLabel: String {
        if config.subtitle.isEmpty {
            return config.title
        } else {
            return "\(config.title), \(config.subtitle)"
        }
    }
    
    // MARK: `body`
    
    var body: some View {
        HStack(spacing: 12.0) {
            VStack(alignment: .leading, spacing: 2.0) {
                Text(config.title)
                
                Text(config.subtitle)
                    .font(.caption)
            }
            .multilineTextAlignment(.leading)
            
            if config.isDetailViewEnabled {
                Text(Image(systemName: "info.circle"))
                    .font(.title3)
            }
        }
        .roundedContrastText()
        .multilineTextAlignment(.leading)
        // 将标题、子标题与 info 图标合并成一个无障碍元素
        .accessibilityElement(children: .combine)
        // 自定义 VoiceOver 朗读内容
        .accessibilityLabel(accessibilityCombinedLabel)
        // 提示用户这里可以点进去看详情（需要在 Localizable.strings 里加 general.more_info）
        .accessibilityHint(GDLocalizedString("general.more_info"))
        .accessibilityAddTraits(.isHeader)
    }
    
}

struct LocationDetailHeader_Previews: PreviewProvider {
    
    static var previews: some View {
        LocationDetailHeader(
            config: LocationDetailConfiguration(
                for: .tour(detail: BeaconMapView_Previews.behavior.content)
            )
        )
    }
    
}
