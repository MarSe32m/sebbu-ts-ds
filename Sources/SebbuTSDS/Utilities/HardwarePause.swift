#if arch(arm) || arch(arm64) || arch(arm64_32)
#if arch(arm)
@_extern(c, "llvm.arm.hint")
@inline(__always)
@_transparent
@inlinable
func _hint(_: UInt32)
#else
@_extern(c, "llvm.aarch64.hint")
@inline(__always)
@_transparent
@inlinable
func _hint(_: UInt32)
#endif
@inline(__always)
@_transparent
@inlinable
func _pause() {
  _hint(2)
}
#elseif arch(i386) || arch(x86_64)
@_extern(c, "llvm.x86.sse2.pause")
@inline(__always)
@_transparent
@inlinable
func _pause()
#else
@inline(__always)
@_transparent
@inlinable
func _pause() {}
#endif

@inline(__always)
@_transparent
@inlinable
func _hardwarePause() {
    _pause()
}
