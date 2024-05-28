//
//  FrameView.swift
//  Mistral-4o
//
//  Created by Darya on 24/05/2024.
//

import SwiftUI

struct FrameView: View {
    var image : CGImage?
    private let label = Text("frame")
    
    var body: some View {
        if let image = image {
            Image(image, scale:1.0, orientation: .up, label: label)
        }
        else {
            Color.black
        }
    }
}

struct FrameView_Previews: PreviewProvider{
    static var previews: some View {
        FrameView()
    }
}
