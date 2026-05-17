import bpy, bmesh, math, random, os, sys
import numpy as np
from mathutils import Vector, noise as bnoise

random.seed(11)
ARGS = sys.argv[sys.argv.index("--")+1:] if "--" in sys.argv else []
PREVIEW = "preview" in ARGS

_HERE = os.path.dirname(os.path.abspath(__file__))
_REPO = os.path.dirname(_HERE)
HEIGHTMAP = os.path.join(_REPO, "source_assets", "heightmaps", "yarimada_16bit.exr")
OUT = os.path.join(_REPO, "data", "terrain")
TERR_SIZE = 2000.0         # meters across (2 km x 2 km)
SRC_RES   = 1254           # native EXR resolution
TERR_GRID = 620 if PREVIEW else SRC_RES   # full: 1:1 with source pixels
RELIEF    = 230.0          # max vertical relief (m)

def log(m): print("[MAPGEN]", m, flush=True)

bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.context.scene

# ---------- load + smooth heightmap (kill erosion spikes) ----------
img = bpy.data.images.load(HEIGHTMAP)
W, H = img.size
px = np.empty(W*H*4, dtype=np.float32)
img.pixels.foreach_get(px)
hm = px.reshape(H, W, 4)[:, :, 0].astype(np.float32)   # luminance ch
hm = (hm - hm.min()) / (hm.max() - hm.min() + 1e-9)

def blur(a, r, iters):
    a = a.astype(np.float32)
    for _ in range(iters):
        pad = np.pad(a, ((r,r),(r,r)), mode='edge')
        s = np.cumsum(np.cumsum(pad, axis=0), axis=1)
        s = np.pad(s, ((1,0),(1,0)), mode='constant')
        win = 2*r+1
        out = (s[win:, win:] - s[:-win, win:] - s[win:, :-win] + s[:-win, :-win]) / (win*win)
        a = out[:a.shape[0], :a.shape[1]]
    return a

# near-lossless: single 1px pass only removes hard 16-bit quant/erosion spikes,
# preserving virtually all native EXR detail
hm = blur(hm, 1, 1)
hm = (hm - hm.min()) / (hm.max() - hm.min() + 1e-9)

def slope_relax(a, iters, pct, mix, rad):
    """Selective fix: relax ONLY the steepest pixels (cliffs / spikes /
    over-steep mountain faces) proportionally to how steep they are.
    Gentle, detailed terrain is left pixel-exact. Slope is recomputed each
    pass so harsh spots get resolved one by one without global blurring."""
    a = a.astype(np.float32)
    for _ in range(iters):
        gy, gx = np.gradient(a)
        slope = np.hypot(gx, gy)
        thr = np.percentile(slope, pct)
        sm = blur(a, rad, 1)
        w = np.clip((slope - thr) / (slope.max() - thr + 1e-9), 0.0, 1.0) * mix
        a = a*(1.0 - w) + sm*w
    return a

# targets the over-steep mountain & jagged ridges only; valleys/erosion stay crisp
hm = slope_relax(hm, iters=10, pct=80.0, mix=0.6, rad=2)
hm = (hm - hm.min()) / (hm.max() - hm.min() + 1e-9)

bimg = bpy.data.images.new("hm_smooth", W, H, float_buffer=True)
rgba = np.zeros((H, W, 4), dtype=np.float32)
rgba[:, :, 0] = rgba[:, :, 1] = rgba[:, :, 2] = hm
rgba[:, :, 3] = 1.0
bimg.pixels.foreach_set(rgba.reshape(-1))

# ---------- terrain ----------
bpy.ops.mesh.primitive_grid_add(x_subdivisions=TERR_GRID, y_subdivisions=TERR_GRID, size=TERR_SIZE)
terr = bpy.context.object; terr.name = "Terrain"
tex = bpy.data.textures.new("hmap", 'IMAGE'); tex.image = bimg; tex.extension = 'EXTEND'
tex.use_interpolation = True            # smooth sub-pixel sampling, no detail clamp
d = terr.modifiers.new("disp", 'DISPLACE')
d.texture = tex; d.texture_coords = 'UV'; d.strength = RELIEF; d.mid_level = 0.0
bpy.ops.object.modifier_apply(modifier="disp")
# NOTE: no geometry relax / no macro synthetic displacement -> the mesh now
# reproduces the full native EXR detail 1:1. Only a faint micro grain remains
# so flat triangles don't read as plastic; it does not override the DEM.
nt=bpy.data.textures.new("micrograin",'CLOUDS'); nt.noise_scale=4.0; nt.noise_depth=2
md=terr.modifiers.new("micrograin",'DISPLACE')
md.texture=nt; md.texture_coords='LOCAL'; md.strength=0.6; md.mid_level=0.5
bpy.ops.object.modifier_apply(modifier="micrograin")
me = terr.data
bpy.ops.object.shade_smooth()

zs = np.array([v.co.z for v in me.vertices]); zs.sort()
zmin, zmax = float(zs[0]), float(zs[-1])
SEA  = float(zs[int(len(zs)*0.34)])
log(f"z {zmin:.1f}..{zmax:.1f} sea={SEA:.1f} relief={zmax-SEA:.1f}")

# ---------- helpers ----------
def new_mat(name):
    m = bpy.data.materials.new(name); m.use_nodes = True
    return m, m.node_tree.nodes, m.node_tree.links

def simple(name, col, rough=0.85, spec=0.3):
    m, nn, _ = new_mat(name); b = nn['Principled BSDF']
    b.inputs['Base Color'].default_value = (*col, 1)
    b.inputs['Roughness'].default_value = rough
    return m

def ground_mat(name, ca, cb, rough, mac_m, mic_m, bstr):
    """Procedural ground in real metres: macro+micro colour + 2-octave relief.
       mac_m = macro feature size (m), mic_m = micro feature size (m)."""
    m, nn, ll = new_mat(name); b = nn['Principled BSDF']
    b.inputs['Roughness'].default_value = rough
    tc = nn.new('ShaderNodeTexCoord')
    # ---- colour: macro patches + fine mottle ----
    n1 = nn.new('ShaderNodeTexNoise'); n1.inputs['Scale'].default_value=1.0/mac_m
    n1.inputs['Detail'].default_value=8.0; n1.inputs['Roughness'].default_value=0.65
    ll.new(tc.outputs['Object'], n1.inputs['Vector'])
    cr = nn.new('ShaderNodeValToRGB')
    cr.color_ramp.elements[0].position=0.32; cr.color_ramp.elements[0].color=(*ca,1)
    cr.color_ramp.elements[1].position=0.68; cr.color_ramp.elements[1].color=(*cb,1)
    ll.new(n1.outputs['Fac'], cr.inputs['Fac'])
    n3 = nn.new('ShaderNodeTexNoise'); n3.inputs['Scale'].default_value=1.0/max(mic_m*2.0,0.5)
    n3.inputs['Detail'].default_value=6.0
    ll.new(tc.outputs['Object'], n3.inputs['Vector'])
    mo = nn.new('ShaderNodeMixRGB'); mo.blend_type='MULTIPLY'
    mo.inputs[0].default_value=0.35
    ll.new(cr.outputs['Color'], mo.inputs[1])
    ll.new(n3.outputs['Color'], mo.inputs[2])
    ll.new(mo.outputs['Color'], b.inputs['Base Color'])
    # ---- relief: macro undulation + micro grain ----
    nb1 = nn.new('ShaderNodeTexNoise'); nb1.inputs['Scale'].default_value=1.0/max(mac_m*0.5,1.0)
    nb1.inputs['Detail'].default_value=8.0
    ll.new(tc.outputs['Object'], nb1.inputs['Vector'])
    bp1 = nn.new('ShaderNodeBump'); bp1.inputs['Strength'].default_value=bstr
    bp1.inputs['Distance'].default_value=2.0
    ll.new(nb1.outputs['Fac'], bp1.inputs['Height'])
    nb2 = nn.new('ShaderNodeTexNoise'); nb2.inputs['Scale'].default_value=1.0/mic_m
    nb2.inputs['Detail'].default_value=10.0
    ll.new(tc.outputs['Object'], nb2.inputs['Vector'])
    bp2 = nn.new('ShaderNodeBump'); bp2.inputs['Strength'].default_value=bstr*0.8
    bp2.inputs['Distance'].default_value=0.4
    ll.new(nb2.outputs['Fac'], bp2.inputs['Height'])
    ll.new(bp1.outputs['Normal'], bp2.inputs['Normal'])
    ll.new(bp2.outputs['Normal'], b.inputs['Normal'])
    return m

# ---------- terrain materials by height+slope (per-face, reliable) ----------
#                            colA                 colB              rough mac  mic  bump
t_sand  = ground_mat("T_Sand", (0.370,0.315,0.200),(0.300,0.250,0.150), 0.92, 28, 1.2, 0.25)
t_grass = ground_mat("T_Grass",(0.072,0.135,0.048),(0.140,0.175,0.078), 0.93, 22, 1.6, 0.55)
t_dry   = ground_mat("T_Dry",  (0.175,0.165,0.094),(0.110,0.125,0.068), 0.93, 24, 1.8, 0.50)
t_rock  = ground_mat("T_Rock", (0.160,0.142,0.122),(0.092,0.086,0.080), 0.88, 18, 0.8, 0.85)
for mm in (t_sand,t_grass,t_dry,t_rock): terr.data.materials.append(mm)
_relief = max(zmax - SEA, 1e-3)
for p in me.polygons:
    zc = p.center.z; nz = p.normal.z
    h = (zc - SEA)/_relief
    if nz < 0.48:                 idx = 3   # steep cliffs -> rock
    elif zc < SEA + 4.0:          idx = 0   # beach band
    elif h < 0.70:                idx = 1   # forest grass (dominant)
    elif h < 0.90:                idx = 2   # dry highland
    else:                         idx = 3   # bare peaks
    p.material_index = idx

# ---------- sea ----------
bpy.ops.mesh.primitive_plane_add(size=TERR_SIZE*3, location=(0,0,SEA))
sea = bpy.context.object; sea.name="Sea"
sm,sn,sll = new_mat("SeaMat"); sb=sn['Principled BSDF']
sb.inputs['Base Color'].default_value=(0.025,0.140,0.195,1)
sb.inputs['Roughness'].default_value=0.45
if 'Specular IOR Level' in sb.inputs: sb.inputs['Specular IOR Level'].default_value=0.25
swv = sn.new('ShaderNodeTexWave'); swv.inputs['Scale'].default_value=14
sbp = sn.new('ShaderNodeBump'); sbp.inputs['Strength'].default_value=0.05
sll.new(swv.outputs['Fac'], sbp.inputs['Height'])
sll.new(sbp.outputs['Normal'], sb.inputs['Normal'])
sea.data.materials.append(sm)

# ---------- assets ----------
def foliage_mat(name, cd, cl, rough=0.78):
    """Per-instance colour variation via Object Info random -> two-tone mix."""
    m, nn, ll = new_mat(name); b = nn['Principled BSDF']
    b.inputs['Roughness'].default_value = rough
    oi = nn.new('ShaderNodeObjectInfo')
    mx = nn.new('ShaderNodeMixRGB'); mx.inputs['Color1'].default_value=(*cd,1)
    mx.inputs['Color2'].default_value=(*cl,1)
    ll.new(oi.outputs['Random'], mx.inputs['Fac'])
    ll.new(mx.outputs['Color'], b.inputs['Base Color'])
    return m

bark   = simple("Bark",(0.135,0.085,0.045))
pinef  = foliage_mat("Pine", (0.045,0.115,0.045),(0.090,0.175,0.075))
broadf = foliage_mat("Broad",(0.090,0.190,0.070),(0.165,0.260,0.105))
bushm  = foliage_mat("BushM",(0.080,0.150,0.060),(0.140,0.210,0.090))
rockm  = foliage_mat("RockM",(0.190,0.175,0.155),(0.300,0.285,0.255), 0.9)
woodm  = simple("WoodM",(0.32,0.21,0.11))
roofm  = simple("RoofM",(0.26,0.09,0.06))
wallm  = simple("WallM",(0.58,0.52,0.42))
darkm  = simple("Dark",(0.01,0.01,0.01),1.0)
trashc = [simple(f"T{i}",c) for i,c in enumerate(
          [(0.45,0.40,0.10),(0.13,0.27,0.42),(0.38,0.38,0.38),(0.50,0.18,0.13)])]

def obj_from_bm(name, bm, mats):
    md = bpy.data.meshes.new(name); bm.to_mesh(md); bm.free()
    o = bpy.data.objects.new(name, md)
    for mm in mats: o.data.materials.append(mm)
    return o

def _jit(verts, rxy, rz):
    for v in verts:
        v.co.x+=random.uniform(-rxy,rxy); v.co.y+=random.uniform(-rxy,rxy)
        v.co.z+=random.uniform(-rz,rz)

def make_pine():
    bm=bmesh.new()
    c=bmesh.ops.create_cone(bm,cap_ends=True,segments=6,radius1=0.20,radius2=0.14,depth=4.4)
    for v in c['verts']: v.co.z+=2.2
    tilt=random.uniform(-0.05,0.05)
    for r,h,z in [(2.5,3.0,2.6),(2.05,3.0,4.0),(1.6,2.9,5.5),(1.12,2.7,7.0),(0.6,2.4,8.6)]:
        cc=bmesh.ops.create_cone(bm,cap_ends=True,segments=10,radius1=r,radius2=0.0,depth=h)
        for v in cc['verts']:
            v.co.z+=z; v.co.x+=tilt*z
            ang=math.atan2(v.co.y,v.co.x); rr=math.hypot(v.co.x,v.co.y)
            if rr>0.05:
                rr*=random.uniform(0.78,1.18)
                v.co.x=math.cos(ang)*rr; v.co.y=math.sin(ang)*rr
    o=obj_from_bm("Pine",bm,[bark,pinef])
    for p in o.data.polygons:
        p.material_index = 0 if p.center.z<2.3 else 1
        p.use_smooth = p.material_index==1
    return o

def make_broad():
    bm=bmesh.new()
    c=bmesh.ops.create_cone(bm,cap_ends=True,segments=6,radius1=0.28,radius2=0.18,depth=4.8)
    for v in c['verts']: v.co.z+=2.4
    for cx,cy,cz,rad in [(0,0,5.9,2.7),(1.5,0.4,5.2,1.8),(-1.3,0.6,5.4,1.7),
                         (0.3,-1.4,5.3,1.6),(0.2,0.3,7.0,1.7)]:
        ic=bmesh.ops.create_icosphere(bm,subdivisions=2,radius=rad)
        for v in ic['verts']:
            v.co.x=v.co.x*1.1+cx; v.co.y=v.co.y*1.1+cy; v.co.z=v.co.z*0.92+cz
        _jit(ic['verts'],0.45,0.35)
    o=obj_from_bm("Broad",bm,[bark,broadf])
    for p in o.data.polygons:
        p.material_index = 0 if p.center.z<4.2 else 1
        p.use_smooth = p.material_index==1
    return o

def make_bush():
    bm=bmesh.new()
    for cx,cy,rad in [(0,0,1.1),(0.7,0.3,0.8),(-0.6,0.4,0.75),(0.2,-0.7,0.7)]:
        ic=bmesh.ops.create_icosphere(bm,subdivisions=2,radius=rad)
        for v in ic['verts']:
            v.co.x+=cx; v.co.y+=cy; v.co.z=v.co.z*0.6+0.55
        _jit(ic['verts'],0.22,0.18)
    o=obj_from_bm("Bush",bm,[bushm])
    for p in o.data.polygons: p.use_smooth=True
    return o

def make_rock():
    bm=bmesh.new()
    ic=bmesh.ops.create_icosphere(bm,subdivisions=2,radius=1.0)
    for v in ic['verts']:
        v.co+=Vector((random.uniform(-.25,.25) for _ in range(3))); v.co.z*=0.65
    return obj_from_bm("Rock",bm,[rockm])

def make_logpile():
    bm=bmesh.new()
    for i in range(6):
        cc=bmesh.ops.create_cone(bm,cap_ends=True,segments=8,radius1=0.26,radius2=0.26,depth=2.8)
        r,cl=divmod(i,3)
        for v in cc['verts']:
            o=v.co.copy(); v.co.x,v.co.z=o.z,o.x
            v.co.y+=cl*0.56-0.6; v.co.z+=0.28+r*0.5
    return obj_from_bm("LogPile",bm,[woodm])

def make_building(w,dp,h,rh,wall,roof):
    bm=bmesh.new(); bmesh.ops.create_cube(bm,size=1.0)
    for v in bm.verts: v.co.x*=w; v.co.y*=dp; v.co.z=(v.co.z+0.5)*h
    o1=obj_from_bm("Walls",bm,[wall])
    bm2=bmesh.new()
    P=[(-w/2,-dp/2,h),(w/2,-dp/2,h),(w/2,dp/2,h),(-w/2,dp/2,h),(0,-dp/2,h+rh),(0,dp/2,h+rh)]
    vs=[bm2.verts.new(p) for p in P]
    bm2.faces.new((vs[0],vs[1],vs[4])); bm2.faces.new((vs[3],vs[5],vs[2]))
    bm2.faces.new((vs[0],vs[4],vs[5],vs[3])); bm2.faces.new((vs[1],vs[2],vs[5],vs[4]))
    o2=obj_from_bm("Roof",bm2,[roof])
    return o1,o2

# ---------- terrain face cache ----------
faces=[(p.center.copy(), p.normal.z) for p in me.polygons]
def ground_z(x,y):
    return min(faces,key=lambda f:(f[0].x-x)**2+(f[0].y-y)**2)[0].z

# clustered scatter using value-noise probability
def clustered(count, zlo, zhi, min_nz, nscale, thresh, jitter):
    pool=[]
    for c,nz in faces:
        if zlo<=c.z<=zhi and nz>=min_nz:
            v=bnoise.noise(Vector((c.x*nscale, c.y*nscale, 0.0)))*0.5+0.5
            if v>thresh:
                pool.append(c)
    random.shuffle(pool)
    out=[]
    for c in pool[:count]:
        out.append(Vector((c.x+random.uniform(-jitter,jitter),
                            c.y+random.uniform(-jitter,jitter), c.z)))
    return out

def scatter(proto, pts, smin, smax, sink):
    for p in pts:
        o=bpy.data.objects.new(proto.name, proto.data)
        s=random.uniform(smin,smax)
        o.scale=(s,s,s*random.uniform(0.9,1.2))
        o.location=(p.x,p.y,p.z-sink)
        o.rotation_euler=(0,0,random.uniform(0,6.283))
        sc.collection.objects.link(o)

log("assets")
P_pine,P_broad,P_bush=make_pine(),make_broad(),make_bush()
P_rock,P_log=make_rock(),make_logpile()
for pr in (P_pine,P_broad,P_bush,P_rock,P_log):
    pr.hide_render=True; pr.hide_viewport=True

mul = 0.4 if PREVIEW else 1.0
log("scatter")
scatter(P_pine,  clustered(int(3200*mul), SEA+0.5, SEA+(zmax-SEA)*0.78, 0.80, 0.012, 0.42, 1.2), 0.8,1.7, 0.4)
scatter(P_broad, clustered(int(2000*mul), SEA+0.4, SEA+(zmax-SEA)*0.45, 0.86, 0.020, 0.55, 1.2), 0.8,1.5, 0.4)
scatter(P_bush,  clustered(int(2600*mul), SEA+0.3, SEA+(zmax-SEA)*0.70, 0.80, 0.030, 0.40, 0.8), 0.6,1.5, 0.15)
scatter(P_rock,  clustered(int(1100*mul), SEA-1.0, zmax, 0.0, 0.05, 0.35, 1.0), 0.5,3.0, 0.5)
scatter(P_log,   clustered(12, SEA+1, SEA+(zmax-SEA)*0.4, 0.93, 0.05, 0.0, 0.5), 0.9,1.2, 0.2)

# ---------- structures ----------
flat=sorted([f for f in faces if SEA+1.0<f[0].z<SEA+(zmax-SEA)*0.35 and f[1]>0.985],
            key=lambda f:f[0].z)
if flat:
    b=flat[len(flat)//3][0]
    w,r=make_building(5.0,4.2,3.2,1.8,woodm,roofm)
    for o in (w,r): o.location=(b.x,b.y,ground_z(b.x,b.y)); o.rotation_euler=(0,0,0.5); sc.collection.objects.link(o)
    CABIN=Vector((b.x,b.y,ground_z(b.x,b.y)))
    hb=flat[len(flat)//2][0]
    for i in range(6):
        a=i*1.05; ox,oy=math.cos(a)*11,math.sin(a)*11
        ww,rr=make_building(6.0,5.0,3.6,2.0,wallm,roofm)
        gz=ground_z(hb.x+ox,hb.y+oy)
        for o in (ww,rr): o.location=(hb.x+ox,hb.y+oy,gz); o.rotation_euler=(0,0,a); sc.collection.objects.link(o)
else:
    CABIN=Vector((0,0,SEA+5))

# garbage dump
dp=clustered(80, SEA+0.5, SEA+(zmax-SEA)*0.3, 0.9, 0.05, 0.0, 0.0)[:80]
if dp:
    cx=sum(p.x for p in dp)/len(dp); cy=sum(p.y for p in dp)/len(dp)
    for p in sorted(dp,key=lambda q:(q.x-cx)**2+(q.y-cy)**2)[:60]:
        bm=bmesh.new(); bmesh.ops.create_cube(bm,size=random.uniform(0.4,1.0))
        o=obj_from_bm("Trash",bm,[random.choice(trashc)])
        o.location=(p.x,p.y,p.z+0.15); o.rotation_euler=tuple(random.uniform(0,3.14) for _ in range(3))
        sc.collection.objects.link(o)

# cave entrance
steep=[f for f in faces if f[1]<0.55 and f[0].z>SEA+6]
if steep:
    cp=steep[len(steep)//2][0]
    bm=bmesh.new()
    cc=bmesh.ops.create_cone(bm,cap_ends=True,segments=14,radius1=3.4,radius2=2.6,depth=5.0)
    cv=obj_from_bm("Cave",bm,[darkm])
    cv.location=(cp.x,cp.y,cp.z+2.2); cv.rotation_euler=(1.5707,0,random.uniform(0,6.28))
    sc.collection.objects.link(cv)
log("scene built")

# ---------- world + sun ----------
wr=bpy.data.worlds.new("W"); sc.world=wr; wr.use_nodes=True
wn=wr.node_tree.nodes; wl=wr.node_tree.links
for nd in list(wn):
    if nd.type!='OUTPUT_WORLD': wn.remove(nd)
wo=wn['World Output']
sky=wn.new('ShaderNodeTexSky'); sky.sky_type='NISHITA'
sky.sun_elevation=math.radians(28); sky.sun_rotation=math.radians(125)
sky.air_density=1.2; sky.dust_density=1.5
bg=wn.new('ShaderNodeBackground'); bg.inputs['Strength'].default_value=0.55
wl.new(sky.outputs['Color'],bg.inputs['Color']); wl.new(bg.outputs['Background'],wo.inputs['Surface'])
sd=bpy.data.lights.new("Sun",'SUN'); sd.energy=2.3; sd.angle=math.radians(2.0)
sd.color=(1.0,0.95,0.85)
su=bpy.data.objects.new("Sun",sd)
su.rotation_euler=(math.radians(62),0,math.radians(-125+90))
sc.collection.objects.link(su)

# ---------- render settings ----------
sc.render.engine='CYCLES'; sc.cycles.device='CPU'
sc.cycles.samples = 28 if PREVIEW else 64
sc.cycles.use_denoising=True
try: sc.cycles.denoiser='OPENIMAGEDENOISE'
except Exception: pass
sc.cycles.max_bounces=4
sc.cycles.caustics_reflective=False; sc.cycles.caustics_refractive=False
sc.render.resolution_x = 960 if PREVIEW else 1600
sc.render.resolution_y = 540 if PREVIEW else 900
sc.view_settings.view_transform='Filmic'
sc.view_settings.exposure=-0.25
sc.view_settings.look='High Contrast'

# ---------- atmosphere: depth haze (compositor mist) ----------
wr.mist_settings.start=TERR_SIZE*0.6
wr.mist_settings.depth=TERR_SIZE*4.5
wr.mist_settings.falloff='LINEAR'
vlyr=bpy.context.view_layer; vlyr.use_pass_mist=True
sc.use_nodes=True
ct=sc.node_tree
for nd in list(ct.nodes): ct.nodes.remove(nd)
rl=ct.nodes.new('CompositorNodeRLayers')
mm=ct.nodes.new('CompositorNodeMath'); mm.operation='MULTIPLY'
mm.inputs[1].default_value=0.22; mm.use_clamp=True   # keep haze a gentle tint
mh=ct.nodes.new('CompositorNodeMixRGB')
mh.inputs[2].default_value=(0.70,0.77,0.83,1.0)   # pale atmospheric haze
cm=ct.nodes.new('CompositorNodeComposite')
ct.links.new(rl.outputs['Mist'],  mm.inputs[0])
ct.links.new(rl.outputs['Image'], mh.inputs[1])
ct.links.new(mm.outputs['Value'], mh.inputs[0])
ct.links.new(mh.outputs['Image'], cm.inputs['Image'])

def cam(name,loc,tgt,lens=38,ortho=0.0):
    cd=bpy.data.cameras.new(name)
    cd.clip_start=0.5; cd.clip_end=60000.0
    if ortho>0:
        cd.type='ORTHO'; cd.ortho_scale=ortho
    else:
        cd.lens=lens
    co=bpy.data.objects.new(name,cd); co.location=loc
    dr=(Vector(tgt)-Vector(loc)).normalized()
    co.rotation_euler=dr.to_track_quat('-Z','Y').to_euler()
    sc.collection.objects.link(co); return co

S=TERR_SIZE
# ---- pick 10 interesting locations from real terrain features ----
def _pick(cond, key, rev=True):
    cand=[c for c,nz in faces if cond(c,nz)]
    if not cand: return Vector((0,0,SEA+5))
    return sorted(cand,key=key,reverse=rev)[0]

PEAK   = _pick(lambda c,nz: True, lambda c:c.z)                       # highest point
VALLEY = _pick(lambda c,nz: c.z>SEA+4 and abs(c.x)<S*0.35 and abs(c.y)<S*0.35,
               lambda c:-c.z)                                         # deep interior basin
RIDGE  = _pick(lambda c,nz: c.z>SEA+(zmax-SEA)*0.55 and nz<0.55,
               lambda c:c.z)                                          # steep high ridge
BAY    = _pick(lambda c,nz: abs(c.z-SEA)<3.0,
               lambda c:-(c.x*c.x+c.y*c.y))                           # coastline cove
def gz(p): return ground_z(p.x,p.y)
def look_cam(name,tgt,ang,dist,height,lens=40,tz=4.0):
    import math as _m
    lx=tgt.x+_m.cos(ang)*dist; ly=tgt.y+_m.sin(ang)*dist
    lz=gz(Vector((lx,ly,0)))+height
    return (name,(lx,ly,lz),(tgt.x,tgt.y,tgt.z+tz),lens,0)

# tuple: (name, loc, target, lens, ortho_scale)
TOPDOWN=("00_topdown",(0,0,zmax+900),(0,0,SEA),0,S*1.05)
AERIAL =("01_aerial",(-S*0.9,-S*0.9, zmax+S*0.7),(0,0,SEA),0,S*1.62)
if PREVIEW:
    CAMS=[TOPDOWN,AERIAL,
     ("09_ground",(CABIN.x-26,CABIN.y-26,CABIN.z+3.0),
                  (CABIN.x+40,CABIN.y+34,CABIN.z+7.0),30,0)]
else:
    CAMS=[
     TOPDOWN,
     AERIAL,
     look_cam("02_peak",   PEAK,   2.3, 230, 70, 46, 0.0),
     look_cam("03_valley", VALLEY, 0.7, 150, 32, 38, 6.0),
     look_cam("04_ridge",  RIDGE,  3.7, 180, 55, 44, 2.0),
     look_cam("05_bay",    BAY,    1.2, 170, 26, 50, 3.0),
     look_cam("06_cabin",  CABIN,  3.9,  34, 12, 34, 2.0),
     look_cam("07_forest", CABIN,  0.6,  90, 24, 30, 8.0),
     look_cam("08_cave",   Vector((cp.x,cp.y,cp.z)) if steep else CABIN,
                                   2.0,  46, 16, 40, 2.0),
     ("09_dump", (cx-40,cy-40, gz(Vector((cx-40,cy-40,0)))+18),
                 (cx,cy, (gz(Vector((cx,cy,0)))+SEA)*0.5+3), 38,0)
        if dp else look_cam("09_overlook", PEAK, 5.5, 320, 120, 50, 0.0),
    ]
os.makedirs(OUT,exist_ok=True)
if not PREVIEW:
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT,"map.blend"))
RX = 960 if PREVIEW else 1600
RY = 540 if PREVIEW else 900
SQ = 900 if PREVIEW else 1500          # square frame for top-down whole-map
for nm,loc,tgt,lens,orth in CAMS:
    co=cam(nm,loc,tgt,lens,orth); sc.camera=co
    if nm=="00_topdown":
        sc.render.resolution_x=SQ; sc.render.resolution_y=SQ
    else:
        sc.render.resolution_x=RX; sc.render.resolution_y=RY
    sc.render.filepath=os.path.join(OUT,f"render_{nm}.png")
    log(f"rendering {nm}")
    bpy.ops.render.render(write_still=True)
    log(f"done {nm} size={os.path.getsize(sc.render.filepath)}")

if not PREVIEW:
    # export the PROCESSED heightmap so Godot builds an identical terrain
    # with its own chunk/LOD system (no giant baked mesh -> mobile friendly)
    import json
    hf=hm.astype('<f4')                       # (H,W) float32 0..1, post slope_relax
    hf.tofile(os.path.join(OUT,"height.f32"))
    meta=dict(w=int(hm.shape[1]), h=int(hm.shape[0]),
              world_size=float(TERR_SIZE), relief=float(RELIEF),
              sea=float(SEA), zmin=float(zmin), zmax=float(zmax))
    with open(os.path.join(OUT,"terrain.json"),"w") as fp: json.dump(meta,fp)
    log(f"HEIGHT exported {hm.shape} meta={meta}")
log("ALL DONE")
