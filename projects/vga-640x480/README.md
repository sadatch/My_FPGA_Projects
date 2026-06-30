# vga-640x480

FPGA で VGA（640×480 / 60Hz）映像を出力する入門用サンプル。
カラーバーの背景に、白い箱が画面内をバウンドするテストパターンを表示します。

![preview](docs/vga_frame0.png)

## ディレクトリ構成

```
vga-640x480/
├── rtl/                 # 合成対象のVerilog（実機に書き込む側）
│   ├── vga_640x480.v    #   タイミング生成の土台（x,y,visible,hsync,vsync）
│   ├── draw_test.v      #   描画（x,yから色を決める。ここを書き換えて遊ぶ）
│   └── top.v            #   全体配線（PLL・vga・drawをつなぐ）
├── sim/
│   └── tb_vga_test.v    # シミュレーション用テストベンチ（PCで絵を確認）
├── docs/                # プレビュー画像
├── Makefile             # iverilogでのビルド/実行
└── .gitignore
```

## 仕組みのざっくり説明

```
clk → [vga_640x480] →(x,y,visible,hsync,vsync)→ [draw_test] →(r,g,b)→ ピン → VGA
```

- `vga_640x480.v` … クロックを数えて「今どこを描いているか(x,y)」を作る土台。基本いじらない。
- `draw_test.v` … 受け取った座標から色を決める主役。**ここを書き換えると絵が変わる。**
- `top.v` … 上2つを部品として置いて配線する。

詳しい解説は Obsidian の `FPGA/VGA映像出力_コード解説.md` を参照。

## シミュレーション（実機なしで絵を確認）

[Icarus Verilog](http://iverilog.icarus.com/) が必要です。

```sh
make        # rtl/ と sim/ をコンパイルして実行 → frame.ppm を生成
make png    # frame.ppm を frame.png に変換（要 ImageMagick）
make clean  # 生成物を削除
```

`frame.ppm` / `frame.png` を画像ビューアで開くと、映るはずの絵が確認できます。

## 実機で動かすときの残作業

1. `top.v` の `wire pix_clk = clk_in;` を **PLLで25MHz** に置き換える
   （iCE40なら `icepll`、Gowin/Tang Nano なら Gowin PLL）。
2. **制約ファイル**で `hsync`/`vsync`/`vga_r/g/b` を実ピンに割り当てる
   （`vga_r/g/b` は抵抗DAC経由でVGAコネクタの 1/2/3 番ピンへ）。

## ライセンス

MIT（必要に応じて変更してください）。
