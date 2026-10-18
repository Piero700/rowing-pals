import re,json,sys,os
src,out=sys.argv[1],sys.argv[2]; os.makedirs(out,exist_ok=True)
for f in os.listdir(src):
    if not f.endswith('.dc.html'): continue
    h=open(os.path.join(src,f)).read()
    m=re.search(r'const DARK = (\{.*?\});',h)
    if m:
        d=json.loads(m.group(1)); h=re.sub(r'\{\{ t\.(\w+) \}\}',lambda x:d[x.group(1)],h)
    h=re.sub(r'<script[\s\S]*?</script>','',h); h=re.sub(r'</?(x-dc|helmet)>','',h)
    h=h.replace('<head>','<head><style>body{background:#101114}</style>')
    open(os.path.join(out,f.replace('.dc.html','.html')),'w').write(h)
