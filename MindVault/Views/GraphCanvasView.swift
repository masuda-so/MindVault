import SwiftUI
import UIKit

struct GraphCanvasView: View {
    let graph: KnowledgeGraph
    @Binding var selectedNoteID: UUID?
    var labelSafeAreaInsets = EdgeInsets()
    var showsNodeLabels = true
    var showsSelectedNodeLabel = true
    var cornerRadius: CGFloat = 8
    var onOpenNote: (UUID) -> Void

    @AppStorage("graphManualNodePositions") private var manualNodePositionsData = ""
    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var nodePositions: [UUID: CGPoint] = [:]
    @State private var displayNodePositions: [UUID: CGPoint] = [:]
    @State private var dragStartNodePosition: CGPoint?
    @State private var activeNodeDragID: UUID?
    @State private var viewportAnimationTask: Task<Void, Never>?
    @State private var nodeMotionTask: Task<Void, Never>?

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                graphBackdrop

                Canvas { context, size in
                    let center = CGPoint(x: size.width / 2 + offset.width, y: size.height / 2 + offset.height)
                    let nodes = Dictionary(uniqueKeysWithValues: graph.nodes.map { ($0.id, $0) })

                    drawBackgroundMarks(in: &context, size: size, center: center)

                    for link in graph.links {
                        guard let source = nodes[link.sourceID], let target = nodes[link.targetID] else { continue }
                        draw(link: link, source: source, target: target, in: &context, center: center)
                    }

                    for node in graph.nodes where selectedNoteID != node.id {
                        draw(node: node, in: &context, center: center, size: size)
                    }

                    if let selectedNode = graph.nodes.first(where: { $0.id == selectedNoteID }) {
                        draw(node: selectedNode, in: &context, center: center, size: size)
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(ObsidianGraphStyle.border, lineWidth: 1)
            }
            .overlay {
                nodeHitTargets(in: proxy.size)
            }
            .overlay(alignment: .trailing) {
                viewportControls(in: proxy.size)
                    .padding(.trailing, 10)
            }
            .gesture(
                DragGesture()
                    .onChanged { value in
                        guard activeNodeDragID == nil else { return }
                        cancelViewportAnimation()
                        updateWithoutAnimation {
                            offset = CGSize(width: lastOffset.width + value.translation.width, height: lastOffset.height + value.translation.height)
                        }
                    }
                    .onEnded { _ in
                        guard activeNodeDragID == nil else { return }
                        lastOffset = offset
                    }
            )
            .simultaneousGesture(
                MagnificationGesture()
                    .onChanged { value in
                        cancelViewportAnimation()
                        updateWithoutAnimation {
                            scale = min(max(lastScale * value, 0.55), 2.4)
                        }
                    }
                    .onEnded { value in
                        let settledScale = min(max(lastScale * value, 0.55), 2.4)
                        animateViewport(toScale: settledScale, targetOffset: offset, duration: 0.14)
                        lastScale = settledScale
                    }
            )
            .simultaneousGesture(
                SpatialTapGesture()
                    .onEnded { value in
                        let center = CGPoint(x: proxy.size.width / 2 + offset.width, y: proxy.size.height / 2 + offset.height)
                        if let node = node(at: value.location, center: center) {
                            selectedNoteID = node.id
                            onOpenNote(node.id)
                        }
                    }
            )
            .onAppear {
                refreshLayout(in: proxy.size, animated: false)
            }
            .onChange(of: graphLayoutSignature) { _, _ in
                refreshLayout(in: proxy.size, animated: true)
            }
            .onChange(of: proxy.size) { _, newSize in
                refreshLayout(in: newSize, animated: true)
            }
            .onDisappear {
                cancelViewportAnimation()
                cancelNodeMotion()
            }
        }
        .accessibilityIdentifier("knowledgeGraphCanvas")
    }

    private var graphBackdrop: some View {
        ZStack {
            ObsidianGraphStyle.canvasBase
            LinearGradient(
                colors: [
                    ObsidianGraphStyle.canvasTop,
                    ObsidianGraphStyle.canvasBase,
                    ObsidianGraphStyle.canvasBottom
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var graphLayoutSignature: String {
        let nodes = graph.nodes.map { $0.id.uuidString }.sorted().joined(separator: ",")
        let links = graph.links
            .map { "\($0.sourceID.uuidString)-\($0.targetID.uuidString)-\($0.kind.rawValue)" }
            .sorted()
            .joined(separator: ",")
        return "\(nodes)|\(links)"
    }

    private func refreshLayout(in size: CGSize, animated: Bool) {
        let manualPositions = decodeManualNodePositions()
        let positions = ForceDirectedGraphLayout.positions(
            for: graph,
            canvasSize: size,
            currentPositions: nodePositions,
            fixedPositions: manualPositions
        )

        updateWithoutAnimation {
            nodePositions = positions
            if !animated || displayNodePositions.isEmpty {
                displayNodePositions = positions
            }
        }

        if animated {
            startNodeMotionLoop()
        }
    }

    private func startNodeMotionLoop() {
        guard nodeMotionTask == nil else { return }

        nodeMotionTask = Task { @MainActor in
            while !Task.isCancelled {
                var didMove = false

                updateWithoutAnimation {
                    let targets: [(UUID, CGPoint)]
                    if let activeNodeDragID, let target = nodePositions[activeNodeDragID] {
                        targets = [(activeNodeDragID, target)]
                    } else {
                        targets = Array(nodePositions)
                    }

                    for (id, target) in targets {
                        let current = displayNodePositions[id] ?? target
                        let smoothing: CGFloat = activeNodeDragID == id ? 0.62 : 0.36
                        let next = current.interpolated(to: target, amount: smoothing)
                        if next.distance(to: target) < 0.35 {
                            displayNodePositions[id] = target
                        } else {
                            displayNodePositions[id] = next
                            didMove = true
                        }
                    }

                    let validIDs = Set(nodePositions.keys)
                    displayNodePositions = displayNodePositions.filter { validIDs.contains($0.key) }
                }

                if !didMove {
                    nodeMotionTask = nil
                    return
                }

                try? await Task.sleep(for: .milliseconds(16))
            }
        }
    }

    private func cancelNodeMotion() {
        nodeMotionTask?.cancel()
        nodeMotionTask = nil
    }

    private func snapDisplayedNode(_ id: UUID) {
        guard let target = nodePositions[id] else { return }
        updateWithoutAnimation {
            displayNodePositions[id] = target
        }
    }

    private func settleDisplayedNode(_ id: UUID) {
        startNodeMotionLoop()
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(140))
            guard
                activeNodeDragID == nil,
                let current = displayNodePositions[id],
                let target = nodePositions[id],
                current.distance(to: target) < 1.2
            else {
                return
            }

            snapDisplayedNode(id)
        }
    }

    private func updateNodePosition(_ id: UUID, to point: CGPoint) {
        updateWithoutAnimation {
            nodePositions[id] = point
            if displayNodePositions[id] == nil {
                displayNodePositions[id] = point
            }
        }
        startNodeMotionLoop()
    }

    private func resetViewportAndLayout(in size: CGSize) {
        manualNodePositionsData = ""
        animateViewport(toScale: 1, targetOffset: .zero, duration: 0.26)
        refreshLayout(in: size, animated: true)
    }

    private func viewportControls(in size: CGSize) -> some View {
        VStack(spacing: 4) {
            controlButton(systemImage: "plus.magnifyingglass", accessibilityLabel: String(localized: "Zoom In")) {
                animateZoom(to: min(scale * 1.22, 2.4), in: size)
            }

            controlButton(systemImage: "minus.magnifyingglass", accessibilityLabel: String(localized: "Zoom Out")) {
                animateZoom(to: max(scale / 1.22, 0.55), in: size)
            }

            controlButton(systemImage: "scope", accessibilityLabel: String(localized: "Reset Layout")) {
                resetViewportAndLayout(in: size)
            }
        }
        .padding(5)
        .background(ObsidianGraphStyle.controlSurface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(ObsidianGraphStyle.border, lineWidth: 1)
        }
    }

    private func animateZoom(to newScale: CGFloat, in size: CGSize) {
        let adjustedOffset = offsetKeepingFocusStable(for: newScale, in: size)
        animateViewport(toScale: newScale, targetOffset: adjustedOffset, duration: 0.28)
    }

    private func animateViewport(toScale targetScale: CGFloat, targetOffset: CGSize, duration: TimeInterval) {
        viewportAnimationTask?.cancel()

        let startScale = scale
        let startOffset = offset
        let frameCount = max(1, Int(duration * 60))

        viewportAnimationTask = Task { @MainActor in
            for frame in 1...frameCount {
                if Task.isCancelled { return }

                let progress = CGFloat(frame) / CGFloat(frameCount)
                let easedProgress = easeOutCubic(progress)
                let nextScale = interpolate(from: startScale, to: targetScale, progress: easedProgress)
                let nextOffset = interpolate(from: startOffset, to: targetOffset, progress: easedProgress)

                updateWithoutAnimation {
                    scale = nextScale
                    lastScale = nextScale
                    offset = nextOffset
                    lastOffset = nextOffset
                }

                try? await Task.sleep(for: .milliseconds(16))
            }

            if Task.isCancelled { return }

            updateWithoutAnimation {
                scale = targetScale
                lastScale = targetScale
                offset = targetOffset
                lastOffset = targetOffset
            }
        }
    }

    private func cancelViewportAnimation() {
        viewportAnimationTask?.cancel()
        viewportAnimationTask = nil
    }

    private func offsetKeepingFocusStable(for newScale: CGFloat, in size: CGSize) -> CGSize {
        guard
            let selectedNoteID,
            let position = displayNodePositions[selectedNoteID] ?? nodePositions[selectedNoteID]
        else {
            return offset
        }

        let screenCenter = CGPoint(x: size.width / 2, y: size.height / 2)
        let currentScreenPoint = CGPoint(
            x: screenCenter.x + offset.width + position.x * scale,
            y: screenCenter.y + offset.height + position.y * scale
        )
        return CGSize(
            width: currentScreenPoint.x - screenCenter.x - position.x * newScale,
            height: currentScreenPoint.y - screenCenter.y - position.y * newScale
        )
    }

    private func updateWithoutAnimation(_ updates: () -> Void) {
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            updates()
        }
    }

    private func easeOutCubic(_ value: CGFloat) -> CGFloat {
        1 - pow(1 - value, 3)
    }

    private func interpolate(from start: CGFloat, to end: CGFloat, progress: CGFloat) -> CGFloat {
        start + (end - start) * progress
    }

    private func interpolate(from start: CGSize, to end: CGSize, progress: CGFloat) -> CGSize {
        CGSize(
            width: interpolate(from: start.width, to: end.width, progress: progress),
            height: interpolate(from: start.height, to: end.height, progress: progress)
        )
    }

    private func controlButton(systemImage: String, accessibilityLabel: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 30, height: 30)
                .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
        .buttonStyle(.plain)
        .foregroundStyle(ObsidianGraphStyle.primaryText)
        .background(ObsidianGraphStyle.controlButton, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        .accessibilityLabel(accessibilityLabel)
    }

    private func nodeHitTargets(in size: CGSize) -> some View {
        let center = CGPoint(x: size.width / 2 + offset.width, y: size.height / 2 + offset.height)
        return ZStack {
            ForEach(graph.nodes) { node in
                let point = screenPoint(for: displayPosition(for: node), center: center)
                let hitSize = max(nodeRadius(node) * 2 + 20, 44)
                Circle()
                    .fill(Color.primary.opacity(0.001))
                    .frame(width: hitSize, height: hitSize)
                    .contentShape(Circle())
                    .highPriorityGesture(nodeDragGesture(for: node))
                    .simultaneousGesture(
                        TapGesture()
                            .onEnded {
                                selectedNoteID = node.id
                                onOpenNote(node.id)
                            }
                    )
                .position(point)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(node.title)
                .accessibilityAddTraits(.isButton)
                .accessibilityIdentifier("graphNode-\(node.id.uuidString)")
            }
        }
    }

    private func nodeDragGesture(for node: GraphNode) -> some Gesture {
        DragGesture(minimumDistance: 3)
            .onChanged { value in
                if dragStartNodePosition == nil {
                    cancelViewportAnimation()
                    dragStartNodePosition = targetPosition(for: node)
                    activeNodeDragID = node.id
                    if selectedNoteID != node.id {
                        selectedNoteID = node.id
                    }
                }

                guard let dragStartNodePosition else { return }
                let newPosition = CGPoint(
                    x: dragStartNodePosition.x + value.translation.width / max(scale, 0.1),
                    y: dragStartNodePosition.y + value.translation.height / max(scale, 0.1)
                )
                updateNodePosition(node.id, to: newPosition)
            }
            .onEnded { _ in
                saveManualPosition(for: node.id, point: targetPosition(for: node))
                dragStartNodePosition = nil
                activeNodeDragID = nil
                settleDisplayedNode(node.id)
            }
    }

    private func drawBackgroundMarks(in context: inout GraphicsContext, size: CGSize, center: CGPoint) {
        let gridSpacing = max(38, 64 * scale)
        let firstX = center.x.truncatingRemainder(dividingBy: gridSpacing) - gridSpacing
        let firstY = center.y.truncatingRemainder(dividingBy: gridSpacing) - gridSpacing

        var x = firstX
        while x <= size.width + gridSpacing {
            var path = Path()
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: size.height))
            context.stroke(path, with: .color(ObsidianGraphStyle.gridLine), lineWidth: 0.55)
            x += gridSpacing
        }

        var y = firstY
        while y <= size.height + gridSpacing {
            var path = Path()
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: size.width, y: y))
            context.stroke(path, with: .color(ObsidianGraphStyle.gridLine), lineWidth: 0.55)
            y += gridSpacing
        }

        let baseRadius = min(size.width, size.height) * 0.30
        for multiplier in [0.82, 1.18, 1.54] {
            let radius = baseRadius * multiplier * sqrt(scale)
            let rect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
            context.stroke(
                Path(ellipseIn: rect),
                with: .color(ObsidianGraphStyle.ringLine),
                style: StrokeStyle(lineWidth: 0.45, dash: [2, 14])
            )
        }
    }

    private func draw(link: GraphLink, source: GraphNode, target: GraphNode, in context: inout GraphicsContext, center: CGPoint) {
        let sourcePoint = screenPoint(for: displayPosition(for: source), center: center)
        let targetPoint = screenPoint(for: displayPosition(for: target), center: center)
        var path = Path()
        path.move(to: sourcePoint)
        path.addLine(to: targetPoint)

        let lineWidth = max(0.55, CGFloat(link.weight) * 0.85) * sqrt(scale)
        let style = StrokeStyle(
            lineWidth: lineWidth,
            lineCap: .round,
            lineJoin: .round
        )

        if link.kind != .tagCooccurrence {
            context.stroke(
                path,
                with: .color(color(for: link).opacity(0.12)),
                style: StrokeStyle(lineWidth: lineWidth + 2.2, lineCap: .round, lineJoin: .round)
            )
        }

        context.stroke(path, with: .color(color(for: link)), style: style)
    }

    private func screenPoint(for point: CGPoint, center: CGPoint) -> CGPoint {
        CGPoint(x: center.x + point.x * scale, y: center.y + point.y * scale)
    }

    private func node(at location: CGPoint, center: CGPoint) -> GraphNode? {
        graph.nodes.first { node in
            let point = screenPoint(for: displayPosition(for: node), center: center)
            let radius = nodeRadius(node)
            let dx = location.x - point.x
            let dy = location.y - point.y
            return sqrt(dx * dx + dy * dy) <= radius + 8
        }
    }

    private func draw(node: GraphNode, in context: inout GraphicsContext, center: CGPoint, size: CGSize) {
        let point = screenPoint(for: displayPosition(for: node), center: center)
        let radius = nodeRadius(node)
        guard isVisible(point: point, radius: radius, in: size) else { return }

        let rect = CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)
        let isSelected = selectedNoteID == node.id
        let baseColor = nodeColor(node, selected: isSelected)

        if isSelected {
            let ringRect = rect.insetBy(dx: -4, dy: -4)
            context.stroke(Path(ellipseIn: ringRect), with: .color(baseColor.opacity(0.72)), lineWidth: 1.15)
        }
        context.fill(Path(ellipseIn: rect), with: .color(baseColor))
        context.stroke(
            Path(ellipseIn: rect),
            with: .color(ObsidianGraphStyle.nodeStroke.opacity(isSelected ? 0.28 : 0.12)),
            lineWidth: isSelected ? 0.85 : 0.4
        )

        guard showsNodeLabels, (!isSelected || showsSelectedNodeLabel) else { return }

        let labelWidth = min(max(CGFloat(node.title.count) * 8.4 + 8, 46), 136)
        let labelTitle = truncatedLabel(node.title, width: labelWidth)
        let label = Text(labelTitle)
            .font(.system(size: isSelected ? 10 : 9, weight: isSelected ? .semibold : .regular))
            .foregroundStyle(isSelected ? ObsidianGraphStyle.selectedNode : ObsidianGraphStyle.secondaryText)
        let labelRect = boundedLabelRect(near: point, radius: radius, preferredWidth: labelWidth, height: 15, in: size)

        context.draw(label, at: CGPoint(x: labelRect.midX, y: labelRect.midY), anchor: .center)
    }

    private func isVisible(point: CGPoint, radius: CGFloat, in size: CGSize) -> Bool {
        let margin = radius + 24
        return point.x >= -margin
            && point.x <= size.width + margin
            && point.y >= -margin
            && point.y <= size.height + margin
    }

    private func boundedLabelRect(
        near point: CGPoint,
        radius: CGFloat,
        preferredWidth: CGFloat,
        height: CGFloat,
        in size: CGSize
    ) -> CGRect {
        let inset: CGFloat = 6
        let safeRect = labelSafeRect(in: size, inset: inset)
        let width = min(preferredWidth, max(32, safeRect.width))
        let unclampedX = point.x - width / 2
        let x = min(max(unclampedX, safeRect.minX), max(safeRect.minX, safeRect.maxX - width))

        let belowY = point.y + radius + 5
        let aboveY = point.y - radius - height - 5
        let preferredY = belowY + height <= safeRect.maxY ? belowY : aboveY
        let y = min(max(preferredY, safeRect.minY), max(safeRect.minY, safeRect.maxY - height))

        return CGRect(x: x, y: y, width: width, height: height)
    }

    private func labelSafeRect(in size: CGSize, inset: CGFloat) -> CGRect {
        CGRect(
            x: inset + labelSafeAreaInsets.leading,
            y: inset + labelSafeAreaInsets.top,
            width: max(32, size.width - inset * 2 - labelSafeAreaInsets.leading - labelSafeAreaInsets.trailing),
            height: max(24, size.height - inset * 2 - labelSafeAreaInsets.top - labelSafeAreaInsets.bottom)
        )
    }

    private func truncatedLabel(_ title: String, width: CGFloat) -> String {
        let maxCharacters = max(4, Int((width - 8) / 8.4))
        guard title.count > maxCharacters else { return title }
        return "\(title.prefix(maxCharacters - 1))…"
    }

    private func displayPosition(for node: GraphNode) -> CGPoint {
        displayNodePositions[node.id] ?? targetPosition(for: node)
    }

    private func targetPosition(for node: GraphNode) -> CGPoint {
        nodePositions[node.id] ?? node.position
    }

    private func nodeRadius(_ node: GraphNode) -> CGFloat {
        let baseRadius = CGFloat(2.3 + min(node.weight, 8) * 0.34)
        let selectedBoost: CGFloat = selectedNoteID == node.id ? 1.4 : 0
        return (baseRadius + selectedBoost) * sqrt(scale)
    }

    private func nodeColor(_ node: GraphNode, selected: Bool) -> Color {
        if selected { return ObsidianGraphStyle.selectedNode }
        if !node.isAIEligible { return ObsidianGraphStyle.mutedNode }
        return ObsidianGraphStyle.primaryNode
    }

    private func color(for link: GraphLink) -> Color {
        switch link.kind {
        case .wiki: ObsidianGraphStyle.tealNode.opacity(0.55)
        case .markdown: ObsidianGraphStyle.cyanNode.opacity(0.44)
        case .aiRelated: ObsidianGraphStyle.amberNode.opacity(0.54)
        case .tagCooccurrence: ObsidianGraphStyle.violetNode.opacity(0.25)
        }
    }

    private func decodeManualNodePositions() -> [UUID: CGPoint] {
        guard
            let data = manualNodePositionsData.data(using: .utf8),
            let stored = try? JSONDecoder().decode([String: StoredGraphPoint].self, from: data)
        else {
            return [:]
        }

        return stored.reduce(into: [UUID: CGPoint]()) { result, entry in
            guard let id = UUID(uuidString: entry.key) else { return }
            result[id] = CGPoint(x: entry.value.x, y: entry.value.y)
        }
    }

    private func saveManualPosition(for id: UUID, point: CGPoint) {
        var stored = decodeManualNodePositions().reduce(into: [String: StoredGraphPoint]()) { result, entry in
            result[entry.key.uuidString] = StoredGraphPoint(x: entry.value.x, y: entry.value.y)
        }
        stored[id.uuidString] = StoredGraphPoint(x: point.x, y: point.y)

        guard let data = try? JSONEncoder().encode(stored) else { return }
        manualNodePositionsData = String(data: data, encoding: .utf8) ?? manualNodePositionsData
    }
}

private struct StoredGraphPoint: Codable {
    var x: CGFloat
    var y: CGFloat
}

private enum ForceDirectedGraphLayout {
    static func positions(
        for graph: KnowledgeGraph,
        canvasSize: CGSize,
        currentPositions: [UUID: CGPoint],
        fixedPositions: [UUID: CGPoint]
    ) -> [UUID: CGPoint] {
        guard !graph.nodes.isEmpty else { return [:] }
        if graph.nodes.count == 1, let node = graph.nodes.first {
            return [node.id: fixedPositions[node.id] ?? .zero]
        }

        let nodes = graph.nodes
        let nodeIDs = Set(nodes.map(\.id))
        let fixed = fixedPositions.filter { nodeIDs.contains($0.key) }
        let bounds = CGSize(
            width: max(110, canvasSize.width * 0.40),
            height: max(110, canvasSize.height * 0.34)
        )

        var positions = initialPositions(
            for: nodes,
            bounds: bounds,
            currentPositions: currentPositions,
            fixedPositions: fixed
        )
        var velocities = Dictionary(uniqueKeysWithValues: nodes.map { ($0.id, CGPoint.zero) })

        for _ in 0..<150 {
            var forces = Dictionary(uniqueKeysWithValues: nodes.map { ($0.id, CGPoint.zero) })

            for leftIndex in nodes.indices {
                for rightIndex in nodes.indices where rightIndex > leftIndex {
                    let left = nodes[leftIndex]
                    let right = nodes[rightIndex]
                    guard
                        let leftPosition = positions[left.id],
                        let rightPosition = positions[right.id]
                    else { continue }

                    let delta = CGPoint(x: leftPosition.x - rightPosition.x, y: leftPosition.y - rightPosition.y)
                    let distance = max(32, hypot(delta.x, delta.y))
                    let strength = 6_400 / (distance * distance)
                    let force = CGPoint(x: delta.x / distance * strength, y: delta.y / distance * strength)
                    forces[left.id, default: .zero].add(force)
                    forces[right.id, default: .zero].add(CGPoint(x: -force.x, y: -force.y))
                }
            }

            for link in graph.links {
                guard
                    let source = positions[link.sourceID],
                    let target = positions[link.targetID]
                else { continue }

                let delta = CGPoint(x: target.x - source.x, y: target.y - source.y)
                let distance = max(24, hypot(delta.x, delta.y))
                let desired = desiredDistance(for: link.kind)
                let strength = (distance - desired) * 0.020 * CGFloat(max(0.45, link.weight))
                let force = CGPoint(x: delta.x / distance * strength, y: delta.y / distance * strength)
                forces[link.sourceID, default: .zero].add(force)
                forces[link.targetID, default: .zero].add(CGPoint(x: -force.x, y: -force.y))
            }

            for node in nodes {
                guard fixed[node.id] == nil, var position = positions[node.id] else {
                    if let fixedPosition = fixed[node.id] {
                        positions[node.id] = fixedPosition
                    }
                    continue
                }

                var force = forces[node.id, default: .zero]
                force.add(CGPoint(x: -position.x * 0.018, y: -position.y * 0.018))

                var velocity = velocities[node.id, default: .zero]
                velocity.x = (velocity.x + force.x) * 0.72
                velocity.y = (velocity.y + force.y) * 0.72
                position.x += velocity.x
                position.y += velocity.y
                position.x = min(max(position.x, -bounds.width), bounds.width)
                position.y = min(max(position.y, -bounds.height), bounds.height)

                positions[node.id] = position
                velocities[node.id] = velocity
            }
        }

        return compacted(positions, fixedPositions: fixed, bounds: bounds)
    }

    private static func initialPositions(
        for nodes: [GraphNode],
        bounds: CGSize,
        currentPositions: [UUID: CGPoint],
        fixedPositions: [UUID: CGPoint]
    ) -> [UUID: CGPoint] {
        let count = max(nodes.count, 1)
        let radius = min(bounds.width, bounds.height) * 0.82

        return Dictionary(uniqueKeysWithValues: nodes.enumerated().map { index, node in
            if let fixedPosition = fixedPositions[node.id] {
                return (node.id, fixedPosition)
            }
            if let currentPosition = currentPositions[node.id] {
                return (node.id, currentPosition)
            }

            let angle = (Double(index) / Double(count)) * .pi * 2 + deterministicJitter(for: node.id)
            let ringOffset = CGFloat(index % 3) * 18
            return (
                node.id,
                CGPoint(
                    x: cos(angle) * (radius + ringOffset),
                    y: sin(angle) * (radius + ringOffset)
                )
            )
        })
    }

    private static func desiredDistance(for kind: LinkKind) -> CGFloat {
        switch kind {
        case .wiki: 116
        case .markdown: 132
        case .aiRelated: 148
        case .tagCooccurrence: 178
        }
    }

    private static func compacted(
        _ positions: [UUID: CGPoint],
        fixedPositions: [UUID: CGPoint],
        bounds: CGSize
    ) -> [UUID: CGPoint] {
        let movablePositions = positions.filter { fixedPositions[$0.key] == nil }
        guard !movablePositions.isEmpty else { return positions }

        let maxX = movablePositions.values.map { abs($0.x) }.max() ?? 1
        let maxY = movablePositions.values.map { abs($0.y) }.max() ?? 1
        let scale = min(1, bounds.width / max(maxX, 1), bounds.height / max(maxY, 1))
        guard scale < 1 else { return positions }

        return positions.reduce(into: [UUID: CGPoint]()) { result, entry in
            if fixedPositions[entry.key] != nil {
                result[entry.key] = entry.value
            } else {
                result[entry.key] = CGPoint(x: entry.value.x * scale, y: entry.value.y * scale)
            }
        }
    }

    private static func deterministicJitter(for id: UUID) -> Double {
        let scalars = id.uuidString.unicodeScalars.map(\.value)
        let seed = scalars.reduce(UInt32(17)) { partial, value in
            partial &* 31 &+ value
        }
        return Double(seed % 47) / 47.0 * 0.34
    }
}

private extension CGPoint {
    mutating func add(_ other: CGPoint) {
        x += other.x
        y += other.y
    }

    func interpolated(to target: CGPoint, amount: CGFloat) -> CGPoint {
        CGPoint(
            x: x + (target.x - x) * amount,
            y: y + (target.y - y) * amount
        )
    }

    func distance(to target: CGPoint) -> CGFloat {
        hypot(x - target.x, y - target.y)
    }
}

private enum ObsidianGraphStyle {
    static let canvasTop = graphColor(
        light: UIColor(red: 0.985, green: 0.985, blue: 0.975, alpha: 1),
        dark: UIColor(red: 0.124, green: 0.124, blue: 0.120, alpha: 1)
    )
    static let canvasBase = graphColor(
        light: UIColor(red: 0.948, green: 0.950, blue: 0.940, alpha: 1),
        dark: UIColor(red: 0.108, green: 0.108, blue: 0.106, alpha: 1)
    )
    static let canvasBottom = graphColor(
        light: UIColor(red: 0.908, green: 0.915, blue: 0.908, alpha: 1),
        dark: UIColor(red: 0.096, green: 0.098, blue: 0.102, alpha: 1)
    )
    static let border = graphColor(
        light: UIColor(red: 0.760, green: 0.770, blue: 0.760, alpha: 0.70),
        dark: UIColor(red: 0.235, green: 0.240, blue: 0.245, alpha: 0.78)
    )
    static let gridLine = graphColor(
        light: UIColor(red: 0.180, green: 0.220, blue: 0.220, alpha: 0.035),
        dark: UIColor(red: 0.780, green: 0.820, blue: 0.860, alpha: 0.020)
    )
    static let ringLine = graphColor(
        light: UIColor(red: 0.000, green: 0.470, blue: 0.440, alpha: 0.060),
        dark: UIColor(red: 0.220, green: 0.780, blue: 0.720, alpha: 0.025)
    )
    static let controlSurface = graphColor(
        light: UIColor(red: 0.965, green: 0.965, blue: 0.955, alpha: 0.94),
        dark: UIColor(red: 0.128, green: 0.132, blue: 0.136, alpha: 0.92)
    )
    static let controlButton = graphColor(
        light: UIColor(red: 0.895, green: 0.905, blue: 0.900, alpha: 1),
        dark: UIColor(red: 0.170, green: 0.176, blue: 0.182, alpha: 1)
    )
    static let primaryText = graphColor(
        light: UIColor(red: 0.115, green: 0.120, blue: 0.125, alpha: 1),
        dark: UIColor(red: 0.860, green: 0.880, blue: 0.900, alpha: 1)
    )
    static let secondaryText = graphColor(
        light: UIColor(red: 0.400, green: 0.430, blue: 0.445, alpha: 1),
        dark: UIColor(red: 0.550, green: 0.600, blue: 0.640, alpha: 1)
    )
    static let nodeStroke = graphColor(
        light: UIColor(red: 0.040, green: 0.060, blue: 0.065, alpha: 1),
        dark: UIColor.white
    )
    static let selectedNode = Color(red: 0.00, green: 0.78, blue: 0.74)
    static let primaryNode = graphColor(
        light: UIColor(red: 0.04, green: 0.56, blue: 0.66, alpha: 1),
        dark: UIColor(red: 0.12, green: 0.76, blue: 0.82, alpha: 1)
    )
    static let tealNode = Color(red: 0.20, green: 0.76, blue: 0.66)
    static let cyanNode = Color(red: 0.00, green: 0.66, blue: 0.86)
    static let amberNode = Color(red: 0.86, green: 0.66, blue: 0.05)
    static let violetNode = Color(red: 0.58, green: 0.32, blue: 0.62)
    static let mutedNode = Color(red: 0.44, green: 0.48, blue: 0.50)
}

private func graphColor(light: UIColor, dark: UIColor) -> Color {
    Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? dark : light
    })
}
