#!/usr/bin/env python3
# 营造 demo GIF 生成器 —— 无 vhs 环境的替代路径（纯 python3 + Pillow，零外部工具/零 brew 依赖）
# 真实运行 inspect-skill.sh 两次（病体 fixture vs 营造自身），逐行 reveal 渲染为动画 GIF。
# 纪律同 demo.tape：用真实运行写，不摆拍。顺带把最新输出同步回 demo-run.txt。
# 用法: python3 assets/render-demo-gif.py   （仓库根运行）
import subprocess, os
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))  # 仓库根
os.chdir(ROOT)

# Catppuccin Mocha 配色
BG=(30,30,46); FG=(205,214,244); GREEN=(166,227,161); YELLOW=(249,226,175)
RED=(243,139,168); BLUE=(137,180,250); MAUVE=(203,166,247)

def load_font(sz):
    for p in ["/System/Library/Fonts/PingFang.ttc","/System/Library/Fonts/STHeiti Light.ttc","/System/Library/Fonts/Menlo.ttc"]:
        if os.path.exists(p):
            try: return ImageFont.truetype(p, sz)
            except Exception: pass
    return ImageFont.load_default()
F = load_font(15)

LH=24; PAD=18; WIDTH=1280

def color(line):
    s=line.lstrip()
    if s.startswith("PASS"): return GREEN
    if s.startswith("WARN"): return YELLOW
    if s.startswith("FAIL"): return RED
    if s.startswith("$"): return MAUVE
    if s.startswith("──") or s.startswith("【"): return BLUE
    return FG

def run(cmd):
    return subprocess.run(cmd, shell=True, capture_output=True, text=True).stdout.rstrip("\n")

cmdA="bash tools/inspect-skill.sh tests/fixtures/bad-skill-demo --target opensource"
cmdB="bash tools/inspect-skill.sh . --target opensource"
linesA=[f"$ {cmdA}"]+run(cmdA).split("\n")
linesB=[f"$ {cmdB}"]+run(cmdB).split("\n")

MAXLINES=max(len(linesA),len(linesB))
H=PAD*2+MAXLINES*LH

def frame(lines, n):
    img=Image.new("RGB",(WIDTH,H),BG); d=ImageDraw.Draw(img); y=PAD
    for ln in lines[:n]:
        d.text((PAD,y),ln,font=F,fill=color(ln)); y+=LH
    return img

frames=[]; durs=[]
for n in range(1,len(linesA)+1): frames.append(frame(linesA,n)); durs.append(85)
durs[-1]=1800
for n in range(1,len(linesB)+1): frames.append(frame(linesB,n)); durs.append(85)
durs[-1]=2600

pframes=[f.convert("P",palette=Image.ADAPTIVE,colors=32) for f in frames]
out="assets/demo.gif"
pframes[0].save(out,save_all=True,append_images=pframes[1:],duration=durs,loop=0,optimize=True,disposal=2)
print(f"✓ {out}（{len(frames)} 帧，{os.path.getsize(out)//1024} KB，{WIDTH}x{H}）")

with open("assets/demo-run.txt","w") as f:
    f.write("# 营造 demo 真实运行存档（GIF 数据源 · 由 render-demo-gif.py 真实运行生成）\n")
    f.write("## RUN A · 病体 fixture（--target opensource）\n"); f.write("\n".join(linesA)+"\n\n")
    f.write("## RUN B · 营造自身（--target opensource）\n"); f.write("\n".join(linesB)+"\n")
print("✓ assets/demo-run.txt 已同步最新运行")
