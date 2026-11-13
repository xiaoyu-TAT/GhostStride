import Foundation

struct GeoPoint: Codable, Hashable, Sendable {
    var latitude: Double
    var longitude: Double
    var isValid: Bool { latitude.isFinite && longitude.isFinite && (-90...90).contains(latitude) && (-180...180).contains(longitude) }
    static let beijing = GeoPoint(latitude: 39.9042, longitude: 116.4074)
    func distance(to other: GeoPoint) -> Double {
        let r = Double.pi / 180
        let a = pow(sin((other.latitude - latitude) * r / 2), 2) + cos(latitude * r) * cos(other.latitude * r) * pow(sin((other.longitude - longitude) * r / 2), 2)
        return 6_371_000 * 2 * atan2(sqrt(max(0, min(1, a))), sqrt(max(0, 1 - min(1, a))))
    }
    func interpolated(to other: GeoPoint, fraction: Double) -> GeoPoint {
        let t = min(1, max(0, fraction))
        let rad = Double.pi / 180
        let a = [cos(latitude*rad)*cos(longitude*rad), cos(latitude*rad)*sin(longitude*rad), sin(latitude*rad)]
        let b = [cos(other.latitude*rad)*cos(other.longitude*rad), cos(other.latitude*rad)*sin(other.longitude*rad), sin(other.latitude*rad)]
        let angle = acos(min(1, max(-1, zip(a,b).map { $0.0 * $0.1 }.reduce(0,+))))
        if angle < 1e-9 { return self }
        // Antipodal points have no unique shortest arc; choose a deterministic meridian.
        if abs(sin(angle)) < 1e-9 { return GeoPoint(latitude: latitude + (other.latitude-latitude)*t, longitude: longitude + (other.longitude-longitude)*t) }
        let v = zip(a,b).map { $0 * sin((1-t)*angle)/sin(angle) + $1 * sin(t*angle)/sin(angle) }
        return GeoPoint(latitude: atan2(v[2], hypot(v[0],v[1]))/rad, longitude: atan2(v[1],v[0])/rad)
    }
}

struct RouteGeometry: Sendable {
    let points: [GeoPoint]
    let cumulative: [Double]
    var distance: Double { cumulative.last ?? 0 }
    init(_ input: [GeoPoint]) {
        var clean: [GeoPoint] = []
        for p in input where p.isValid { if clean.last != p { clean.append(p) } }
        points = clean
        var sums: [Double] = clean.isEmpty ? [] : [0]
        for i in 1..<max(1, clean.count) { sums.append(sums[i-1] + clean[i-1].distance(to: clean[i])) }
        cumulative = sums
    }
    func position(at meters: Double) -> GeoPoint? {
        guard let first = points.first else { return nil }
        guard distance > 0 else { return first }
        let d = min(distance, max(0, meters.isFinite ? meters : 0))
        if d >= distance { return points.last }
        var lo = 1, hi = cumulative.count - 1
        while lo < hi { let mid = (lo+hi)/2; if cumulative[mid] < d { lo = mid+1 } else { hi = mid } }
        let length = cumulative[lo] - cumulative[lo-1]
        return points[lo-1].interpolated(to: points[lo], fraction: length > 0 ? (d-cumulative[lo-1])/length : 0)
    }
    func completed(at meters: Double) -> [GeoPoint] {
        guard let p = position(at: meters) else { return [] }
        return zip(points,cumulative).filter { $0.1 < meters }.map(\.0) + [p]
    }
    /// 根据当前位置附近的路线夹角计算转弯减速系数。
    ///
    /// 直线路段返回 1；转弯越急，系数越低，最低为 0.65。
    /// 该系数只用于应用内模拟，不会修改原始路线点。
    func turnFactor(at meters: Double) -> Double {
        guard points.count > 2, distance > 0 else { return 1 }
        let d = min(distance, max(0, meters))
        var index = 1
        while index < cumulative.count - 1 && cumulative[index] < d { index += 1 }
        let incoming = localVector(from: points[index - 1], to: points[index])
        let outgoing = localVector(from: points[index], to: points[min(index + 1, points.count - 1)])
        let incomingLength = hypot(incoming.x, incoming.y)
        let outgoingLength = hypot(outgoing.x, outgoing.y)
        guard incomingLength > 0, outgoingLength > 0 else { return 1 }
        let cosine = max(-1, min(1, (incoming.x * outgoing.x + incoming.y * outgoing.y) / (incomingLength * outgoingLength)))
        let turn = acos(cosine) / .pi
        return max(0.65, 1 - turn * 0.35)
    }
    /// 在路线切线的法线方向增加小幅横向偏移，模拟 GPS 采样的自然抖动。
    ///
    /// 偏移使用米作为单位，并通过局部经纬度换算为坐标。原始
    /// `position(at:)` 始终保持精确路线位置，只有模拟定位发布的位置会使用该结果。
    func offsetPosition(at meters: Double, lateralMeters: Double) -> GeoPoint? {
        guard let point = position(at: meters), lateralMeters.isFinite else { return point }
        let d = min(distance, max(0, meters))
        let next = position(at: min(distance, d + 2))
        guard let next else { return point }
        let vector = localVector(from: point, to: next)
        let length = hypot(vector.x, vector.y)
        guard length > 0 else { return point }
        let east = -vector.y / length * lateralMeters
        let north = vector.x / length * lateralMeters
        let latitude = point.latitude + north / 111_000
        let longitudeScale = max(0.01, cos(point.latitude * .pi / 180))
        let longitude = point.longitude + east / (111_000 * longitudeScale)
        return GeoPoint(latitude: latitude, longitude: longitude)
    }
    private func localVector(from: GeoPoint, to: GeoPoint) -> (x: Double, y: Double) {
        let latitudeScale = 111_000.0
        let longitudeScale = latitudeScale * max(0.01, cos(from.latitude * .pi / 180))
        return (x: (to.longitude - from.longitude) * longitudeScale, y: (to.latitude - from.latitude) * latitudeScale)
    }
}

enum MotionPreset: String, CaseIterable, Identifiable {
    case walk = "步行", jog = "慢跑", run = "快跑", cycle = "骑行"
    var id: String { rawValue }
    var kmh: Double { switch self { case .walk: 5; case .jog: 8; case .run: 12; case .cycle: 20 } }
}
enum MotionUnits {
    static func pace(kmh: Double) -> Double { kmh.isFinite && kmh > 0 ? 60 / kmh : 0 }
    static func speed(pace: Double) -> Double { pace.isFinite && pace > 0 ? 60 / pace : 0 }
}

enum SimulationState: String, Sendable { case idle = "未开始", running = "播放中", paused = "已暂停", finished = "已完成", stopped = "已停止" }
/// 纯状态机：`now` 必须是单调递增的真实时间，`elapsed` 是包含预览倍率的模拟时间。
struct SimulationEngine: Sendable {
    private(set) var geometry = RouteGeometry([])
    private(set) var state: SimulationState = .idle
    private(set) var elapsed = 0.0
    private(set) var traveled = 0.0
    /// 当前模拟瞬时速度，单位为 m/s；自然运动模式下会受到加速度限制。
    private(set) var currentSpeed = 0.0
    private var lastTick: Double?
    var kmh = 8.0
    var previewRate = 1.0
    var loops = false
    /// 是否启用加减速、转弯减速和横向轨迹扰动。
    /// 默认关闭以保持引擎直接使用时的确定性；AppModel 默认开启。
    var realisticMotion = false
    var lapDistance: Double {
        guard geometry.distance > 0 else { return 0 }
        return loops ? traveled.truncatingRemainder(dividingBy: geometry.distance) : min(traveled, geometry.distance)
    }
    var position: GeoPoint? { geometry.position(at: lapDistance) }
    /// 返回实际发布给 MockLocationProvider 的位置。
    /// 关闭自然运动时返回路线位置，开启后只增加米级横向扰动。
    var simulatedPosition: GeoPoint? {
        guard realisticMotion, let position = position else { return self.position }
        let lateral = sin(elapsed * 0.75) * 0.8 + sin(elapsed * 1.9) * 0.25
        return geometry.offsetPosition(at: lapDistance, lateralMeters: lateral)
    }
    var remaining: Double { max(0, geometry.distance-lapDistance) }
    var remainingSeconds: Double { kmh > 0 ? remaining/(kmh/3.6) : 0 }
    mutating func load(_ points: [GeoPoint]) { geometry = RouteGeometry(points); reset() }
    mutating func reset() { state = .idle; elapsed = 0; traveled = 0; currentSpeed = 0; lastTick = nil }
    mutating func start(now: Double) {
        guard now.isFinite, !geometry.points.isEmpty else { return }
        reset()
        state = geometry.distance > 0 ? .running : .finished
        lastTick = state == .running ? now : nil
    }
    mutating func advance(now: Double) {
        guard state == .running, now.isFinite, let old = lastTick, now >= old else { return }
        lastTick = now
        guard kmh.isFinite, kmh > 0, previewRate.isFinite, previewRate > 0 else { return }
        let dt = (now-old) * min(5, previewRate)
        let baseSpeed = min(200, kmh) / 3.6
        // 自然模式先根据路线转角得到目标速度，再以有限加速度逼近目标，
        // 避免每个采样点瞬间跳到设定速度。
        let targetSpeed = realisticMotion ? baseSpeed * geometry.turnFactor(at: lapDistance) : baseSpeed
        let speed: Double
        if realisticMotion {
            // 跑步时减速通常比加速更快；这里使用保守上限，避免出现不自然的速度突变。
            let acceleration = targetSpeed >= currentSpeed ? 0.9 : 1.3
            currentSpeed += min(acceleration * dt, abs(targetSpeed - currentSpeed)) * (targetSpeed >= currentSpeed ? 1 : -1)
            speed = currentSpeed
        } else {
            currentSpeed = baseSpeed
            speed = baseSpeed
        }
        let used = loops ? dt : min(dt, max(0, geometry.distance-traveled)/max(speed, 0.001))
        elapsed += used; traveled += used*speed
        if !loops && traveled >= geometry.distance - 1e-7 { traveled = geometry.distance; state = .finished; lastTick = nil }
    }
    mutating func pause(now: Double) { advance(now: now); if state == .running { state = .paused }; lastTick = nil }
    mutating func resume(now: Double) { guard state == .paused, now.isFinite else { return }; state = .running; lastTick = now }
    mutating func stop(now: Double) { advance(now: now); state = .stopped; currentSpeed = 0; lastTick = nil }
}
