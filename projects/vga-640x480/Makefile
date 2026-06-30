# Icarus Verilog でのシミュレーション用 Makefile
# 使い方:  make / make png / make clean

SRC   := rtl/vga_640x480.v rtl/draw_test.v rtl/top.v
TB    := sim/tb_vga_test.v
BUILD := build
SIM   := $(BUILD)/sim.vvp

.PHONY: all run png clean

all: run

# コンパイル → 実行（frame.ppm を生成）
run: $(SIM)
	vvp $(SIM)

$(SIM): $(SRC) $(TB)
	@mkdir -p $(BUILD)
	iverilog -g2012 -o $(SIM) $(SRC) $(TB)

# frame.ppm を PNG に変換（要 ImageMagick: convert）
png: frame.ppm
	convert frame.ppm frame.png

clean:
	rm -rf $(BUILD) frame.ppm frame.png *.vcd
