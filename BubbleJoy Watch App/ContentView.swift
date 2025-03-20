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
    
    var body: some View {
        ZStack {
            // 背景
            Color.black.edgesIgnoringSafeArea(.all)
            
            // 泡泡
            ForEach(bubbles) { bubble in
                if !bubble.isPopped {
                    ZStack {
                        BubbleView(size: 60)
                            .scaleEffect(pressedBubbleId == bubble.id ? 1.3 : 1.0)
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
            initialBubbles.append(BubbleState(id: i, isPopped: false, position: position))
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
        
        // 触发更强烈的震动
        WKInterfaceDevice.current().play(.click)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            WKInterfaceDevice.current().play(.click)
        }  // 改为 notification 类型的触觉反馈
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            WKInterfaceDevice.current().play(.click)
        }  // 改为 notification 类型的触觉反馈
        
        // 更新泡泡状态
        withAnimation(.easeOut(duration: 0.3)) {
            bubbles[index].isPopped = true
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
                bubbles.append(BubbleState(id: newId, isPopped: false, position: newPosition))
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
}

// 泡泡视图
struct BubbleView: View {
    let size: CGFloat
    @State private var animateScale = false
    
    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [.blue.opacity(0.7), .cyan.opacity(0.4)]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
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
                .shadow(color: .cyan.opacity(0.5), radius: 10)
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
