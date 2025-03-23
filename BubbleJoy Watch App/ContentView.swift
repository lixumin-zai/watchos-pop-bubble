//
//  ContentView.swift
//  BubbleJoy Watch App
//
//  Created by lixumin on 2025/3/20.
//

import SwiftUI
import AVFoundation
import WatchKit

struct ContentView: View {
    // 存储泡泡状态
    @State private var bubbles: [BubbleState] = []
    
    // 音效播放器
    @State private var audioPlayer: AVAudioPlayer?
    
    // 在 ContentView 中添加状态变量
    @State private var pressedBubbleId: Int? = nil
    
    // 爆炸效果相关状态
    @State private var explosionParticles: [ExplosionParticle] = []
    @State private var explosionWaves: [ExplosionWave] = []
    
    var body: some View {
        ZStack {
            // 背景
            Color.black.edgesIgnoringSafeArea(.all)
            
            // 爆炸波纹
            ForEach(explosionWaves) { wave in
                Circle()
                    .stroke(wave.color.opacity(wave.opacity), lineWidth: 2)
                    .frame(width: wave.size, height: wave.size)
                    .position(wave.position)
            }
            
            // 爆炸粒子
            ForEach(explosionParticles) { particle in
                Circle()
                    .fill(particle.color)
                    .frame(width: particle.size, height: particle.size)
                    .position(particle.position)
                    .opacity(particle.opacity)
            }
            
            // 泡泡
            ForEach(bubbles) { bubble in
                if !bubble.isPopped {
                    ZStack {
                        BubbleView(size: 60, style: bubble.style)
                            .scaleEffect(pressedBubbleId == bubble.id ? 1.3 : 1.0)
                            .scaleEffect(bubble.scale)
                            .opacity(bubble.opacity)
                            .animation(.easeInOut(duration: 0.3), value: pressedBubbleId)
                    }
                    .position(bubble.position)
                    .gesture(
                        LongPressGesture(minimumDuration: 0.3)
                            .onEnded { _ in
                                popBubble(id: bubble.id)
                            }
                            .simultaneously(with: 
                                DragGesture(minimumDistance: 0)
                                    .onChanged { _ in
                                        pressedBubbleId = bubble.id
                                    }
                                    .onEnded { _ in
                                        pressedBubbleId = nil
                                    }
                            )
                    )
                }
            }
        }
        .onAppear {
            prepareAudio()
            initializeBubbles()
            resetGame()
        }
    }
    
    private func resetGame() {
        DispatchQueue.main.asyncAfter(deadline:.now() + 1.5) {
            addNewBubblesIfNeeded()
            resetGame()
        }
    }

    // 初始化泡泡
    private func initializeBubbles() {
        var positions: [CGPoint] = []
        var initialBubbles: [BubbleState] = []
        
        for i in 0..<4 {
            let position = generateNonOverlappingPosition(existingPositions: positions, bubbleSize: 60)
            positions.append(position)
            initialBubbles.append(BubbleState(id: i, isPopped: false, position: position, style: .random))
        }
        
        bubbles = initialBubbles
    }
    
    // 准备音效
    private func prepareAudio() {
        guard let soundURL = Bundle.main.url(forResource: "bo", withExtension: "mp3") else {
            print("找不到音效文件")
            return
        }
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: soundURL)
            audioPlayer?.prepareToPlay()
        } catch {
            print("无法加载音效: \(error.localizedDescription)")
        }
    }
    
    // 点击泡泡
    private func popBubble(id: Int) {
        guard let index = bubbles.firstIndex(where: { $0.id == id }) else { return }
        
        // 播放音效
        audioPlayer?.play()
        
        // 触发震动
        WKInterfaceDevice.current().play(.click)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            WKInterfaceDevice.current().play(.click)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            WKInterfaceDevice.current().play(.click)
        }
        
        // 获取泡泡位置和样式
        let bubblePosition = bubbles[index].position
        let bubbleStyle = bubbles[index].style
        
        // 创建爆炸粒子
        createExplosionParticles(at: bubblePosition, style: bubbleStyle)
        
        // 创建爆炸波纹
        createExplosionWaves(at: bubblePosition, style: bubbleStyle)
        
        // 更新泡泡状态，添加爆炸动画
        withAnimation(.easeOut(duration: 0.2)) {
            bubbles[index].scale = 1.2
        }
        
        // 短暂膨胀后收缩并消失
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.easeIn(duration: 0.15)) {
                bubbles[index].scale = 0.1
                bubbles[index].opacity = 0
            }
        }
        
        // 延迟设置 isPopped 状态，让动画完成后再移除泡泡
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            bubbles[index].isPopped = true
        }
    }
    
    // 创建爆炸粒子
    private func createExplosionParticles(at position: CGPoint, style: BubbleStyle) {
        // 清理旧粒子
        explosionParticles.removeAll { $0.opacity <= 0.05 }
        
        // 获取泡泡颜色
        let mainColor = style.colors.main
        let secondaryColor = style.colors.secondary
        
        // 创建新粒子
        let particleCount = Int.random(in: 8...12)
        
        for i in 0..<particleCount {
            // 随机角度和距离
            let angle = Double.random(in: 0..<(2 * .pi))
            let distance = CGFloat.random(in: 20...50)
            
            // 计算目标位置
            let targetX = position.x + cos(angle) * distance
            let targetY = position.y + sin(angle) * distance
            
            // 随机选择颜色
            let color = i % 2 == 0 ? mainColor : secondaryColor
            
            // 创建粒子
            let particle = ExplosionParticle(
                id: UUID(),
                position: position,
                targetPosition: CGPoint(x: targetX, y: targetY),
                size: CGFloat.random(in: 3...8),
                color: color,
                opacity: 1.2,
                duration: Double.random(in: 0.3...0.6)
            )
            
            explosionParticles.append(particle)
            
            // 动画粒子
            withAnimation(.easeOut(duration: particle.duration)) {
                if let index = explosionParticles.firstIndex(where: { $0.id == particle.id }) {
                    explosionParticles[index].position = particle.targetPosition
                    explosionParticles[index].opacity = 0
                }
            }
        }
    }
    
    // 创建爆炸波纹
    private func createExplosionWaves(at position: CGPoint, style: BubbleStyle) {
        // 清理旧波纹
        explosionWaves.removeAll { $0.opacity <= 0.05 }
        
        // 获取泡泡颜色
        let mainColor = style.colors.main
        
        // 创建3个波纹
        for i in 0..<3 {
            let delay = Double(i) * 0.1
            let duration = 0.5
            
            let wave = ExplosionWave(
                id: UUID(),
                position: position,
                size: 10,
                targetSize: 80 + CGFloat(i * 20),
                color: mainColor,
                opacity: 0.8,
                duration: duration
            )
            
            explosionWaves.append(wave)
            
            // 延迟启动波纹动画
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation(.easeOut(duration: duration)) {
                    if let index = explosionWaves.firstIndex(where: { $0.id == wave.id }) {
                        explosionWaves[index].size = wave.targetSize
                        explosionWaves[index].opacity = 0
                    }
                }
            }
        }
    }
    
    
    // 添加新泡泡，确保场上有4个泡泡
    private func addNewBubblesIfNeeded() {
        // 计算当前未被点击的泡泡数量
        let activeBubbles = bubbles.filter { !$0.isPopped }
        
        // 如果未被点击的泡泡少于4个，添加一个新泡泡
        if activeBubbles.count < 4 {
            // 获取当前所有泡泡的位置
            let existingPositions = activeBubbles.map { $0.position }
            
            // 获取当前最大ID
            let maxId = bubbles.map { $0.id }.max() ?? -1
            let newId = maxId + 1
            
            // 生成新泡泡的位置
            let newPosition = generateNonOverlappingPosition(existingPositions: existingPositions, bubbleSize: 60)
            
            // 添加新泡泡到数组
            withAnimation {
                bubbles.append(BubbleState(id: newId, isPopped: false, position: newPosition, style: .random))
            }
            
            // 如果还需要添加更多泡泡，延迟一秒后再添加下一个
            // if activeBubbles.count + 1 < 4 {
            //     DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            //         addNewBubblesIfNeeded()
            //     }
            // }
        }
    }
    
    
    // 生成不重叠的位置
    private func generateNonOverlappingPosition(existingPositions: [CGPoint], bubbleSize: CGFloat) -> CGPoint {
        let screenWidth = WKInterfaceDevice.current().screenBounds.width
        let screenHeight = WKInterfaceDevice.current().screenBounds.height - 40
        let minDistance = bubbleSize * 1.2 // 设置最小距离为泡泡直径的1.2倍
        // 设置安全边距，确保泡泡完全在屏幕内
        let safeMargin = bubbleSize / 2 + 5 // 增加5点额外边距
        
        var newPosition: CGPoint
        var attempts = 0
        let maxAttempts = 100 // 设置最大尝试次数，避免无限循环
        
        repeat {
            // 生成随机位置，确保泡泡完全在屏幕内
            let x = CGFloat.random(in: safeMargin...(screenWidth - safeMargin))
            let y = CGFloat.random(in: safeMargin...(screenHeight - safeMargin))
            newPosition = CGPoint(x: x, y: y)
            
            attempts += 1
            
            // 如果尝试次数过多，就接受当前位置
            if attempts >= maxAttempts {
                break
            }
            
        } while existingPositions.contains(where: { 
            distance($0, newPosition) < minDistance 
        })
        return newPosition
    }
    
    // 计算两点之间的距离
    private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        return sqrt(pow(a.x - b.x, 2) + pow(a.y - b.y, 2))
    }
}

// 泡泡状态模型
struct BubbleState: Identifiable {
    var id: Int
    var isPopped: Bool
    var position: CGPoint
    var style: BubbleStyle
    var scale: CGFloat = 1.0
    var opacity: CGFloat = 1.0
}

// 泡泡样式枚举
enum BubbleStyle: Int, CaseIterable {
    case lightBlue, white, rainbow, multiGradient
    
    // 获取样式对应的颜色
    var colors: (main: Color, secondary: Color) {
        switch self {
        case .lightBlue:
            return (.blue.opacity(0.8), .cyan.opacity(0.3))
        case .white:
            return (.white.opacity(0.8), .gray.opacity(0.2))
        case .rainbow:
            return (.pink.opacity(0.7), .blue.opacity(0.4)) // 实际会在视图中使用彩虹渐变
        case .multiGradient:
            return (.purple.opacity(0.7), .orange.opacity(0.4)) // 实际会在视图中使用多色渐变
        }
    }
    
    // 获取随机样式
    static var random: BubbleStyle {
        return BubbleStyle.allCases.randomElement() ?? .lightBlue
    }
}

// 泡泡视图
struct BubbleView: View {
    let size: CGFloat
    @State private var animateScale = false
    var style: BubbleStyle = .lightBlue // 默认浅蓝色样式
    
    var body: some View {
        ZStack {
            // 根据不同样式创建不同的背景
            Group {
                switch style {
                case .lightBlue, .white:
                    // 浅蓝和白色使用简单的双色渐变
                    Circle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [style.colors.main, style.colors.secondary]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                case .rainbow:
                    // 彩虹色使用彩虹色泡泡样式
                    // 彩虹色使用渐变
                    Circle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    .red,
                                    .orange,
                                    .yellow,
                                    .green,
                                    .blue,
                                    .purple,
                                    .pink.opacity(0.7)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                case .multiGradient:
                    // 渐变混合使用随机多色渐变
                    Circle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [.purple, .blue, .cyan, .mint, .green]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
            }
            .overlay(
                Circle()
                    .stroke(Color.white.opacity(0.3), lineWidth: 2)
            )
            .overlay(
                Circle()
                    .fill(Color.white.opacity(0.3))
                    .frame(width: size * 0.2)
                    .offset(x: -size * 0.2, y: -size * 0.2)
            )
            .shadow(color: style == .white ? .gray.opacity(0.5) : style.colors.main.opacity(0.5), radius: 10)
        }
        .frame(width: size, height: size)
        .scaleEffect(animateScale ? 1.1 : 1.0)
        .onAppear {
            withAnimation(Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                animateScale.toggle()
            }
        }
    }
}

// CGPoint扩展，用于随机位置
extension CGPoint {
    static var random: CGPoint {
        let screenWidth = WKInterfaceDevice.current().screenBounds.width
        let screenHeight = WKInterfaceDevice.current().screenBounds.height
        
        // 设置安全边距，确保泡泡完全在屏幕内
        let safeMargin: CGFloat = 35 // 安全边距
        
        let x = CGFloat.random(in: safeMargin...(screenWidth - safeMargin))
        let y = CGFloat.random(in: safeMargin...(screenHeight - safeMargin))
        
        return CGPoint(x: x, y: y)
    }
}

#Preview {
    ContentView()
}

// 爆炸粒子模型
struct ExplosionParticle: Identifiable {
    var id: UUID
    var position: CGPoint
    var targetPosition: CGPoint
    var size: CGFloat
    var color: Color
    var opacity: CGFloat
    var duration: Double
}

// 爆炸波纹模型
struct ExplosionWave: Identifiable {
    var id: UUID
    var position: CGPoint
    var size: CGFloat
    var targetSize: CGFloat
    var color: Color
    var opacity: CGFloat
    var duration: Double
}
