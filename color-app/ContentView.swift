//
//  ContentView.swift
//  color-app
//
//  Created by Daben on 2024/12/17.
//

import SwiftUI
import SwiftData
import UIKit
import CoreImage
import AVFoundation

struct ContentView: View {
    @State private var selectedImage: UIImage?
    @State private var showImagePicker = false
    @State private var showCamera = false
    @State private var selectedColor: Color?
    @State private var decomposedColors: [(Color, Double)] = []
    @State private var dragLocation: CGPoint = .zero
    @State private var imageSize: CGSize = .zero
    
    func getPixelColor(at position: CGPoint, in image: UIImage) -> Color? {
        let pixelPoint = CGPoint(
            x: position.x * image.scale,
            y: position.y * image.scale
        )
        
        guard let pixelData = image.cgImage?.dataProvider?.data,
              let data: UnsafePointer<UInt8> = CFDataGetBytePtr(pixelData) else {
            return nil
        }
        
        let bytesPerPixel = 4
        let bytesPerRow = image.cgImage?.bytesPerRow ?? 0
        let pixelInfo = Int(pixelPoint.y) * bytesPerRow + Int(pixelPoint.x) * bytesPerPixel
        
        let r = CGFloat(data[pixelInfo]) / 255.0
        let g = CGFloat(data[pixelInfo + 1]) / 255.0
        let b = CGFloat(data[pixelInfo + 2]) / 255.0
        
        return Color(red: r, green: g, blue: b)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // 背景
                Color.gray.opacity(0.1)
                    .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    // 图片显示区域
                    if let image = selectedImage {
                        GeometryReader { geometry in
                            ZStack {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxWidth: geometry.size.width, maxHeight: 300)
                                    .clipShape(RoundedRectangle(cornerRadius: 20))
                                    .shadow(radius: 10)
                                    .overlay(
                                        ColorPickerOverlay(
                                            location: $dragLocation,
                                            color: selectedColor ?? .clear,
                                            isVisible: dragLocation != .zero
                                        )
                                    )
                                    .gesture(
                                        DragGesture(minimumDistance: 0)
                                            .onChanged { value in
                                                let imageView = geometry.frame(in: .local)
                                                let imageSize = AVMakeRect(
                                                    aspectRatio: image.size,
                                                    insideRect: CGRect(
                                                        x: 0,
                                                        y: 0,
                                                        width: geometry.size.width,
                                                        height: 300
                                                    )
                                                )
                                                
                                                // 检查是否在图片范围内
                                                if value.location.x >= imageSize.minX &&
                                                    value.location.x <= imageSize.maxX &&
                                                    value.location.y >= imageSize.minY &&
                                                    value.location.y <= imageSize.maxY {
                                                    
                                                    dragLocation = value.location
                                                    
                                                    // 计算相对位置
                                                    let relativeX = (value.location.x - imageSize.minX) / imageSize.width
                                                    let relativeY = (value.location.y - imageSize.minY) / imageSize.height
                                                    
                                                    // 转换为图片坐标
                                                    let pixelX = relativeX * CGFloat(image.size.width)
                                                    let pixelY = relativeY * CGFloat(image.size.height)
                                                    
                                                    if let color = getPixelColor(
                                                        at: CGPoint(x: pixelX, y: pixelY),
                                                        in: image
                                                    ) {
                                                        selectedColor = color
                                                    }
                                                }
                                            }
                                            .onEnded { _ in
                                                // 可选：拖动结束时��藏取色器
                                                // dragLocation = .zero
                                            }
                                    )
                            }
                            .frame(maxWidth: .infinity, maxHeight: 300)
                        }
                        .frame(height: 300)
                    } else {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(.ultraThinMaterial)
                            .frame(height: 300)
                            .overlay(
                                Text("选择或拍摄图片")
                                    .foregroundColor(.gray)
                            )
                    }
                    
                    // 取色结果显示
                    if let color = selectedColor {
                        ColorResultView(color: color)
                    }
                    
                    // 颜色分解结果
                    if !decomposedColors.isEmpty {
                        DecomposedColorsView(colors: decomposedColors)
                    }
                    
                    // 操作按钮
                    HStack(spacing: 20) {
                        ActionButton(title: "相册", systemImage: "photo.on.rectangle") {
                            showImagePicker = true
                        }
                        
                        ActionButton(title: "相机", systemImage: "camera") {
                            showCamera = true
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("取色器")
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(image: $selectedImage, sourceType: .photoLibrary)
            }
            .sheet(isPresented: $showCamera) {
                ImagePicker(image: $selectedImage, sourceType: .camera)
            }
        }
    }
}

// 自定义按钮样式
struct ActionButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack {
                Image(systemName: systemImage)
                    .font(.system(size: 24))
                Text(title)
                    .font(.caption)
            }
            .frame(width: 80, height: 80)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 20))
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// 按钮动画样式
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// 颜色结果示视图
struct ColorResultView: View {
    let color: Color
    
    var body: some View {
        VStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 15)
                .fill(color)
                .frame(height: 60)
                .overlay(
                    RoundedRectangle(cornerRadius: 15)
                        .stroke(.gray.opacity(0.2), lineWidth: 1)
                )
            
            if let components = UIColor(color).rgbaComponents {
                VStack(spacing: 4) {
                    Text("RGB: (\(Int(components.r * 255)), \(Int(components.g * 255)), \(Int(components.b * 255)))")
                        .font(.caption)
                    Text("HEX: \(UIColor(color).hexString)")
                        .font(.caption)
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

// 分解颜色显示视图
struct DecomposedColorsView: View {
    let colors: [(Color, Double)]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("颜色分解")
                .font(.headline)
            
            ForEach(colors.indices, id: \.self) { index in
                HStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(colors[index].0)
                        .frame(width: 30, height: 30)
                    
                    Text("\(Int(colors[index].1 * 100))%")
                        .font(.caption)
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

// 新增：取色器覆盖层视图
struct ColorPickerOverlay: View {
    @Binding var location: CGPoint
    let color: Color
    let isVisible: Bool
    
    var body: some View {
        GeometryReader { geometry in
            if isVisible {
                Circle()
                    .stroke(Color.white, lineWidth: 2)
                    .background(Circle().fill(color))
                    .frame(width: 40, height: 40)
                    .position(location)
                    .shadow(color: .black.opacity(0.3), radius: 2)
            }
        }
    }
}

// 新增：颜色转换扩展
extension UIColor {
    var rgbaComponents: (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat)? {
        guard let components = cgColor.components else { return nil }
        
        switch components.count {
        case 2: // Grayscale
            return (components[0], components[0], components[0], components[1])
        case 4: // RGBA
            return (components[0], components[1], components[2], components[3])
        default:
            return nil
        }
    }
    
    var hexString: String {
        guard let components = rgbaComponents else { return "#000000" }
        return String(
            format: "#%02X%02X%02X",
            Int(components.r * 255),
            Int(components.g * 255),
            Int(components.b * 255)
        )
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Item.self, inMemory: true)
}
