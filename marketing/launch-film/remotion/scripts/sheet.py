import sys,glob,os
from PIL import Image,ImageDraw
files=sorted(glob.glob(sys.argv[1]+'/*.jpg')); cols=int(sys.argv[3]) if len(sys.argv)>3 else 3; W=640;H=360
rows=(len(files)+cols-1)//cols; sh=Image.new('RGB',(W*cols,(H+24)*rows),'#222')
d=ImageDraw.Draw(sh)
for i,f in enumerate(files):
    im=Image.open(f).resize((W,H)); x=(i%cols)*W; y=(i//cols)*(H+24); sh.paste(im,(x,y+24)); d.text((x+6,y+6),os.path.basename(f),fill='white')
sh.save(sys.argv[2])
