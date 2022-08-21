import Foundation
import simd

struct Particle {
    var position: vector_float2
    var initialPos: vector_float2
    var velocity: vector_float2
    var acceleration: vector_float2
    var life: Float = 0.0
}
