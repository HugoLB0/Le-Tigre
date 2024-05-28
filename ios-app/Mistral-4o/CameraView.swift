//
//  CameraView.swift
//  Mistral-4o
//
//  Created by Darya on 26/05/2024.
//

import SwiftUI

struct CameraView: View {
    var body: some View {
        HostedViewController()
            .edgesIgnoringSafeArea(.all)
    }
}

struct CameraView_Previews: PreviewProvider {
    static var previews: some View {
        CameraView()
    }
}

