"""Export the owned imagegen source; Pillow is only needed for regeneration."""
from pathlib import Path
from PIL import Image
root=Path(__file__).resolve().parents[1]
image=Image.open(root/'assets/icon-source.png')
assert image.mode=='RGBA' and image.getchannel('A').getextrema()==(0,255)
image.resize((256,256),Image.Resampling.LANCZOS).save(root/'mod/icon.png',optimize=True)
print(root/'mod/icon.png')
