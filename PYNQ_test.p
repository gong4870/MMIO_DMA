from pynq import Overlay, allocate, MMIO
import numpy as np

# === 1. 오버레이 로드
print("🔧 Overlay 로드 중...")
overlay = Overlay('/home/xilinx/jupyter_notebooks/MMIO/design_1.bit')
dma = overlay.axi_dma_0
print("✅ Overlay 로드 완료")

# === 2. MMIO 통해 BRAM 초기화
BRAM_BASE = 0x40000000
BRAM_RANGE = 0x1000
mmio = MMIO(BRAM_BASE, BRAM_RANGE)

print("\n📦 BRAM 초기화 (64bit 간격 주소)")
for i in range(10):
    mmio.write(i * 8, i)
    print(f"[MMIO WRITE] Addr=0x{BRAM_BASE + i*8:08X} <- {i}")

# === 3. DMA용 버퍼 할당 (64비트로!)
input_buffer = allocate(shape=(20,), dtype=np.uint64)
output_buffer = allocate(shape=(20,), dtype=np.uint64)
output_buffer[:] = 0  # 수신 전에 초기화
print("\n📤 DMA 버퍼 생성 및 초기화 완료 (64bit)")

# === 4. 입력 버퍼에 값 작성
print("\n📝 Input Buffer 작성 (64bit):")
for i in range(20):
    input_buffer[i] = i * 10
    print(f"[INPUT] input_buffer[{i}] = {input_buffer[i]}")

# === 5. MMIO 내용 확인
print("\n📖 MMIO Readback 확인:")
for offset in range(0, 80, 8):
    val = mmio.read(offset)
    print(f"[MMIO READ] Addr=0x{BRAM_BASE + offset:08X} -> {val}")

# === 6. DMA 전송 시작
dma.recvchannel.transfer(output_buffer)   # 먼저 수신 대기 설정
dma.sendchannel.transfer(input_buffer)   # 그다음 송신 시작

dma.sendchannel.wait()
print("보냄 완료")
dma.recvchannel.wait()
print("받기 완료")


# === 7. 출력 버퍼 확인
print("\n📥 DMA Output Buffer 확인 (64bit):")
for i in range(20):
    val = output_buffer[i]
    print(f"[OUTPUT] output_buffer[{i}] = {val}")
