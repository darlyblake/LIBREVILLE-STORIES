#!/usr/bin/env python3
"""Conservative OSM road surface and topology audit for LIBREVILLE STORIES."""
from __future__ import annotations
import json, math
from collections import Counter, defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
INPUT = ROOT / "data/osm/extended/roads.geojson"
OUTPUT = ROOT / "data/analysis/road_surface_audit.json"
LATITUDE_REFERENCE = 0.400
METERS_PER_DEGREE = 111320.0
COS_LAT = math.cos(math.radians(LATITUDE_REFERENCE))
CELL = 20.0
UNPAVED = {"unpaved","ground","dirt","earth","compacted","gravel","fine_gravel","pebblestone","sand","mud","grass","woodchips"}
POOR = {"bad","very_bad","horrible","very_horrible","impassable"}
PAVED = {"asphalt","paved","concrete","concrete:lanes","concrete:plates","paving_stones","sett","cobblestone","paved_stones"}

def lines(geometry):
    kind=geometry.get("type")
    if kind=="LineString": return [geometry.get("coordinates",[])]
    if kind=="MultiLineString": return geometry.get("coordinates",[])
    return []

def xy(coord):
    return (float(coord[0])*METERS_PER_DEGREE*COS_LAT, float(coord[1])*METERS_PER_DEGREE)

def length_m(geometry):
    return sum(math.dist(xy(a),xy(b)) for line in lines(geometry) for a,b in zip(line,line[1:]))

def classify(props):
    surface=str(props.get("surface","")).strip().lower()
    smooth=str(props.get("smoothness","")).strip().lower()
    track=str(props.get("tracktype","")).strip().lower()
    if surface in UNPAVED or track in {"grade2","grade3","grade4","grade5"}: return "unpaved"
    if surface in PAVED and smooth in POOR: return "damaged_paved" if surface in {"asphalt","paved"} else "poor_smoothness_tagged"
    if smooth in POOR and surface in {"","asphalt","paved"}: return "damaged_paved"
    if surface in PAVED: return "paved_tagged"
    if surface: return "other_surface_tagged"
    return "surface_unknown"

def level(props):
    return (str(props.get("layer","0")),str(props.get("bridge","no")),str(props.get("tunnel","no")))

def point_segment_distance(p,a,b):
    vx,vy=b[0]-a[0],b[1]-a[1]
    denom=vx*vx+vy*vy
    if denom<1e-9: return math.dist(p,a),0.0
    t=max(0.0,min(1.0,((p[0]-a[0])*vx+(p[1]-a[1])*vy)/denom))
    q=(a[0]+t*vx,a[1]+t*vy)
    return math.dist(p,q),t

def audit_topology(features):
    endpoints=[]; segments=[]; bounds=[float("inf"),float("inf"),-float("inf"),-float("inf")]
    for fi,feature in enumerate(features):
        props=feature.get("properties") or {}
        if not props.get("highway"): continue
        for li,line in enumerate(lines(feature.get("geometry") or {})):
            if len(line)<2: continue
            pts=[xy(c) for c in line]
            for x,y in pts:
                bounds[0]=min(bounds[0],x);bounds[1]=min(bounds[1],y);bounds[2]=max(bounds[2],x);bounds[3]=max(bounds[3],y)
            total=sum(math.dist(a,b) for a,b in zip(pts,pts[1:]))
            for side,coord in (("start",pts[0]),("end",pts[-1])):
                endpoints.append({"feature":fi,"line":li,"side":side,"p":coord,"props":props,"length":total})
            for si,(a,b) in enumerate(zip(pts,pts[1:])):
                segments.append({"feature":fi,"line":li,"a":a,"b":b,"props":props})
    grid=defaultdict(list)
    for si,seg in enumerate(segments):
        a,b=seg["a"],seg["b"]
        for gx in range(math.floor(min(a[0],b[0])/CELL),math.floor(max(a[0],b[0])/CELL)+1):
            for gy in range(math.floor(min(a[1],b[1])/CELL),math.floor(max(a[1],b[1])/CELL)+1):
                grid[(gx,gy)].append(si)
    exact=Counter()
    for ep in endpoints: exact[(round(ep["p"][0],2),round(ep["p"][1],2))]+=1
    near_pairs=[]; t_candidates=[]; dangling=[]; boundary=[]; isolated=[]
    for i,ep in enumerate(endpoints):
        p=ep["p"]; gx,gy=math.floor(p[0]/CELL),math.floor(p[1]/CELL)
        candidates=set()
        for ox in (-1,0,1):
            for oy in (-1,0,1): candidates.update(grid[(gx+ox,gy+oy)])
        best=None
        for si in candidates:
            seg=segments[si]
            if seg["feature"]==ep["feature"] or level(seg["props"])!=level(ep["props"]): continue
            dist,t=point_segment_distance(p,seg["a"],seg["b"])
            if 0.05<t<0.95 and dist<=3.0:
                candidate={"endpoint_osm_id":ep["props"].get("osm_id",ep["feature"]),"road_osm_id":seg["props"].get("osm_id",seg["feature"]),"distance_m":round(dist,2),"endpoint_side":ep["side"]}
                if best is None or dist<best[0]: best=(dist,candidate)
        if best: t_candidates.append(best[1])
        # Nearby endpoints, without joining different bridge/tunnel/layer levels.
        for j in range(i+1,len(endpoints)):
            other=endpoints[j]
            if other["feature"]==ep["feature"] or level(other["props"])!=level(ep["props"]): continue
            d=math.dist(p,other["p"])
            if 0.05<d<=1.5:
                near_pairs.append({"road_a":ep["props"].get("osm_id",ep["feature"]),"road_b":other["props"].get("osm_id",other["feature"]),"distance_m":round(d,2),"level":level(ep["props"])})
        edge=min(p[0]-bounds[0],bounds[2]-p[0],p[1]-bounds[1],bounds[3]-p[1])
        if edge<=50.0: boundary.append(ep)
        elif exact[(round(p[0],2),round(p[1],2))]==1 and not best:
            dangling.append({"osm_id":ep["props"].get("osm_id",ep["feature"]),"name":ep["props"].get("name",""),"highway":ep["props"].get("highway",""),"side":ep["side"],"length_m":round(ep["length"],1),"level":level(ep["props])"})
    # Short isolated features are review candidates, not assumed geometry errors.
    dangling_by_feature=Counter(str(x["osm_id"]) for x in dangling)
    for feature in features:
        props=feature.get("properties") or {}
        if not props.get("highway"): continue
        ln=length_m(feature.get("geometry") or {})
        key=str(props.get("osm_id",feature.get("id","")))
        if ln<35 and dangling_by_feature[key]>=2:
            isolated.append({"osm_id":key,"name":props.get("name",""),"highway":props.get("highway",""),"length_m":round(ln,1)})
    def clean_ep(e): return {k:v for k,v in e.items() if k!="p" and k!="props"}
    return {
      "endpoint_count":len(endpoints),"segment_count":len(segments),
      "near_endpoint_pairs_within_1_5m":len(near_pairs),"possible_t_junctions_within_3m":len(t_candidates),
      "dangling_endpoint_review_candidates":len(dangling),"perimeter_endpoints":len(boundary),
      "short_isolated_road_candidates":len(isolated),
      "examples":{"near_endpoint_pairs":near_pairs[:200],"possible_t_junctions":t_candidates[:200],
                  "dangling_endpoints":[{k:v for k,v in x.items()} for x in dangling[:200]],
                  "short_isolated_roads":isolated[:100]}
    }

def audit_features(features):
    counts=Counter(); lengths=defaultdict(float); highway_counts=defaultdict(Counter); examples=defaultdict(list)
    for feature in features:
        props=feature.get("properties") or {}
        if not props.get("highway"): continue
        cat=classify(props); ln=length_m(feature.get("geometry") or {})
        counts[cat]+=1;lengths[cat]+=ln;highway_counts[cat][str(props.get("highway","unknown"))]+=1
        if cat in {"unpaved","damaged_paved","poor_smoothness_tagged"} and len(examples[cat])<250:
            examples[cat].append({"osm_id":feature.get("id",props.get("osm_id","")),"name":props.get("name",""),
              "highway":props.get("highway",""),"surface":props.get("surface",""),"smoothness":props.get("smoothness",""),
              "tracktype":props.get("tracktype",""),"estimated_length_m":round(ln,1)})
    return {"feature_count":sum(counts.values()),"categories":{k:{"features":counts[k],
      "estimated_total_length_km":round(lengths[k]/1000,2),"highway_types":dict(highway_counts[k].most_common())}
      for k in sorted(counts)},"examples":dict(examples),"topology":audit_topology(features)}

def main():
    if not INPUT.exists(): raise SystemExit(f"OSM roads file missing: {INPUT}")
    data=json.loads(INPUT.read_text(encoding="utf-8")); report=audit_features(data.get("features",[]))
    report.update({"source":str(INPUT.relative_to(ROOT)),"method":"OSM tags and conservative endpoint/segment proximity checks; approximate local metric projection",
      "warning":"OSM surface and smoothness tags are incomplete. Dangling endpoints and short isolated roads are review candidates, not proof of broken roads. Bridge/layer/tunnel levels are never matched."})
    OUTPUT.parent.mkdir(parents=True,exist_ok=True)
    OUTPUT.write_text(json.dumps(report,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    print(f"OSM roads audited: {report['feature_count']} features")
    for key,item in report["categories"].items(): print(f"- {key}: {item['features']} features, ~{item['estimated_total_length_km']} km")
    top=report["topology"]
    for key in ("near_endpoint_pairs_within_1_5m","possible_t_junctions_within_3m","dangling_endpoint_review_candidates","perimeter_endpoints","short_isolated_road_candidates"):
        print(f"- {key}: {top[key]}")
    print(f"Detailed report: {OUTPUT}")
    return 0
if __name__=="__main__": raise SystemExit(main())
