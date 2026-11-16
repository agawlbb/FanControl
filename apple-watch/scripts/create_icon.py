from PIL import Image, ImageDraw
from pathlib import Path
import json, math
root=Path(__file__).resolve().parents[1]/'WatchApp'/'Assets.xcassets'
folder=root/'AppIcon.appiconset'
folder.mkdir(parents=True,exist_ok=True)
im=Image.new('RGB',(1024,1024),'#111b22'); draw=ImageDraw.Draw(im)
# A simple geometric fan, matching the Android fan identity.
for n in range(3):
    angle=n*2*math.pi/3
    points=[]
    for x,y in [(0,-50),(80,-115),(170,-240),(135,-345),(-10,-350),(-90,-255),(-70,-130)]:
        points.append((512+x*math.cos(angle)-y*math.sin(angle),512+x*math.sin(angle)+y*math.cos(angle)))
    draw.polygon(points,fill='#5ce1c1')
draw.ellipse((437,437,587,587),fill='#111b22',outline='#5ce1c1',width=26)
im.save(folder/'AppIcon.png')
(folder/'Contents.json').write_text(json.dumps({'images':[{'filename':'AppIcon.png','idiom':'universal','platform':'watchos','size':'1024x1024'}],'info':{'author':'xcode','version':1}},indent=2))
(root/'Contents.json').write_text(json.dumps({'info':{'author':'xcode','version':1}}))
