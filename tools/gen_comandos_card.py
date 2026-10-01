# -*- coding: utf-8 -*-
import json, os
EQUIPO = [
 ("/ultimo <eq> <comp>", "Último análisis de un componente"),
 ("/condicionmt <eq>", "Condición de los MT del equipo"),
 ("/diagcompleto <eq>", "Diagnóstico del equipo: todos sus componentes"),
 ("/tendencia <eq> <comp>", "Tendencia de un componente: contexto + parámetros × fechas"),
 ("/grafica <eq> <comp> <metal>", "Tendencia y gráfica de un metal en un componente"),
 ("/historial <eq> <comp> [rango]", "Historial (bitácora) de un componente"),
 ("/historialeq <eq> [rango]", "Historial de todo el equipo"),
 ("/historialmetal <eq> <metal> [comp] [rango]", "Historial de un metal"),
 ("/acumulados <eq>", "Acumulados del motor diésel del equipo"),
]
FLOTA = [
 ("/panel <proj> [modelo]", "Panel de la flota: cuántos, qué componentes y por dónde empezar"),
 ("/barridodet <proj> [modelo]", "Barrido detalle por componente"),
 ("/triage <comp> <proj> [modelo]", "Triage: estado de un componente en la flota"),
 ("/incipiente <proj> [comp]", "Tendencia incipiente (alerta temprana)"),
 ("/ranking <proj> <comp> <metal> [modelo] [top]", "Ranking de un metal"),
 ("/metalflota <proj> <comp> <metal(es)> [modelo]", "Último de un metal en la flota"),
 ("/historialflota <proj> [rango]", "Historial de observados de la flota"),
 ("/rankingacum <proj>", "Ranking de acumulados (motor diésel)"),
 ("/rankinggraf <proj>", "Ranking de acumulados en gráfica de barras"),
]
# Adaptive Card borra los <...> (los lee como etiqueta HTML) -> usar guillemets ‹ › para requeridos
EQUIPO=[(c.replace("<","‹").replace(">","›"), q) for c,q in EQUIPO]
FLOTA =[(c.replace("<","‹").replace(">","›"), q) for c,q in FLOTA]
def cell(t, bold=False):
    return {"type":"TableCell","items":[{"type":"TextBlock","text":t,"wrap":True,"size":"Small",**({"weight":"Bolder"} if bold else {})}]}
def table(rows):
    tr=[{"type":"TableRow","cells":[cell("Comando",1),cell("Qué hace",1)],"style":"accent"}]
    for c,q in rows: tr.append({"type":"TableRow","cells":[cell(c),cell(q)]})
    return {"type":"Table","columns":[{"width":2},{"width":3}],"gridStyle":"default","firstRowAsHeaders":True,"rows":tr}
card={
 "type":"AdaptiveCard","$schema":"http://adaptivecards.io/schemas/adaptive-card.json","version":"1.5",
 "body":[
   {"type":"TextBlock","text":"🛠️ Comandos KomfIA","weight":"Bolder","size":"Large","wrap":True},
   {"type":"TextBlock","text":"Escribe **/** + módulo + parámetros.","wrap":True,"isSubtle":True,"spacing":"None"},
   {"type":"Container","style":"emphasis","spacing":"Small","bleed":True,"items":[
       {"type":"TextBlock","text":"📖 Cómo leer los comandos","weight":"Bolder","size":"Small","spacing":"None"},
       {"type":"FactSet","spacing":"Small","facts":[
           {"title":"‹campo›","value":"OBLIGATORIO"},
           {"title":"[campo]","value":"opcional (tiene un valor por defecto)"},
           {"title":"‹proj›","value":"proyecto / mina — ej. Antapaccay, Antamina"},
           {"title":"‹eq›","value":"equipo — ej. CA3177 (traduce «el 3177»)"},
           {"title":"‹comp›","value":"componente — MT LH · MT RH · RD LH · RD RH · Hidr · Motor. Otros se escriben completos: Mando Final LH/RH, Transmisión, PTO, Caja Giro Front/Rear, Diferencial, Freno…"},
           {"title":"‹metal›","value":"metal — Fe, Cu, Cr, Ni, Pb, Sn, Si, PQ, Na, K… (o su nombre)"},
           {"title":"[modelo]","value":"modelo — ej. 980E (por defecto: todos)"},
           {"title":"[rango]","value":"ventana de tiempo — ej. «2 años», «5 meses», «14 días» (por defecto: todo)"},
           {"title":"[top]","value":"cuántos mostrar, 1 o 2 dígitos (por defecto: 10)"}
       ]}
   ]},
   {"type":"TextBlock","text":"🔧 Por equipo","weight":"Bolder","spacing":"Medium","color":"Accent"},
   table(EQUIPO),
   {"type":"TextBlock","text":"🚛 Por flota","weight":"Bolder","spacing":"Medium","color":"Accent"},
   table(FLOTA),
   {"type":"TextBlock","text":"También funcionan **/diagnostico** (= /diagcompleto), **/tendenciadet** (= /tendencia), **/barrido** y **/conteo** (= /panel).","wrap":True,"isSubtle":True,"size":"Small","spacing":"Medium"},
   {"type":"TextBlock","text":"Si falta un dato requerido, te lo pido en el chat. El `/` solo actúa pegado a un comando; tu lenguaje natural sigue igual.","wrap":True,"isSubtle":True,"size":"Small","spacing":"None"}
 ]
}
json.dumps(card)  # valida
out="docs/copilot/tarjetas"; os.makedirs(out,exist_ok=True)
open(out+"/comandos_card.json","w",encoding="utf-8").write(json.dumps(card,ensure_ascii=False,indent=2))
print("OK card escrita:", out+"/comandos_card.json", "| filas:", len(EQUIPO)+len(FLOTA))
