#!/usr/bin/env python3
"""Generate review-only Lang from explicit mock input; never edits SDK Sources."""
from pathlib import Path
import json,re
ROOT = Path(__file__).resolve().parent
PROGRAMS = ROOT.parent / 'Programs'
for language in ('zh', 'en'):
    data = json.loads((ROOT / f'paris-input.{language}.json').read_text())
    def t(zh, en): return json.dumps(zh if language == 'zh' else en, ensure_ascii=False)
    def place(i):
        p=f'input.places[{i}]'
        return f'''Stack([
  Image({p}.name,{p}.image),
  Stack([TextContent({p}.name,"small-heavy"),TagBlock({p}.tags,"sm"),TextContent({p}.description,"small"),
    Stack([BoldText("number",currency+({p}.unitPrice*trip.adults),null,"text","lg"),
      Buttons([Button({p}.booking?{t('订','Book')}:{t('详情','Details')},@OpenUrl({p}.url),"primary",null,"small")])],"row","s","center","between",false)
  ],"column","s","stretch","between",false)
],"row","m","stretch","start",false)'''
    def flights(group):
        return f'''CompositeCardBlock(@Each({group}.options,"f",CompositeCardItem(f.id,
  Stack([Icon("plane"),TextContent(f.carrier,"small-heavy"),TextContent({group}.route,"small")],"row","s","center","start",false),[
    Stack([
      Stack([TextContent(f.departure,"large-heavy"),TextContent({group}.origin,"small")],"column","xs"),
      Stack([TextContent(f.duration,"small"),TextContent(f.stops,"small-heavy")],"column","xs","center"),
      Stack([TextContent(f.arrival,"large-heavy"),TextContent({group}.destination,"small")],"column","xs")
    ],"row","s","center","between",false),
    TextContent(f.detail,"small")
  ],{{price:BoldText("number",currency+f.price,null,"text","lg"),button:Button({t('订','Book')},@OpenUrl(f.url),"primary",null,"small")}}
)),"carousel",true)'''
    source=f'''root=Stack([heading,overview,itinerary,placesMap,transport,stays,budget,closing],"column","l")
heading=Stack([TextContent(headline,"large-heavy"),TextContent({t('11 月 5–6 日 · 两位成人','5–6 November 2026 · two adults')},"small")],"column","s")
headline={t('巴黎，两天一晚','Paris, two days and one night')}
input={json.dumps(data,ensure_ascii=False,separators=(',',':'))}
trip=input.trip
currency=trip.currency
$day="day1"
outboundGroup=input.flightGroups[0]
returnGroup=input.flightGroups[1]
recommendedOutbound=input.flightGroups[0].options[0]
recommendedReturn=input.flightGroups[1].options[0]
recommendedStay=input.stays[0]
flightCost=recommendedOutbound.price+recommendedReturn.price
stayCost=recommendedStay.pricePerRoomNight*trip.rooms*trip.nights
visitCost=(input.places[0].unitPrice+input.places[1].unitPrice+input.places[2].unitPrice+input.places[3].unitPrice)*trip.adults
total=flightCost+stayCost+visitCost+input.budgetAssumptions.food+input.budgetAssumptions.localTransport+input.budgetAssumptions.buffer
overview=Stack([
 OverviewCardItem("people",IconText(Icon("users"),"neutral","m",trip.adults+{t(' 人',' people')},null,true,"vertical")),
 OverviewCardItem("days",IconText(Icon("calendar-days"),"neutral","m",trip.days+{t(' 天',' days')},null,true,"vertical")),
 OverviewCardItem("nights",IconText(Icon("moon"),"neutral","m",trip.nights+{t(' 晚',' night')},null,true,"vertical"))
],"row","s","stretch","start",false)
itinerary=Stack([InlineHeader({t('两天这样走','Your two days')}),Buttons([
 Button({t('第一天 · 左岸','Day 1 · Art')},@Set($day,"day1"),$day=="day1"?"primary":"secondary",null,"small"),
 Button({t('第二天 · 塞纳','Day 2 · Seine')},@Set($day,"day2"),$day=="day2"?"primary":"secondary",null,"small")
]),$day=="day1"?Stack([
 TextContent({t('上午抵达后寄存行李。下午看卢浮宫，傍晚穿过塞纳河去左岸。','Leave bags after arrival. Visit the Louvre in the afternoon, then cross the Seine to the Left Bank.')},"small"),
 {place(0)},Separator(),{place(1)},Separator(),
 ListBlock([ListItem(input.places[4].name,input.places[4].description,{{src:input.places[4].image,alt:input.places[4].name}})],"image")
],"column","m"):Stack([
 {place(2)},Separator(),{place(3)},
 TextContent({t('午餐后取行李，计划 15:00 离开市区；为推荐的 18:30 航班留出接驳和安检时间。','Collect bags after lunch and plan to leave the city at 15:00, allowing time for the recommended 18:30 flight.')},"small")
],"column","m")],"column","m")
placesMap=Stack([InlineHeader({t('都在这张地图上','Your places, on one map')}),Map(@Each(input.places,"p",{{id:p.id,title:p.name,lat:p.lat,lng:p.lng,imageSrc:p.image,subtitle:p.description,url:p.url,icon:p.icon}}),input.routes,null,"regular","wgs84")],"column","m")
transport=Stack([
 InlineHeader({t('往返航班','Flights, each way')}),
 TextContent({t('去程选早班直飞，返程留出傍晚时间；票价按两位成人单程计算，时间均为当地时间。','An early nonstop out and an evening return leave more time in Paris. Each price covers two adults on one leg; times are local.')},"small"),
 InlineHeader(outboundGroup.title,outboundGroup.route),
 {flights('outboundGroup')},
 InlineHeader(returnGroup.title,returnGroup.route),
 {flights('returnGroup')}
],"column","m")
stays=Stack([InlineHeader({t('住一晚，选一处落脚点','A place to stay')}),CompositeCardBlock(@Each(input.stays,"h",CompositeCardItem(h.id,ImageTextLarge(h.image,h.name,h.name,null,true),[
 TagBlock(h.tags,"sm"),Text("text",h.description)
 ],{{price:BoldText("number",currency+(h.pricePerRoomNight*trip.rooms*trip.nights),null,"text","lg"),button:Button({t('订','Book')},@OpenUrl(h.url),"primary",null,"small")}})),"carousel",true)],"column","m")
budget=Stack([InlineHeader({t('推荐方案预算','Recommended plan budget')}),BoldText("number",currency+total,trip.adults+{t(' 人合计 · 含余量',' people · including buffer')},"text","lg"),PieChart([
 {t('机票','Flights')},{t('住宿','Stay')},{t('餐饮','Food')},{t('接驳与交通','Transport')},{t('门票','Tickets')},{t('余量','Buffer')}
 ],[flightCost,stayCost,input.budgetAssumptions.food,input.budgetAssumptions.localTransport,visitCost,input.budgetAssumptions.buffer],"donut")],"column","m")
closing=TextContent({t('先确认去返航班与房间库存，再预约卢浮宫时段；餐饮与市内交通留有预算余量。','Confirm both flights and the room before reserving the Louvre time slot. Food and local transport retain a small buffer.')},"small-heavy")
'''
    # Keep each authored assignment in one transport line. Incremental review
    # playback can then append complete records rather than partial JSON or
    # half of a deeply nested card expression.
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

    if language == 'en':
        changed = json.loads(json.dumps(data))
        changed['stays'][0]['pricePerRoomNight'] = 275
        changed['places'][0]['description'] = 'Updated source record description'
        changed_source = source.replace(json.dumps(data,ensure_ascii=False,separators=(',',':')), json.dumps(changed,ensure_ascii=False,separators=(',',':')), 1)
        (PROGRAMS/'paris-fewshot-source-change.openui').write_text(changed_source)
