from PIL import Image, ImageDraw, ImageFilter
import math, sys
S=4096
def lerp(a,b,t): return tuple(int(a[i]+(b[i]-a[i])*t) for i in range(3))
# background: diagonal gradient deep violet -> near black
bg=Image.new('RGB',(S,S))
px=bg.load()
top=(46,24,92); bot=(10,8,22)
import numpy as np
yy,xx=np.mgrid[0:S,0:S]
grad=Image.fromarray(np.clip((xx*0.35+yy*0.65)/S*255,0,255).astype('uint8'),'L')
bg=Image.composite(Image.new('RGB',(S,S),bot),Image.new('RGB',(S,S),top),grad)
# soft glow
glow=Image.new('L',(S,S),0); d=ImageDraw.Draw(glow)
d.ellipse((S*0.18,S*0.12,S*0.95,S*0.9),fill=150)
glow=glow.filter(ImageFilter.GaussianBlur(S*0.12))
bg=Image.composite(Image.new('RGB',(S,S),(150,90,255)),bg,glow.point(lambda v:int(v*0.55)))
img=bg.convert('RGBA')
def card(angle,cx,cy,w,h,fill,outline=None):
    layer=Image.new('RGBA',(S,S),(0,0,0,0)); d=ImageDraw.Draw(layer)
    d.rounded_rectangle((cx-w/2,cy-h/2,cx+w/2,cy+h/2),radius=w*0.12,fill=fill,outline=outline,width=int(S*0.012) if outline else 0)
    return layer.rotate(angle,center=(cx,cy+h*0.9),resample=Image.BICUBIC)
w,h=S*0.42,S*0.56; cx,cy=S*0.5,S*0.47
# shadow
sh=card(0,cx,cy+S*0.03,w,h,(0,0,0,170)).filter(ImageFilter.GaussianBlur(S*0.03))
img=Image.alpha_composite(img,sh)
img=Image.alpha_composite(img,card(18,cx,cy,w,h,(96,62,170,255),(170,130,255,255)))
img=Image.alpha_composite(img,card(-18,cx,cy,w,h,(120,80,205,255),(190,150,255,255)))
front=card(0,cx,cy,w,h,(28,20,52,255),(200,165,255,255))
img=Image.alpha_composite(img,front)
# play triangle on front card
d=ImageDraw.Draw(img)
r=S*0.12; tx,ty=cx+r*0.12,cy
d.polygon([(tx-r*0.6,ty-r),(tx-r*0.6,ty+r),(tx+r*1.0,ty)],fill=(180,140,255,255))
# rounded-square mask
mask=Image.new('L',(S,S),0); ImageDraw.Draw(mask).rounded_rectangle((0,0,S-1,S-1),radius=S*0.2,fill=255)
out=Image.new('RGBA',(S,S),(0,0,0,0)); out.paste(img,(0,0),mask)
out.resize((1024,1024),Image.LANCZOS).save(sys.argv[1],optimize=True)
