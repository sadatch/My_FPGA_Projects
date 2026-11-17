# シミュレーションと図の生成 (要 Icarus Verilog, Python3 + numpy/matplotlib/Pillow)
#   make test     RTL を参照モデルと照合 (core / bcd / top)
#   make core     ニューロンコアだけ (数秒)
#   make figures  docs/ の図を作り直す
#   make clean

.PHONY: test core bcd top figures clean

test:
	python3 python/run_tests.py

core:
	python3 python/run_tests.py core

bcd:
	python3 python/run_tests.py bcd

top:
	python3 python/run_tests.py top
	python3 python/serial_viewer.py --replay sim/out/uart_capture.bin --save docs/uart_capture.png

figures:
	python3 python/make_figures.py

clean:
	rm -rf build sim/out __pycache__ python/__pycache__
