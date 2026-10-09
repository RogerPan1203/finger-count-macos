import SwiftUI

@main
struct FingerCountApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .defaultSize(width: 1160, height: 790)
    }
}

private enum Theme {
    static let canvas = Color(red: 0.964, green: 0.969, blue: 0.945)
    static let surface = Color.white
    static let ink = Color(red: 0.115, green: 0.165, blue: 0.126)
    static let muted = Color(red: 0.44, green: 0.49, blue: 0.44)
    static let subtle = Color(red: 0.63, green: 0.68, blue: 0.63)
    static let line = Color(red: 0.88, green: 0.91, blue: 0.86)
    static let lime = Color(red: 0.76, green: 0.95, blue: 0.39)
    static let limeSoft = Color(red: 0.86, green: 0.97, blue: 0.68)
    static let forest = Color(red: 0.17, green: 0.31, blue: 0.17)
    static let camera = Color(red: 0.075, green: 0.12, blue: 0.095)
}

private struct ContentView: View {
    @StateObject private var model = CameraModel()
    @AppStorage(AppLanguage.preferenceKey) private var selectedLanguage = AppLanguage.system

    private var language: AppLanguage { selectedLanguage }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                introduction

                HStack(alignment: .top, spacing: 20) {
                    CameraPanel(model: model, language: language)
                        .frame(maxWidth: .infinity)
                    ResultPanel(model: model, language: language)
                        .frame(width: 330)
                }

                footer
            }
            .frame(maxWidth: 1350)
            .padding(.horizontal, 38)
            .frame(maxWidth: .infinity)
        }
        .background(Theme.canvas)
        .frame(minWidth: 890, minHeight: 690)
        .onAppear { model.setLanguage(language) }
        .onChange(of: selectedLanguage) { model.setLanguage($0) }
        .onDisappear { model.stop() }
    }

    private var header: some View {
        HStack(alignment: .center) {
            HStack(spacing: 12) {
                BrandMark()
                    .frame(width: 34, height: 34)
                VStack(alignment: .leading, spacing: 1) {
                    Text(language.text("指尖", "Fingers"))
                        .font(.system(size: 20, weight: .black))
                        .tracking(-1.5)
                        .foregroundStyle(Theme.ink)
                    Text("FINGER COUNT")
                        .font(.system(size: 8, weight: .medium, design: .monospaced))
                        .tracking(1.3)
                        .foregroundStyle(Theme.muted)
                }
            }
            Spacer()
            HStack(spacing: 16) {
                HStack(spacing: 7) {
                    Circle()
                        .fill(Color(red: 0.42, green: 0.68, blue: 0.31))
                        .frame(width: 6, height: 6)
                    Text(language.text("本机实时识别", "Live, on-device tracking"))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Theme.muted)
                }
                Picker(language.text("语言", "Language"), selection: $selectedLanguage) {
                    Text(language.text("跟随系统", "System")).tag(AppLanguage.system)
                    Text("English").tag(AppLanguage.english)
                    Text("中文").tag(AppLanguage.chinese)
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(width: 105)
                .accessibilityLabel(language.text("语言", "Language"))
            }
        }
        .padding(.vertical, 18)
        .overlay(alignment: .bottom) { Theme.line.frame(height: 1) }
    }

    private var introduction: some View {
        HStack(alignment: .bottom, spacing: 35) {
            VStack(alignment: .leading, spacing: 13) {
                HStack(spacing: 10) {
                    Theme.forest.frame(width: 22, height: 1)
                    Text(language.text("实时手部追踪", "LIVE HAND TRACKING"))
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .tracking(1.5)
                        .foregroundStyle(Theme.forest)
                }
                Text(language.text("伸出手指，数字即刻出现。", "Hold up your fingers. See the count."))
                    .font(.system(size: 38, weight: .black))
                    .tracking(-2.1)
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Text(language.text("打开摄像头，将手放入画面。可同时识别双手，实时显示伸出的手指数。",
                               "Turn on the camera and show one or two hands to see a live finger count."))
                .font(.system(size: 12))
                .lineSpacing(5)
                .foregroundStyle(Theme.muted)
                .frame(width: 265, alignment: .leading)
                .padding(.bottom, 3)
        }
        .padding(.top, 39)
        .padding(.bottom, 27)
    }

    private var footer: some View {
        HStack {
            Text(language.text("指尖 / FINGER COUNT", "FINGERS / FINGER COUNT"))
            Spacer()
            Text(language.text("摄像头画面在这台 Mac 上处理", "Camera frames stay on this Mac"))
        }
        .font(.system(size: 9, weight: .medium, design: .monospaced))
        .tracking(0.5)
        .foregroundStyle(Theme.subtle)
        .padding(.top, 24)
        .padding(.bottom, 27)
    }
}

private struct BrandMark: View {
    var body: some View {
        HStack(alignment: .bottom, spacing: 3) {
            Capsule().frame(width: 6, height: 20).rotationEffect(.degrees(-24), anchor: .bottom)
            Capsule().frame(width: 6, height: 27)
            Capsule().frame(width: 6, height: 34)
            Capsule().frame(width: 6, height: 29)
        }
        .foregroundStyle(Theme.ink)
        .rotationEffect(.degrees(-8))
        .accessibilityHidden(true)
    }
}

private struct PanelHeading: View {
    let index: String
    let english: String
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("\(index) / \(english)")
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .tracking(1.1)
                .foregroundStyle(Theme.subtle)
            Text(title)
                .font(.system(size: 18, weight: .bold))
                .tracking(-0.6)
                .foregroundStyle(Theme.ink)
        }
    }
}

private struct CameraPanel: View {
    @ObservedObject var model: CameraModel
    let language: AppLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center) {
                PanelHeading(index: "01", english: language.text("摄像头", "CAMERA"),
                             title: language.text("实时画面", "Live camera"))
                Spacer()
                statusPill
            }
            .padding(.bottom, 18)

            cameraStage

            if let error = model.errorMessage {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 12))
                        .padding(.top, 2)
                    Text(error)
                        .font(.system(size: 12))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .foregroundStyle(Color(red: 0.59, green: 0.20, blue: 0.15))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Color(red: 1.0, green: 0.95, blue: 0.93), in: RoundedRectangle(cornerRadius: 9))
                .padding(.top, 13)
            }

            controls
                .padding(.top, 18)
        }
        .padding(20)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 19))
        .overlay { RoundedRectangle(cornerRadius: 19).stroke(Theme.line, lineWidth: 1) }
    }

    private var statusPill: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(statusColor)
                .frame(width: 7, height: 7)
            Text(model.statusText)
                .font(.system(size: 11, weight: .medium))
                .lineLimit(1)
        }
        .foregroundStyle(Theme.muted)
        .padding(.horizontal, 11)
        .frame(height: 29)
        .background(Theme.canvas, in: Capsule())
        .accessibilityElement(children: .combine)
    }

    private var statusColor: Color {
        if model.errorMessage != nil { return Color(red: 0.86, green: 0.38, blue: 0.31) }
        if model.isRunning { return Color(red: 0.35, green: 0.68, blue: 0.25) }
        if model.isStarting { return Color(red: 0.88, green: 0.63, blue: 0.20) }
        return Theme.subtle
    }

    private var cameraStage: some View {
        ZStack {
            Theme.camera

            CameraPreview(
                session: model.session,
                handPoints: model.handPoints,
                frameSize: model.frameSize,
                mirrored: model.isMirrored
            )
            .opacity(model.isRunning ? 1 : 0)

            ViewfinderCorners()
                .stroke(Theme.limeSoft.opacity(0.5), style: StrokeStyle(lineWidth: 1.3, lineCap: .round))
                .padding(24)

            if !model.isRunning {
                VStack(spacing: 0) {
                    Image(systemName: "hand.raised")
                        .font(.system(size: 43, weight: .ultraLight))
                        .foregroundStyle(Theme.lime)
                        .frame(width: 94, height: 94)
                        .background(Theme.lime.opacity(0.07), in: RoundedRectangle(cornerRadius: 24))
                        .overlay { RoundedRectangle(cornerRadius: 24).stroke(Theme.lime.opacity(0.20)) }
                        .rotationEffect(.degrees(-7))
                    Text(model.isStarting
                         ? language.text("正在连接摄像头…", "Connecting to camera…")
                         : language.text("把手放进画面", "Place a hand in view"))
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.top, 23)
                    Text(model.isStarting
                         ? language.text("请稍候，或允许系统访问摄像头", "Please wait or allow camera access")
                         : language.text("点击下方按钮，然后允许系统访问摄像头", "Click below, then allow camera access"))
                        .font(.system(size: 12))
                        .foregroundStyle(Color.white.opacity(0.55))
                        .padding(.top, 7)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            VStack {
                HStack {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(model.isRunning ? Theme.lime : Color.white.opacity(0.45))
                            .frame(width: 5, height: 5)
                        Text(model.isRunning
                             ? language.text("摄像头实时画面", "LIVE CAMERA")
                             : language.text("摄像头就绪", "CAMERA READY"))
                    }
                    Spacer()
                    Text(language.text("手部追踪", "HAND TRACKING"))
                }
                Spacer()
                HStack {
                    Text(language.text("视觉识别 / 双手", "VISION / TWO HANDS"))
                    Spacer()
                    Text(model.isRunning ? "\(model.framesPerSecond) FPS" : "— FPS")
                }
            }
            .font(.system(size: 9, weight: .medium, design: .monospaced))
            .tracking(1.1)
            .foregroundStyle(Color.white.opacity(0.7))
            .padding(24)
        }
        .aspectRatio(1.47, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityLabel(language.text("摄像头实时画面", "Live camera preview"))
    }

    private var controls: some View {
        HStack(spacing: 9) {
            Button(action: model.start) {
                Label(language.text("开启摄像头", "Start camera"), systemImage: "play.fill")
                    .frame(height: 39)
                    .padding(.horizontal, 14)
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(model.isRunning || model.isStarting)

            Button(action: model.stop) {
                Label(language.text("停止", "Stop"), systemImage: "stop.fill")
                    .frame(height: 39)
                    .padding(.horizontal, 14)
            }
            .buttonStyle(SecondaryButtonStyle())
            .disabled(!model.isRunning && !model.isStarting)

            Spacer(minLength: 4)

            Button(action: model.toggleMirror) {
                Label(language.text("镜像画面", "Mirror"), systemImage: "rectangle.on.rectangle.angled")
                    .frame(height: 39)
                    .padding(.horizontal, 10)
            }
            .buttonStyle(QuietButtonStyle(active: model.isMirrored))
            .help(model.isMirrored
                  ? language.text("关闭镜像画面", "Turn off mirrored preview")
                  : language.text("开启镜像画面", "Turn on mirrored preview"))
            .accessibilityValue(model.isMirrored
                                ? language.text("已开启", "On")
                                : language.text("已关闭", "Off"))
        }
        .font(.system(size: 12, weight: .semibold))
    }
}

private struct ViewfinderCorners: Shape {
    func path(in rect: CGRect) -> Path {
        let length: CGFloat = 19
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + length))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX + length, y: rect.minY))
        path.move(to: CGPoint(x: rect.maxX - length, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + length))
        path.move(to: CGPoint(x: rect.maxX, y: rect.maxY - length))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX - length, y: rect.maxY))
        path.move(to: CGPoint(x: rect.minX + length, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - length))
        return path
    }
}

private struct ResultPanel: View {
    @ObservedObject var model: CameraModel
    let language: AppLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                PanelHeading(index: "02", english: language.text("结果", "RESULT"),
                             title: language.text("识别结果", "Finger count"))
                Spacer()
                Text(model.isRunning
                     ? language.text("● 实时", "● LIVE")
                     : language.text("○ 待机", "○ IDLE"))
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(model.isRunning ? Theme.forest.opacity(0.75) : Theme.subtle)
            }
            .padding(.bottom, 18)

            countCard

            HStack(alignment: .firstTextBaseline) {
                Text(language.text("逐手统计", "Each hand"))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.ink)
                Spacer()
                Text(language.text("最多两只手", "Up to two hands"))
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.subtle)
            }
            .padding(.top, 23)
            .padding(.bottom, 10)

            VStack(spacing: 8) {
                if model.hands.isEmpty {
                    HStack(spacing: 10) {
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Theme.subtle)
                            .frame(width: 27, height: 27)
                            .overlay { RoundedRectangle(cornerRadius: 6).stroke(Theme.line) }
                        Text(model.isRunning
                             ? language.text("尚未检测到手，请将手伸入画面", "No hand detected. Move a hand into view.")
                             : language.text("开启摄像头后显示每只手的结果", "Start the camera to see each hand."))
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.subtle)
                        Spacer(minLength: 0)
                    }
                    .padding(13)
                    .frame(maxWidth: .infinity, minHeight: 66)
                    .overlay { RoundedRectangle(cornerRadius: 9).strokeBorder(Theme.line, style: StrokeStyle(lineWidth: 1, dash: [4, 4])) }
                } else {
                    ForEach(Array(model.hands.enumerated()), id: \.element.id) { index, hand in
                        HandResultRow(index: index, reading: hand, language: language)
                    }
                }
            }

            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "info.circle")
                    .font(.system(size: 13))
                    .padding(.top, 1)
                Text(language.text("手掌朝向摄像头、保持光线充足，识别会更稳定。",
                                   "Face your palm toward the camera and use good lighting for steadier results."))
                    .font(.system(size: 11))
                    .lineSpacing(3)
            }
            .foregroundStyle(Theme.muted)
            .padding(.top, 20)

            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 19))
        .overlay { RoundedRectangle(cornerRadius: 19).stroke(Theme.line, lineWidth: 1) }
    }

    private var countCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                Text("✳")
                    .font(.system(size: 24, weight: .light))
                    .foregroundStyle(Theme.forest)
                Spacer()
                Text("0–10")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(Theme.forest.opacity(0.75))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .overlay { RoundedRectangle(cornerRadius: 5).stroke(Theme.forest.opacity(0.27)) }
            }
            Spacer(minLength: 14)
            Text(model.total.map { String($0) } ?? "—")
                .font(.system(size: 92, weight: .bold, design: .rounded))
                .monospacedDigit()
                .tracking(-6)
                .contentTransition(.numericText())
                .foregroundStyle(Theme.ink)
                .accessibilityLabel(model.total.map {
                    language.text("伸出 \($0) 根手指", "\($0) fingers extended")
                } ?? language.text("等待识别", "Waiting for a hand"))
            Text(model.total == nil
                 ? language.text("等待识别", "Waiting for a hand")
                 : language.text("伸出的手指", "Fingers extended"))
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Theme.forest)
                .padding(.top, -1)
            Text(language.text("双手伸出的手指总数", "Total across both hands"))
                .font(.system(size: 11))
                .foregroundStyle(Theme.forest.opacity(0.73))
                .padding(.top, 4)
        }
        .padding(21)
        .frame(maxWidth: .infinity, minHeight: 245, alignment: .leading)
        .background(Theme.limeSoft, in: RoundedRectangle(cornerRadius: 13))
    }
}

private struct HandResultRow: View {
    let index: Int
    let reading: HandReading
    let language: AppLanguage

    private var names: [String] {
        language.usesChinese ? ["拇", "食", "中", "无", "小"] : ["TH", "IN", "MI", "RI", "PI"]
    }

    private var fullNames: [String] {
        language.usesChinese ? ["拇指", "食指", "中指", "无名指", "小指"]
                             : ["Thumb", "Index", "Middle", "Ring", "Pinky"]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text(String(format: "%02d", index + 1))
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(Theme.subtle)
                Text(language.text("第 \(index + 1) 只手", "Hand \(index + 1)"))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Spacer()
                Text(language.text("\(reading.count) 根",
                                   "\(reading.count) \(reading.count == 1 ? "finger" : "fingers")"))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.forest)
            }
            HStack(spacing: 5) {
                ForEach(0..<5, id: \.self) { finger in
                    let extended = finger < reading.fingerStates.count && reading.fingerStates[finger]
                    Text(names[finger])
                        .font(.system(size: 10, weight: extended ? .semibold : .regular))
                        .foregroundStyle(extended ? Theme.forest : Theme.subtle)
                        .frame(maxWidth: .infinity)
                        .frame(height: 22)
                        .background(extended ? Theme.limeSoft : Theme.canvas, in: RoundedRectangle(cornerRadius: 5))
                        .accessibilityLabel(fullNames[finger])
                        .accessibilityValue(extended
                                            ? language.text("伸出", "Extended")
                                            : language.text("弯曲", "Folded"))
                }
            }
        }
        .padding(12)
        .background(Theme.canvas.opacity(0.73), in: RoundedRectangle(cornerRadius: 9))
        .overlay { RoundedRectangle(cornerRadius: 9).stroke(Theme.line, lineWidth: 1) }
        .accessibilityElement(children: .combine)
    }
}

private struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(Theme.ink)
            .background(Theme.lime, in: RoundedRectangle(cornerRadius: 8))
            .opacity(configuration.isPressed ? 0.78 : 1)
    }
}

private struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(Theme.ink)
            .background(Theme.canvas, in: RoundedRectangle(cornerRadius: 8))
            .overlay { RoundedRectangle(cornerRadius: 8).stroke(Theme.line, lineWidth: 1) }
            .opacity(configuration.isPressed ? 0.70 : 1)
    }
}

private struct QuietButtonStyle: ButtonStyle {
    let active: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(active ? Theme.forest : Theme.muted)
            .background(active ? Theme.limeSoft.opacity(0.65) : .clear, in: RoundedRectangle(cornerRadius: 8))
            .opacity(configuration.isPressed ? 0.62 : 1)
    }
}
