import Foundation
import MetalKit

private let numParticles = 2_000_000

final class Renderer: NSObject {

    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let pipelineState: MTLRenderPipelineState
    private let computePipelineState: MTLComputePipelineState

    private var totalVertexCount: Int = 0
    private var currentBufferIndex = 0

    private var particleBuffer: MTLBuffer
    private var particleVB: MTLBuffer

    private var viewportSize: simd_uint2 = [0, 0]

    private var texture: MTLTexture

    init(metalView: MTKView) {
        guard let device = MTLCreateSystemDefaultDevice(),
              let commandQueue = device.makeCommandQueue() else { fatalError() }

        self.device = device
        self.commandQueue = commandQueue

        metalView.preferredFramesPerSecond = 60

        metalView.device = device
        metalView.clearColor = MTLClearColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1)

        guard let defaultLibrary = device.makeDefaultLibrary(),
              let vertexFunction = defaultLibrary.makeFunction(name: "vertexShader"),
              let fragmentFunction = defaultLibrary.makeFunction(name: "fragmentShader"),
              let kernelFunction = defaultLibrary.makeFunction(name: "particleMove") else { fatalError() }

        self.computePipelineState = {
            do {
                return try device.makeComputePipelineState(function: kernelFunction)
            } catch {
                fatalError("Failed to create compute pipeline state: \(error)")
            }
        }()

        let pipelineStateDescriptor = MTLRenderPipelineDescriptor()
        pipelineStateDescriptor.label = "MyPipeline"
        pipelineStateDescriptor.vertexFunction = vertexFunction
        pipelineStateDescriptor.fragmentFunction = fragmentFunction

        pipelineStateDescriptor.colorAttachments[0].pixelFormat = metalView.colorPixelFormat
        pipelineStateDescriptor.vertexBuffers[0].mutability = .mutable

        self.pipelineState = {
            do {
                return try device.makeRenderPipelineState(descriptor: pipelineStateDescriptor)
            } catch {
                fatalError("Failed to create pipeline state: \(error)")
            }
        }()

        let textureLoader = MTKTextureLoader(device: device)
        self.texture = {
            do {
                return try textureLoader.newTexture(name: "farm", scaleFactor: 1.0, bundle: nil, options: [.SRGB: false])
            } catch {
                fatalError("No texture: \(error)")
            }
        }()

        particleBuffer = device.makeBuffer(length: numParticles * MemoryLayout<Particle>.stride)!

        let particleVBSize = numParticles * MemoryLayout<Vertex>.stride

        let vb = device.makeBuffer(length: particleVBSize)!
        vb.label = "Particle"
        particleVB = vb

        super.init()

        generateParticles()

        metalView.delegate = self
    }

    private func generateParticles() {
        var particles: [Particle] = []

        for _ in 0...numParticles {
            var p = vector_float2()
            p.x = Float.random(in: -1800...1800)
            p.y = Float.random(in: -1200...1200)

            let particle = Particle(position: p, initialPos: p, velocity: vector_float2.zero, acceleration: vector_float2(0, 0))
            particles.append(particle)
        }

        let particleBufferPtr = particleBuffer.contents().bindMemory(to: Particle.self, capacity: numParticles)
        memcpy(particleBufferPtr, &particles, numParticles * MemoryLayout<Particle>.stride)
    }
}

extension Renderer: MTKViewDelegate {
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        viewportSize = [UInt32(size.width), UInt32(size.height)]
    }

    func updateState(commandBuffer: MTLCommandBuffer) {
        if let computeEncoder = commandBuffer.makeComputeCommandEncoder() {
            computeEncoder.setComputePipelineState(computePipelineState)

            let threadGroupSize = min(computePipelineState.maxTotalThreadsPerThreadgroup, numParticles);
            computeEncoder.setBuffer(particleBuffer, offset: 0, index: 0)
            computeEncoder.setBuffer(particleVB, offset: 0, index: 1)
            computeEncoder.dispatchThreads(MTLSize(width: numParticles, height: 1, depth: 1),
                                           threadsPerThreadgroup: MTLSize(width: threadGroupSize, height: 1, depth: 1))
            computeEncoder.endEncoding()
        }
    }

    func draw(in view: MTKView) {
        guard let commandBuffer = commandQueue.makeCommandBuffer() else { return }

        updateState(commandBuffer: commandBuffer)

        guard let renderPassDescriptor = view.currentRenderPassDescriptor,
              let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else { return }

        commandBuffer.label = "MyCommand"
        renderEncoder.label = "MyRenderEncoder"

        renderEncoder.setViewport(MTLViewport(originX: 0, originY: 0,
                                              width: Double(viewportSize.x),
                                              height: Double(viewportSize.y),
                                              znear: 0, zfar: 0))

        renderEncoder.setRenderPipelineState(pipelineState)

        renderEncoder.setVertexBuffer(particleVB, offset: 0, index: 0)

        renderEncoder.setVertexBytes(&viewportSize,
                                     length: MemoryLayout<simd_uint2>.stride,
                                     index: Int(AAPLVertexInputIndexViewportSize.rawValue))

        renderEncoder.setFragmentTexture(texture, index: 0)

        renderEncoder.drawPrimitives(type: .point, vertexStart: 0, vertexCount: numParticles)

        renderEncoder.endEncoding()

        if let drawable = view.currentDrawable {
            commandBuffer.present(drawable)
        }

        commandBuffer.commit()
    }
}
