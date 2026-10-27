#!/usr/bin/env python3
"""Generate review-only Lang from explicit mock input; never edits SDK Sources."""
from pathlib import Path
import json,re
ROOT = Path(__file__).resolve().parent
PROGRAMS = ROOT.parent / 'Programs'
for language in ('zh', 'en'):
    data = json.loads((ROOT / f'paris-input.{language}.json').read_text())
    def t(zh, en): return json.dumps(zh if language == 'zh' else en, ensure_ascii=False)
    def place(i, time):
        p=f'input.places[{i}]'
        return f'''Stack([
  Image({p}.name,{p}.image),
  Stack([TextContent({json.dumps(time,ensure_ascii=False)},"small"),BoldText("text",{p}.name,null,"text","md"),TagBlock({p}.tags,"sm"),TextContent({p}.description,"small"),
    Stack([BoldText("number",currency+({p}.unitPrice*trip.adults),null,"text","md"),
      Buttons([Button({p}.booking?{t('订','Book')}:{t('详情','Details')},@OpenUrl({p}.url),"primary",null,"small")])],"row","s","center","between",false)
  ],"column","xs","stretch","start",false)
],"row","m","stretch","start",false)'''
    def flights(group, recommended):
        return f'''CompositeCardBlock(@Each({group}.options,"f",CompositeCardItem(f.id,
  Stack([TextContent(f.carrier,"small-heavy"),TagBlock([f.id=={recommended}.id?{t('推荐','Recommended')}:{t('备选','Alternative')}],"sm")],"row","s","center","between",false),[
    Stack([
      Stack([BoldText("number",f.departure,null,"text","lg"),TextContent({group}.origin,"small")],"column","xs"),
      Stack([TextContent(f.duration,"small"),flightArrow,TextContent(f.stops,"small-heavy")],"column","xs","center"),
      Stack([BoldText("number",f.arrival,null,"text","lg"),TextContent({group}.destination,"small")],"column","xs")
    ],"row","s","center","between",false),
    TextContent(f.detail,"small")
  ],{{price:BoldText("number",currency+f.price,null,"text","md"),button:Button({t('订','Book')},@OpenUrl(f.url),"primary",null,"small")}}
)),"carousel",true)'''
    source=f'''root=Stack([heading,transport,itinerary,stays,placesMap,budget,closing],"column","l")
heading=Stack([TextContent(headline,"large-heavy"),TextContent({t('11 月 5–6 日 · 两位成人','5–6 November 2026 · two adults')},"small")],"column","s")
headline={t('巴黎，两天一晚','Paris, two days and one night')}
input={json.dumps(data,ensure_ascii=False,separators=(',',':'))}
trip=input.trip
currency=trip.currency
$view="overview"
outboundGroup=input.flightGroups[0]
returnGroup=input.flightGroups[1]
recommendedOutbound=input.flightGroups[0].options[0]
recommendedReturn=input.flightGroups[1].options[0]
recommendedStay=input.stays[0]
flightArrow=Stack([Stack([Separator()],"column","none"),Icon("move-right")],"row","none","center","start",false)
flightCost=recommendedOutbound.price+recommendedReturn.price
stayCost=recommendedStay.pricePerRoomNight*trip.rooms*trip.nights
visitCost=(input.places[0].unitPrice+input.places[1].unitPrice+input.places[2].unitPrice+input.places[3].unitPrice)*trip.adults
total=flightCost+stayCost+visitCost+input.budgetAssumptions.food+input.budgetAssumptions.localTransport+input.budgetAssumptions.buffer
transport=Stack([
 InlineHeader({t('往返航班','Flights, each way')},{t('当地时间 · 两位成人单程价','Local times · one-way fares for two')}),
 InlineHeader(outboundGroup.title,outboundGroup.route),
 {flights('outboundGroup', 'recommendedOutbound')},
 InlineHeader(returnGroup.title,returnGroup.route),
 {flights('returnGroup', 'recommendedReturn')}
],"column","m")
itinerary=Stack([InlineHeader({t('两天行程','Your two-day itinerary')}),viewSwitcher,activeView],"column","m")
viewSwitcher=Buttons([
 Button({t('总览','Overview')},@Set($view,"overview"),$view=="overview"?"primary":"secondary",null,"small"),
 Button({t('第一天','Day 1')},@Set($view,"day1"),$view=="day1"?"primary":"secondary",null,"small"),
 Button({t('第二天','Day 2')},@Set($view,"day2"),$view=="day2"?"primary":"secondary",null,"small")
],"row")
activeView=$view=="overview"?routeSummary:($view=="day1"?dayOne:dayTwo)
routeSummary=Steps([
 StepsItem({t('第一天 · 艺术与左岸','Day 1 · Art and the Left Bank')},
  recommendedOutbound.arrival+{t(' 抵达，下午参观卢浮宫，傍晚逛圣日耳曼与咖啡馆。夜宿：',' arrival, the Louvre in the afternoon, then Saint-Germain and a café. Stay: ')}+recommendedStay.name),
 StepsItem({t('第二天 · 铁塔与塞纳','Day 2 · Tower and Seine')},
  {t('上午登铁塔，午间游船；午餐后取行李，15:00 前往机场，','Tower in the morning and a midday cruise; collect bags after lunch, leave for the airport at 15:00 for the ')}+recommendedReturn.departure+{t(' 从 CDG 返程。',' return from CDG.')})
])
stays=Stack([InlineHeader({t('住宿 · 一晚','A place to stay')},{t('推荐：','Recommended: ')}+recommendedStay.name),CompositeCardBlock(@Each(input.stays,"h",CompositeCardItem(h.id,ImageTextLarge(h.image,h.name,h.name,null,true),[
 TagBlock(h.tags,"sm"),Text("text",h.description)
 ],{{price:BoldText("number",currency+(h.pricePerRoomNight*trip.rooms*trip.nights),null,"text","lg"),button:Button({t('订','Book')},@OpenUrl(h.url),"primary",null,"small")}})),"carousel",true)],"column","m")
placesMap=Stack([InlineHeader({t('行程地图','Your places, on one map')}),Map(@Each(input.places,"p",{{id:p.id,title:p.name,lat:p.lat,lng:p.lng,imageSrc:p.image,subtitle:p.description,url:p.url,icon:p.icon}}),input.routes,null,"regular","wgs84")],"column","m")
budget=Stack([InlineHeader({t('推荐方案预算','Recommended plan budget')}),BoldText("number",currency+total,trip.adults+{t(' 人合计 · 含余量',' people · including buffer')},"text","lg"),PieChart([
 {t('机票','Flights')},{t('住宿','Stay')},{t('餐饮','Food')},{t('接驳与交通','Transport')},{t('门票','Tickets')},{t('余量','Buffer')}
 ],[flightCost,stayCost,input.budgetAssumptions.food,input.budgetAssumptions.localTransport,visitCost,input.budgetAssumptions.buffer],"donut")],"column","m")
closing=TextContent({t('行程与预算按推荐航班和住宿安排。先确认机酒，再预约景点；若改选更晚抵达或更早返程的航班，需要相应缩短游览。','The schedule and budget use the recommended flights and room. Confirm those before reserving attractions; a later arrival or earlier return needs a shorter day plan.')},"small")
dayOne=Stack([
 TextContent({t('11 月 5 日 · 艺术与左岸','5 November · Art and the Left Bank')},"small"),
 TextContent(recommendedOutbound.arrival+{t(' 抵达 CDG，接驳至左岸，寄存行李后午餐。',' arrival at CDG. Transfer to the Left Bank, leave bags and have lunch.')},"small"),
 {place(0, '14:00–17:00')},
 TextContent({t('参观后步行过塞纳河，傍晚逛圣日耳曼。','After the museum, walk across the Seine for an evening in Saint-Germain.')},"small"),
 Separator(),{place(1, '17:30–18:30')},Separator(),
 Stack([TextContent({t('用餐与休息','Food & a pause')},"small-heavy"),
  ListBlock([ListItem(input.places[4].name,input.places[4].description,{{src:input.places[4].image,alt:input.places[4].name}})],"image","small")],"column","s"),
 TextContent({t('晚餐后入住：','After dinner, check in: ')}+recommendedStay.name,"small")
],"column","m")
dayTwo=Stack([
 TextContent({t('11 月 6 日 · 铁塔与塞纳','6 November · Tower and Seine')},"small"),
 TextContent({t('08:30 在住宿处退房、寄存行李，再前往铁塔。','08:30 check out, arrange bag storage and head to the tower.')},"small"),
 {place(2, '09:30–11:00')},
 TextContent({t('步行至铁塔附近的游船码头，按选定班次登船。','Walk to the cruise pier near the tower for the chosen departure.')},"small"),
 Separator(),{place(3, '11:30–12:30')},
 TextContent({t('午餐后取行李，15:00 离开市区前往 CDG，搭乘 ','After lunch, collect bags and leave for CDG at 15:00 for the ')}+recommendedReturn.departure+{t(' 航班。',' flight.')},"small")
],"column","m")
'''
    # Store one readable declaration per line. The review host feeds raw
    # bounded chunks independently of these statement boundaries.
    statements=[]
    for line in source.splitlines():
        if re.match(r'^[A-Za-z_$][A-Za-z0-9_$]*=',line): statements.append(line)
        elif statements: statements[-1]+=' '+line.strip()
    source='\n'.join(statements)+'\n'
    path=PROGRAMS/f'paris-fewshot-{language}.openui';path.write_text(source)
    expected=(data['flightGroups'][0]['options'][0]['price']+data['flightGroups'][1]['options'][0]['price']+data['stays'][0]['pricePerRoomNight']*data['trip']['rooms']*data['trip']['nights']+sum(p['unitPrice'] for p in data['places'][:4])*data['trip']['adults']+sum(data['budgetAssumptions'].values()))
    assert expected==987
    assert source.startswith('root=')
    assert not data['routes']
    (ROOT/f'paris-provenance.{language}.json').write_text(json.dumps({'kind':'authored-few-shot','input':f'paris-input.{language}.json','program':str(path.relative_to(ROOT.parent)),'expectedTotal':expected,'navigationRoutesSupplied':False,'mapPointIds':[p['id'] for p in data['places']],'recommendedRecordIds':[data['flightGroups'][0]['options'][0]['id'],data['flightGroups'][1]['options'][0]['id'],data['stays'][0]['id']],'derivations':['ticket unit price times party size','room nightly price times rooms and nights','sum selected records and explicit budget assumptions'],'excludedClaims':['live availability','route calculation','booking completion'],'usage':'Learn information roles and source-grounded composition; not a mandatory page template or a reusable source of business facts.'},ensure_ascii=False,indent=2)+'\n')
